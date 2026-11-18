package com.appylab.rooko

import android.content.Context
import android.content.SharedPreferences
import org.json.JSONObject
import java.io.ByteArrayOutputStream
import java.net.HttpURLConnection
import java.net.URL
import java.nio.ByteBuffer
import java.nio.charset.CodingErrorAction
import java.nio.charset.StandardCharsets
import java.security.KeyFactory
import java.security.MessageDigest
import java.security.Signature
import java.security.spec.X509EncodedKeySpec
import java.util.Base64
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean
import javax.net.ssl.HttpsURLConnection

internal enum class DetectorRegistryEntryStatus(val wireValue: String) {
    CATALOGUED("catalogued"),
    SUPPORTED("supported"),
    DISABLED("disabled");

    companion object {
        fun fromWireValue(value: String): DetectorRegistryEntryStatus? =
            entries.firstOrNull { it.wireValue == value }
    }
}

internal data class DetectorVersionValidation(
    val reportId: String,
    val transitionCases: Long,
    val stationaryCases: Long,
    val deviceFamilies: Long,
    val precisionPercent: Double,
    val recallPercent: Double,
    val stationaryRepeats: Long,
) {
    fun passesGate(): Boolean =
        reportId.matches(Regex("[A-Za-z0-9][A-Za-z0-9._-]{0,95}")) &&
            transitionCases >= MIN_TRANSITION_CASES &&
            stationaryCases >= MIN_STATIONARY_CASES &&
            deviceFamilies >= MIN_DEVICE_FAMILIES &&
            precisionPercent in MIN_PRECISION_PERCENT..100.0 &&
            recallPercent in MIN_RECALL_PERCENT..100.0 &&
            stationaryRepeats == 0L

    private companion object {
        const val MIN_TRANSITION_CASES = 200L
        const val MIN_STATIONARY_CASES = 100L
        const val MIN_DEVICE_FAMILIES = 3L
        const val MIN_PRECISION_PERCENT = 98.0
        const val MIN_RECALL_PERCENT = 90.0
    }
}

internal data class DetectorRegistryEntry(
    val packageName: String,
    val versionName: String,
    val status: DetectorRegistryEntryStatus,
    val profileId: String?,
    val sourceUrl: String,
    val validation: DetectorVersionValidation? = null,
)

internal data class DetectorRegistryProfile(
    val profileId: String,
    val packageName: String,
    val strategyId: String,
    val feedMarkerViewIds: Set<String>,
    val transitionViewIds: Set<String>,
    val identityStrategy: ItemIdentityStrategy,
    val identityNodeViewId: String?,
)

/** Exists only after the signed payload has passed signature, schema, time, and rollback checks. */
internal class VerifiedDetectorRegistry internal constructor(
    val sequence: Long,
    val schemaVersion: Int = 1,
    val issuedAtEpochSeconds: Long,
    val expiresAtEpochSeconds: Long,
    val entries: List<DetectorRegistryEntry>,
    val profiles: Map<String, DetectorRegistryProfile> = emptyMap(),
    internal val payloadDigest: String,
) {
    fun entryFor(packageName: String, versionName: String): DetectorRegistryEntry? =
        entries.firstOrNull {
            it.packageName == packageName && it.versionName == versionName
        }

    fun isUnexpired(nowMillis: Long = System.currentTimeMillis()): Boolean =
        nowMillis / 1_000L < expiresAtEpochSeconds

    fun profileFor(profileId: String, packageName: String): DetectorRegistryProfile? =
        profiles[profileId]?.takeIf { it.packageName == packageName }
}

internal fun interface DetectorRegistryTransport {
    fun fetch(endpoint: String): ByteArray?
}

