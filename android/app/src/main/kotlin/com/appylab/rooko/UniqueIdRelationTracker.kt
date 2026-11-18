package com.appylab.rooko

import java.security.MessageDigest
import java.security.SecureRandom
import javax.crypto.Mac
import javax.crypto.spec.SecretKeySpec

/** Safe labels written by the debug probe; no opaque ID or digest leaves process memory. */
internal enum class UniqueIdRelation(val wireValue: String) {
    API_UNAVAILABLE("api_unavailable"),
    NO_VALUE("no_value"),
    INVALID_VALUE("invalid_value"),
    FIRST("first"),
    SAME("same"),
    CHANGED("changed"),
}

/** Candidate nodes are limited to item containers observed on the current selected versions. */
internal object UniqueIdProbeNodeIds {
    private val candidates = mapOf(
        "instagram" to setOf("clips_video_container"),
        "youtube" to setOf("reel_player_page_container"),
    )

    fun isCandidate(appId: String, resourceName: String): Boolean =
        resourceName in candidates[appId].orEmpty()
}

/** Compares short-lived HMACs of API 33+ node IDs for a debug-only feasibility probe. */
internal class UniqueIdRelationTracker(
    private val retentionMillis: Long = MAX_RETENTION_MILLIS,
    private val maximumIdLength: Int = MAX_ID_LENGTH,
) {
    private data class Scope(
        val appId: String,
        val versionName: String,
        val resourceName: String,
        val occurrence: Int,
    )

    private data class Entry(
        val digest: ByteArray,
        val firstObservedAtMillis: Long,
    )

    private val entries = mutableMapOf<Scope, Entry>()
    private var sessionKey = newSessionKey()

    fun observe(
        appId: String,
        versionName: String,
        resourceName: String,
        occurrence: Int,
        opaqueUniqueId: String?,
        elapsedRealtimeMillis: Long,
        apiAvailable: Boolean,
    ): UniqueIdRelation {
        if (!apiAvailable) return UniqueIdRelation.API_UNAVAILABLE

        val scope = Scope(
            appId = appId,
            versionName = versionName,
            resourceName = resourceName,
            occurrence = occurrence.coerceAtLeast(0),
        )
        if (opaqueUniqueId.isNullOrBlank()) {
            remove(scope)
            return UniqueIdRelation.NO_VALUE
        }
        if (opaqueUniqueId.length > maximumIdLength) {
            remove(scope)
            return UniqueIdRelation.INVALID_VALUE
        }

        if (entries.values.any { elapsedRealtimeMillis < it.firstObservedAtMillis }) {
            clear()
        }
        removeExpired(elapsedRealtimeMillis)

        val digest = digest(scope, opaqueUniqueId)
        val previous = entries[scope]
        val relation = when {
            previous == null -> UniqueIdRelation.FIRST
            MessageDigest.isEqual(previous.digest, digest) -> UniqueIdRelation.SAME
            else -> UniqueIdRelation.CHANGED
        }
        previous?.digest?.fill(0)
        entries[scope] = Entry(digest, elapsedRealtimeMillis)
        return relation
    }

    fun clear() {
        entries.values.forEach { it.digest.fill(0) }
        entries.clear()
        sessionKey.fill(0)
        sessionKey = newSessionKey()
    }

    private fun removeExpired(nowMillis: Long) {
        val expiredScopes = entries.filterValues { entry ->
            nowMillis - entry.firstObservedAtMillis > retentionMillis
        }.keys
        expiredScopes.forEach(::remove)
    }

    private fun remove(scope: Scope) {
        entries.remove(scope)?.digest?.fill(0)
    }

    private fun digest(scope: Scope, value: String): ByteArray {
        val mac = Mac.getInstance(HMAC_ALGORITHM)
        mac.init(SecretKeySpec(sessionKey, HMAC_ALGORITHM))
        listOf(scope.appId, scope.versionName, scope.resourceName, scope.occurrence.toString())
            .forEach { field ->
                mac.update(field.toByteArray(Charsets.UTF_8))
                mac.update(0.toByte())
            }
        return mac.doFinal(value.toByteArray(Charsets.UTF_8))
    }

    private fun newSessionKey(): ByteArray = ByteArray(SESSION_KEY_BYTES).also {
        SecureRandom().nextBytes(it)
    }

    companion object {
        private const val HMAC_ALGORITHM = "HmacSHA256"
        private const val MAX_ID_LENGTH = 512
        private const val SESSION_KEY_BYTES = 32
        const val MAX_RETENTION_MILLIS = 5 * 60 * 1_000L

        fun apiLevelSupportsUniqueId(apiLevel: Int): Boolean = apiLevel >= 33
    }
}