/** Performs a static, bounded HTTPS GET for the complete registry envelope. */
internal class HttpsDetectorRegistryTransport(
    private val connectionFactory: (URL) -> HttpsURLConnection? = { url ->
        url.openConnection() as? HttpsURLConnection
    },
    private val monotonicNanos: () -> Long = System::nanoTime,
    private val requestTimeoutMillis: Int = REQUEST_TIMEOUT_MILLIS,
) : DetectorRegistryTransport {
    override fun fetch(endpoint: String): ByteArray? {
        val url = runCatching { URL(endpoint) }.getOrNull() ?: return null
        if (!isSafeDetectorRegistryEndpoint(url)) return null
        if (requestTimeoutMillis <= 0) return null
        val startedAtNanos = monotonicNanos()
        val connection = runCatching { connectionFactory(url) }.getOrNull() ?: return null
        val deadlineReached = AtomicBoolean(false)
        val timeoutTask = timeoutScheduler.schedule({
            deadlineReached.set(true)
            runCatching { connection.disconnect() }
        }, requestTimeoutMillis.toLong(), TimeUnit.MILLISECONDS)
        try {
            connection.instanceFollowRedirects = false
            connection.connectTimeout = minOf(CONNECT_TIMEOUT_MILLIS, requestTimeoutMillis)
            connection.readTimeout = minOf(READ_TIMEOUT_MILLIS, requestTimeoutMillis)
            connection.requestMethod = "GET"
            connection.useCaches = false
            connection.setRequestProperty("Accept", "application/json")
            connection.setRequestProperty("Accept-Encoding", "identity")
            connection.setRequestProperty("Cache-Control", "no-cache")
            connection.setRequestProperty("User-Agent", STATIC_USER_AGENT)
            if (connection.responseCode != HttpURLConnection.HTTP_OK) return null
            if (deadlineReached.get() || remainingTimeoutMillis(startedAtNanos) <= 0) return null
            if (connection.contentLengthLong > MAX_ENVELOPE_BYTES) return null
            return connection.inputStream.use { input ->
                val output = ByteArrayOutputStream()
                val buffer = ByteArray(BUFFER_SIZE)
                var totalBytes = 0
                while (true) {
                    val remainingMillis = remainingTimeoutMillis(startedAtNanos)
                    if (deadlineReached.get() || remainingMillis <= 0) return null
                    connection.readTimeout = minOf(READ_TIMEOUT_MILLIS, remainingMillis)
                    val count = input.read(buffer)
                    if (deadlineReached.get() || remainingTimeoutMillis(startedAtNanos) <= 0) return null
                    if (count < 0) break
                    totalBytes += count
                    if (totalBytes > MAX_ENVELOPE_BYTES) return null
                    output.write(buffer, 0, count)
                }
                output.toByteArray().takeUnless {
                    deadlineReached.get() || remainingTimeoutMillis(startedAtNanos) <= 0
                }
            }
        } catch (_: Exception) {
            return null
        } finally {
            timeoutTask.cancel(false)
            connection.disconnect()
        }
    }

    private fun remainingTimeoutMillis(startedAtNanos: Long): Int {
        val elapsedMillis = (monotonicNanos() - startedAtNanos) / NANOS_PER_MILLISECOND
        val remainingMillis = requestTimeoutMillis - elapsedMillis
        return remainingMillis.coerceIn(0L, Int.MAX_VALUE.toLong()).toInt()
    }

    private companion object {
        const val MAX_ENVELOPE_BYTES = 512 * 1024
        const val CONNECT_TIMEOUT_MILLIS = 5_000
        const val READ_TIMEOUT_MILLIS = 5_000
        const val REQUEST_TIMEOUT_MILLIS = 15_000
        const val NANOS_PER_MILLISECOND = 1_000_000L
        const val BUFFER_SIZE = 8 * 1024
        const val STATIC_USER_AGENT = "Rooko-DetectorRegistry/1"
        val timeoutScheduler = Executors.newSingleThreadScheduledExecutor { runnable ->
            Thread(runnable, "rooko-registry-timeout").apply { isDaemon = true }
        }
    }
}

private fun isSafeDetectorRegistryEndpoint(url: URL): Boolean =
    url.protocol == "https" && url.host.isNotBlank() && url.userInfo == null &&
        url.ref == null && url.query == null

/** Fetches and caches one signed registry. Requests contain no app or device-specific values. */
internal class DetectorVersionRegistry(
    context: Context,
    private val registryUrl: String = BuildConfig.DETECTOR_REGISTRY_URL,
    private val registryPublicKeyBase64: String = BuildConfig.DETECTOR_REGISTRY_PUBLIC_KEY_BASE64,
    private val transport: DetectorRegistryTransport = HttpsDetectorRegistryTransport(),
    private val clockMillis: () -> Long = { System.currentTimeMillis() },
) {
    private val preferences: SharedPreferences = context.getSharedPreferences(
        PREFERENCES_NAME,
        Context.MODE_PRIVATE,
    )
    fun readVerified(nowMillis: Long = clockMillis()): VerifiedDetectorRegistry? {
        val envelope = preferences.getString(ENVELOPE_KEY, null) ?: return null
        val registry = DetectorRegistryEnvelope.verify(
            envelope = envelope,
            publicKeyBase64 = registryPublicKeyBase64,
            nowMillis = nowMillis,
        ) ?: return null
        if (registry.sequence != preferences.getLong(HIGHEST_SEQUENCE_KEY, 0L)) return null
        if (registry.payloadDigest != preferences.getString(PAYLOAD_DIGEST_KEY, null)) return null
        return registry
    }

    fun refreshAsync(onComplete: (VerifiedDetectorRegistry?) -> Unit = {}) {
        val isNotConfigured =
            registryUrl.isBlank() || registryPublicKeyBase64.isBlank()
        var completeImmediately = false
        var shouldStartFetch = false
        synchronized(refreshLock) {
            if (isNotConfigured) {
                completeImmediately = true
            } else if (refreshInFlight) {
                pendingCallbacks += onComplete
            } else {
                val now = clockMillis()
                val lastAttempt = preferences.getLong(LAST_ATTEMPT_KEY, 0L)
                if (lastAttempt > 0L && now >= lastAttempt &&
                    now - lastAttempt < MIN_REFRESH_INTERVAL_MILLIS
                ) {
                    completeImmediately = true
                } else {
                    refreshInFlight = true
                    pendingCallbacks += onComplete
                    preferences.edit().putLong(LAST_ATTEMPT_KEY, now).apply()
                    shouldStartFetch = true
                }
            }
        }
        if (completeImmediately) {
            onComplete(readVerified())
            return
        }
        if (!shouldStartFetch) return
        executor.execute {
            try {
                fetchAndCache()
            } catch (_: Exception) {
                // Network and parsing failures intentionally leave the last verified cache intact.
            } finally {
                val callbacks = synchronized(refreshLock) {
                    refreshInFlight = false
                    pendingCallbacks.toList().also { pendingCallbacks.clear() }
                }
                val result = readVerified()
                callbacks.forEach { callback -> runCatching { callback(result) } }
            }
        }
    }

    private fun fetchAndCache() {
        val endpoint = registryUrl
        val publicKey = registryPublicKeyBase64
        if (endpoint.isBlank() || publicKey.isBlank()) return

        val endpointUrl = runCatching { URL(endpoint) }.getOrNull() ?: return
        if (!isSafeDetectorRegistryEndpoint(endpointUrl)) return
        val envelopeBytes = transport.fetch(endpoint) ?: return
        if (envelopeBytes.isEmpty() || envelopeBytes.size > MAX_ENVELOPE_BYTES) return
        val envelope = String(envelopeBytes, StandardCharsets.UTF_8)
        val registry = DetectorRegistryEnvelope.verify(envelope, publicKey, clockMillis()) ?: return
        cacheIfNewer(envelope, registry)
    }

    private fun cacheIfNewer(envelope: String, registry: VerifiedDetectorRegistry) {
        val currentSequence = preferences.getLong(HIGHEST_SEQUENCE_KEY, 0L)
        val currentDigest = preferences.getString(PAYLOAD_DIGEST_KEY, null)
        if (registry.sequence < currentSequence) return
        if (registry.sequence == currentSequence && currentDigest != registry.payloadDigest) return
        if (registry.sequence == currentSequence && currentDigest == registry.payloadDigest) {
            if (readVerified() != null) return
            preferences.edit().putString(ENVELOPE_KEY, envelope).commit()
            return
        }

        preferences.edit()
            .putString(ENVELOPE_KEY, envelope)
            .putLong(HIGHEST_SEQUENCE_KEY, registry.sequence)
            .putString(PAYLOAD_DIGEST_KEY, registry.payloadDigest)
            .commit()
    }

    companion object {
        private const val PREFERENCES_NAME = "rooko_detector_registry"
        private const val ENVELOPE_KEY = "signed_envelope"
        private const val HIGHEST_SEQUENCE_KEY = "highest_sequence"
        private const val PAYLOAD_DIGEST_KEY = "payload_digest"
        private const val LAST_ATTEMPT_KEY = "last_fetch_attempt_at_millis"
        private const val MAX_ENVELOPE_BYTES = 512 * 1024
        private const val MIN_REFRESH_INTERVAL_MILLIS = 15 * 60 * 1_000L
        private val refreshLock = Any()
        private var refreshInFlight = false
        private val pendingCallbacks = mutableListOf<(VerifiedDetectorRegistry?) -> Unit>()
        private val executor = Executors.newSingleThreadExecutor { runnable ->
            Thread(runnable, "rooko-detector-registry").apply { isDaemon = true }
        }
    }
}

internal object DetectorRegistryEnvelope {
    private const val MAX_ENVELOPE_BYTES = 512 * 1024
    private const val MAX_ENTRIES = 10_000
    private val versionNamePattern = Regex("[A-Za-z0-9.+_-]{1,64}")
    private val profileIdPattern = Regex("[a-z0-9][a-z0-9._-]{0,63}")

    fun verify(
        envelope: String,
        publicKeyBase64: String,
        nowMillis: Long = System.currentTimeMillis(),
    ): VerifiedDetectorRegistry? = try {
        if (envelope.toByteArray(StandardCharsets.UTF_8).size > MAX_ENVELOPE_BYTES) return null
        if (publicKeyBase64.isBlank()) return null
        val envelopeObject = JSONObject(envelope)
        if (!hasOnlyKeys(envelopeObject, setOf("payload", "signature"))) return null
        val payloadBytes = Base64.getDecoder().decode(envelopeObject.getString("payload"))
        if (payloadBytes.isEmpty() || payloadBytes.size > MAX_ENVELOPE_BYTES) return null
        val signatureBytes = Base64.getDecoder().decode(envelopeObject.getString("signature"))
        val publicKeyBytes = Base64.getDecoder().decode(publicKeyBase64.filterNot(Char::isWhitespace))
        val publicKey = KeyFactory.getInstance("EC")
            .generatePublic(X509EncodedKeySpec(publicKeyBytes))
        val verifier = Signature.getInstance("SHA256withECDSA")
        verifier.initVerify(publicKey)
        verifier.update(payloadBytes)
        if (!verifier.verify(signatureBytes)) return null

        val payload = StandardCharsets.UTF_8.newDecoder()
            .onMalformedInput(CodingErrorAction.REPORT)
            .onUnmappableCharacter(CodingErrorAction.REPORT)
            .decode(ByteBuffer.wrap(payloadBytes))
            .toString()
        parsePayload(payload, payloadBytes, nowMillis)
    } catch (_: Exception) {
        null
    }

    private fun parsePayload(
        payload: String,
        payloadBytes: ByteArray,
        nowMillis: Long,
    ): VerifiedDetectorRegistry? {
        val root = JSONObject(payload)
        val schemaVersion = root.longInteger("schemaVersion") ?: return null
        if (schemaVersion !in setOf(1L, 2L)) return null
        val allowedPayloadKeys = setOf(
            "schemaVersion",
            "sequence",
            "issuedAtEpochSeconds",
            "expiresAtEpochSeconds",
            "entries",
        ) + if (schemaVersion == 2L) setOf("profiles") else emptySet()
        if (!hasOnlyKeys(root, allowedPayloadKeys)) return null
        if (schemaVersion == 2L && !root.has("profiles")) return null
        val sequence = root.longInteger("sequence") ?: return null
        val issuedAt = root.longInteger("issuedAtEpochSeconds") ?: return null
        val expiresAt = root.longInteger("expiresAtEpochSeconds") ?: return null
        val nowSeconds = nowMillis / 1_000L
        if (sequence <= 0L || issuedAt <= 0L || expiresAt <= issuedAt) return null
        if (issuedAt > nowSeconds + ALLOWED_CLOCK_SKEW_SECONDS || nowSeconds >= expiresAt) return null

        val rawEntries = root.getJSONArray("entries")
        if (rawEntries.length() > MAX_ENTRIES) return null
        val knownPackages = SupportedAppsNative.all.map { it.packageName }.toSet()
        val profiles = if (schemaVersion == 2L) {
            parseProfiles(root.getJSONArray("profiles"), knownPackages) ?: return null
        } else {
            emptyMap()
        }
        val seenVersions = mutableSetOf<Pair<String, String>>()
        val entries = buildList {
            for (index in 0 until rawEntries.length()) {
                val item = rawEntries.getJSONObject(index)
                if (!hasOnlyKeys(
                        item,
                        setOf("packageName", "versionName", "status", "profileId", "sourceUrl", "validation"),
                    )
                ) return null
                val packageName = item.getString("packageName")
                val versionName = item.getString("versionName")
                val status = DetectorRegistryEntryStatus.fromWireValue(item.getString("status"))
                    ?: return null
                if (packageName !in knownPackages || !versionNamePattern.matches(versionName)) {
                    return null
                }
                if (!seenVersions.add(packageName to versionName)) return null
                val profileId = if (item.has("profileId") && !item.isNull("profileId")) {
                    item.getString("profileId")
                } else {
                    null
                }
                val hasValidation = item.has("validation")
                val validation = if (hasValidation) {
                    parseValidation(item.optJSONObject("validation")) ?: return null
                } else {
                    null
                }
                if (schemaVersion == 1L && hasValidation) return null
                if (schemaVersion == 2L) {
                    if (status == DetectorRegistryEntryStatus.SUPPORTED) {
                        if (validation?.passesGate() != true) return null
                    } else if (hasValidation) {
                        return null
                    }
                }
                val sourceUrl = item.getString("sourceUrl")
                    .takeIf(::isPublicHttpsUrl) ?: return null
                if (profileId != null && !profileIdPattern.matches(profileId)) return null
                if (schemaVersion == 2L && profileId != null &&
                    profiles[profileId]?.packageName != packageName
                ) return null
                when (status) {
                    DetectorRegistryEntryStatus.CATALOGUED -> if (profileId != null) return null
                    DetectorRegistryEntryStatus.SUPPORTED -> {
                        if (profileId == null) return null
                        if (schemaVersion == 2L && profiles[profileId]?.packageName != packageName) {
                            return null
                        }
                    }
                    DetectorRegistryEntryStatus.DISABLED -> Unit
                }
                add(DetectorRegistryEntry(
                    packageName = packageName,
                    versionName = versionName,
                    status = status,
                    profileId = profileId,
                    sourceUrl = sourceUrl,
                    validation = validation,
                ))
            }
        }
        return VerifiedDetectorRegistry(
            sequence = sequence,
            schemaVersion = schemaVersion.toInt(),
            issuedAtEpochSeconds = issuedAt,
            expiresAtEpochSeconds = expiresAt,
            entries = entries,
            profiles = profiles,
            payloadDigest = sha256Hex(payloadBytes),
        )
    }

    private fun parseValidation(raw: org.json.JSONObject?): DetectorVersionValidation? {
        val item = raw ?: return null
        if (!hasOnlyKeys(item, VALIDATION_KEYS)) return null
        val reportId = item.optString("reportId")
        val transitionCases = item.longInteger("transitionCases") ?: return null
        val stationaryCases = item.longInteger("stationaryCases") ?: return null
        val deviceFamilies = item.longInteger("deviceFamilies") ?: return null
        val precisionPercent = item.numberValue("precisionPercent") ?: return null
        val recallPercent = item.numberValue("recallPercent") ?: return null
        val stationaryRepeats = item.longInteger("stationaryRepeats") ?: return null
        if (reportId.isBlank() || transitionCases < 0L || stationaryCases < 0L ||
            deviceFamilies < 0L || stationaryRepeats < 0L
        ) return null
        return DetectorVersionValidation(
            reportId = reportId,
            transitionCases = transitionCases,
            stationaryCases = stationaryCases,
            deviceFamilies = deviceFamilies,
            precisionPercent = precisionPercent,
            recallPercent = recallPercent,
            stationaryRepeats = stationaryRepeats,
        ).takeIf(DetectorVersionValidation::passesGate)
    }

    private fun parseProfiles(
        rawProfiles: org.json.JSONArray,
        knownPackages: Set<String>,
    ): Map<String, DetectorRegistryProfile>? {
        if (rawProfiles.length() > MAX_PROFILES) return null
        val parsed = linkedMapOf<String, DetectorRegistryProfile>()
        for (index in 0 until rawProfiles.length()) {
            val item = rawProfiles.optJSONObject(index) ?: return null
            if (!hasOnlyKeys(item, PROFILE_KEYS)) return null
            val profileId = item.optString("profileId").takeIf(profileIdPattern::matches) ?: return null
            val packageName = item.optString("packageName")
                .takeIf { it in knownPackages } ?: return null
            if (profileId in parsed) return null
            if (item.optString("strategyId") != ACCESSIBILITY_STRUCTURE_STRATEGY) return null

            val feedMarkerViewIds = item.stringIdSet("feedMarkerViewIds", packageName) ?: return null
            val transitionViewIds = item.stringIdSet("transitionViewIds", packageName) ?: return null
            val identityStrategy = when (item.optString("identityStrategy")) {
                "stable_opaque_accessibility_token" ->
                    ItemIdentityStrategy.STABLE_OPAQUE_ACCESSIBILITY_TOKEN
                "structural_node_pair" -> ItemIdentityStrategy.STRUCTURAL_NODE_PAIR
                "bounded_transition_fingerprint" -> ItemIdentityStrategy.BOUNDED_TRANSITION_FINGERPRINT
                else -> return null
            }
            val identityNodeViewId = if (item.has("identityNodeViewId")) {
                item.optString("identityNodeViewId").takeIf { it.isResourceId(packageName) }
                    ?: return null
            } else {
                null
            }
            if (identityStrategy != ItemIdentityStrategy.BOUNDED_TRANSITION_FINGERPRINT &&
                identityNodeViewId == null
            ) return null
            if (identityStrategy == ItemIdentityStrategy.BOUNDED_TRANSITION_FINGERPRINT &&
                identityNodeViewId != null
            ) return null

            parsed[profileId] = DetectorRegistryProfile(
                profileId = profileId,
                packageName = packageName,
                strategyId = ACCESSIBILITY_STRUCTURE_STRATEGY,
                feedMarkerViewIds = feedMarkerViewIds,
                transitionViewIds = transitionViewIds,
                identityStrategy = identityStrategy,
                identityNodeViewId = identityNodeViewId,
            )
        }
        return parsed
    }

    private fun org.json.JSONObject.stringIdSet(
        fieldName: String,
        packageName: String,
    ): Set<String>? {
        val array = optJSONArray(fieldName) ?: return null
        if (array.length() !in 1..MAX_RESOURCE_IDS_PER_PROFILE) return null
        val ids = linkedSetOf<String>()
        for (index in 0 until array.length()) {
            val value = array.optString(index).takeIf { it.isResourceId(packageName) } ?: return null
            if (!ids.add(value)) return null
        }
        return ids
    }

    private fun org.json.JSONObject.numberValue(fieldName: String): Double? =
        (opt(fieldName) as? Number)?.toDouble()?.takeIf(Double::isFinite)

    private fun String.isResourceId(packageName: String): Boolean =
        Regex("^${Regex.escape(packageName)}:id/[a-z_][a-z0-9_]*$").matches(this)

    private fun sha256Hex(bytes: ByteArray): String = MessageDigest.getInstance("SHA-256")
        .digest(bytes)
        .joinToString("") { byte -> "%02x".format(byte) }

    private fun hasOnlyKeys(jsonObject: JSONObject, allowed: Set<String>): Boolean {
        val keys = jsonObject.keys()
        while (keys.hasNext()) if (keys.next() !in allowed) return false
        return true
    }

    private fun JSONObject.longInteger(name: String): Long? {
        val value = opt(name) as? Number ?: return null
        val asDouble = value.toDouble()
        if (!asDouble.isFinite()) return null
        val asLong = value.toLong()
        return asLong.takeIf { asDouble == it.toDouble() }
    }

    private fun isPublicHttpsUrl(value: String): Boolean = try {
        val source = URL(value)
        source.protocol == "https" && source.host.isNotBlank() &&
            source.userInfo == null && source.ref == null && value.length <= MAX_SOURCE_URL_LENGTH
    } catch (_: Exception) {
        false
    }

    private const val ALLOWED_CLOCK_SKEW_SECONDS = 300L
    private const val MAX_SOURCE_URL_LENGTH = 512
    private const val ACCESSIBILITY_STRUCTURE_STRATEGY = "accessibility_structure_v1"
    private const val MAX_PROFILES = 500
    private const val MAX_RESOURCE_IDS_PER_PROFILE = 8
    private val PROFILE_KEYS = setOf(
        "profileId",
        "packageName",
        "strategyId",
        "feedMarkerViewIds",
        "transitionViewIds",
        "identityStrategy",
        "identityNodeViewId",
    )
    private val VALIDATION_KEYS = setOf(
        "reportId",
        "transitionCases",
        "stationaryCases",
        "deviceFamilies",
        "precisionPercent",
        "recallPercent",
        "stationaryRepeats",
    )
}
