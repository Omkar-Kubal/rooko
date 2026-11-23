package com.heykakaa.rooko

import java.nio.charset.StandardCharsets
import java.security.KeyPair
import java.security.KeyPairGenerator
import java.security.Signature
import java.security.spec.ECGenParameterSpec
import java.util.Base64
import org.json.JSONArray
import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35])
class DetectorVersionRegistryTest {
    private val nowSeconds = 1_800_000_000L

    @Test
    fun acceptsSignedCataloguedVersionWithoutEnablingIt() {
        val source = entry(YOUTUBE, "21.45.82")
        val fixture = signedRegistry(JSONArray().put(source))

        val registry = verify(fixture)

        assertNotNull(registry)
        assertEquals(7L, registry?.sequence)
        assertEquals("21.45.82", registry?.entryFor(YOUTUBE, "21.45.82")?.versionName)
        assertNull(DetectorProfiles.forVersion(YOUTUBE, "21.45.82", registry))
    }

    @Test
    fun acceptsEnvelopeProducedBySharedNodePublisherFixture() {
        val envelope = javaClass.getResourceAsStream("/detector_registry/registry-envelope.json")!!
            .bufferedReader(StandardCharsets.UTF_8).use { it.readText() }
        val publicKey = javaClass.getResourceAsStream("/detector_registry/registry-public-key.b64")!!
            .bufferedReader(StandardCharsets.UTF_8).use { it.readText().trim() }

        val registry = DetectorRegistryEnvelope.verify(
            envelope = envelope,
            publicKeyBase64 = publicKey,
            nowMillis = nowSeconds * 1000L,
        )

        assertNotNull(registry)
        assertEquals(7L, registry?.sequence)
        assertEquals("21.45.82", registry?.entryFor(YOUTUBE, "21.45.82")?.versionName)
    }

    @Test
    fun resolvesSharedNodePublisherSchemaV2Fixture() {
        val envelope = javaClass.getResourceAsStream("/detector_registry/registry-envelope-v2.json")!!
            .bufferedReader(StandardCharsets.UTF_8).use { it.readText() }
        val publicKey = javaClass.getResourceAsStream("/detector_registry/registry-public-key-v2.b64")!!
            .bufferedReader(StandardCharsets.UTF_8).use { it.readText().trim() }

        val registry = DetectorRegistryEnvelope.verify(
            envelope = envelope,
            publicKeyBase64 = publicKey,
            nowMillis = nowSeconds * 1000L,
        )

        assertEquals(2, registry?.schemaVersion)
        assertEquals("fixture-only", registry?.entryFor(YOUTUBE, "21.45.82")?.validation?.reportId)
        assertEquals(
            "youtube.shorts.fixture.v2",
            DetectorProfiles.forVersion(YOUTUBE, "21.45.82", registry)?.profileId,
        )
    }

    @Test
    fun rejectsTamperedExpiredAndTooFarInFutureEnvelopes() {
        val fixture = signedRegistry(JSONArray())
        val tamperedPayload = JSONObject(fixture.envelope)
            .put("payload", Base64.getEncoder().encodeToString(bytes("{}")))
            .toString()
        assertNull(DetectorRegistryEnvelope.verify(tamperedPayload, fixture.publicKey, nowSeconds * 1000L))
        assertNull(verify(signedRegistry(JSONArray(), expiresAt = nowSeconds)))
        assertNull(verify(signedRegistry(JSONArray(), issuedAt = nowSeconds + 301)))
    }

    @Test
    fun rejectsDuplicateVersionsAndUntrustedSourceUrls() {
        val duplicate = JSONArray()
            .put(entry(YOUTUBE, "21.45.82"))
            .put(entry(YOUTUBE, "21.45.82"))
        assertNull(verify(signedRegistry(duplicate)))

        val invalidSource = entry(YOUTUBE, "21.45.82").put("sourceUrl", "http://example.org/youtube")
        assertNull(verify(signedRegistry(JSONArray().put(invalidSource))))

        val invalidPackage = entry("com.example.youtube", "21.45.82")
        assertNull(verify(signedRegistry(JSONArray().put(invalidPackage))))
    }

    @Test
    fun supportedRegistryMappingCannotResolveWithoutBundledProfile() {
        val supported = entry(YOUTUBE, "21.45.82")
            .put("status", "supported")
            .put("profileId", "youtube.shorts.v1")
        val registry = verify(signedRegistry(JSONArray().put(supported)))

        assertNotNull(registry)
        assertNull(DetectorProfiles.forVersion(YOUTUBE, "21.45.82", registry))
    }

    @Test
    fun resolvesSignedRemoteProfileForExactVersionsWithoutBundledProfile() {
        val profile = remoteProfile()
        val entries = JSONArray()
            .put(entry(YOUTUBE, "21.45.82")
                .put("status", "supported")
                .put("profileId", "youtube.shorts.structure.v1")
                .put("validation", validation()))
            .put(entry(YOUTUBE, "21.46.83")
                .put("status", "supported")
                .put("profileId", "youtube.shorts.structure.v1")
                .put("validation", validation("youtube-21-46-83")))
        val registry = verify(signedRegistry(
            entries = entries,
            schemaVersion = 2,
            profiles = JSONArray().put(profile),
        ))

        assertNotNull(registry)
        assertEquals("youtube.shorts.structure.v1", registry?.profileFor(
            "youtube.shorts.structure.v1", YOUTUBE,
        )?.profileId)
        assertEquals(98.0, registry?.entryFor(YOUTUBE, "21.45.82")?.validation?.precisionPercent)
        val resolved = listOf("21.45.82", "21.46.83").map { versionName ->
            DetectorProfiles.forVersion(YOUTUBE, versionName, registry)
        }
        assertEquals(listOf("21.45.82", "21.46.83"), resolved.map { it?.versionName })
        assertEquals(setOf("youtube.shorts.structure.v1"), resolved.mapNotNull { it?.profileId }.toSet())
        assertEquals(setOf("com.google.android.youtube:id/shorts_feed"), resolved.first()?.feedMarkerViewIds)
    }

    @Test
    fun rejectsRemoteProfilesWithUnknownStrategiesOrCrossPackageResourceIds() {
        val unknownStrategy = remoteProfile().put("strategyId", "downloaded_detector")
        assertNull(verify(signedRegistry(
            entries = JSONArray(),
            schemaVersion = 2,
            profiles = JSONArray().put(unknownStrategy),
        )))

        val crossPackageId = remoteProfile().put(
            "feedMarkerViewIds",
            JSONArray().put("com.instagram.android:id/reels_feed"),
        )
        assertNull(verify(signedRegistry(
            entries = JSONArray(),
            schemaVersion = 2,
            profiles = JSONArray().put(crossPackageId),
        )))
    }

    @Test
    fun rejectsSupportedRemoteMappingWhenSignedAccuracyEvidenceMissesGate() {
        val unsupportedEvidence = validation().put("precisionPercent", 97.9)
        val entry = entry(YOUTUBE, "21.45.82")
            .put("status", "supported")
            .put("profileId", "youtube.shorts.structure.v1")
            .put("validation", unsupportedEvidence)
        assertNull(verify(signedRegistry(
            entries = JSONArray().put(entry),
            schemaVersion = 2,
            profiles = JSONArray().put(remoteProfile()),
        )))
    }

    private fun verify(fixture: SignedFixture): VerifiedDetectorRegistry? =
        DetectorRegistryEnvelope.verify(
            envelope = fixture.envelope,
            publicKeyBase64 = fixture.publicKey,
            nowMillis = nowSeconds * 1000L,
        )

    private fun signedRegistry(
        entries: JSONArray,
        issuedAt: Long = nowSeconds - 60,
        expiresAt: Long = nowSeconds + 60 * 60,
        schemaVersion: Int = 1,
        profiles: JSONArray = JSONArray(),
    ): SignedFixture {
        val payload = JSONObject()
            .put("schemaVersion", schemaVersion)
            .put("sequence", 7)
            .put("issuedAtEpochSeconds", issuedAt)
            .put("expiresAtEpochSeconds", expiresAt)
            .put("entries", entries)
        if (schemaVersion == 2) payload.put("profiles", profiles)
        val payloadBytes = payload.toString()
            .toByteArray(StandardCharsets.UTF_8)
        val keyPair = keyPair()
        val signature = Signature.getInstance("SHA256withECDSA").apply {
            initSign(keyPair.private)
            update(payloadBytes)
        }.sign()
        val envelope = JSONObject()
            .put("payload", Base64.getEncoder().encodeToString(payloadBytes))
            .put("signature", Base64.getEncoder().encodeToString(signature))
            .toString()
        return SignedFixture(
            envelope = envelope,
            publicKey = Base64.getEncoder().encodeToString(keyPair.public.encoded),
        )
    }

    private fun keyPair(): KeyPair = KeyPairGenerator.getInstance("EC").apply {
        initialize(ECGenParameterSpec("secp256r1"))
    }.generateKeyPair()

    private fun entry(
        packageName: String,
        versionName: String,
    ): JSONObject = JSONObject()
        .put("packageName", packageName)
        .put("versionName", versionName)
        .put("status", "catalogued")
        .put("sourceUrl", "https://example.org/releases/$versionName")

    private fun remoteProfile(): JSONObject = JSONObject()
        .put("profileId", "youtube.shorts.structure.v1")
        .put("packageName", YOUTUBE)
        .put("strategyId", "accessibility_structure_v1")
        .put("feedMarkerViewIds", JSONArray().put("$YOUTUBE:id/shorts_feed"))
        .put("transitionViewIds", JSONArray().put("$YOUTUBE:id/shorts_pager"))
        .put("identityStrategy", "structural_node_pair")
        .put("identityNodeViewId", "$YOUTUBE:id/shorts_item")

    private fun validation(reportId: String = "youtube-21-45-82-validation"): JSONObject = JSONObject()
        .put("reportId", reportId)
        .put("transitionCases", 200)
        .put("stationaryCases", 100)
        .put("deviceFamilies", 3)
        .put("precisionPercent", 98.0)
        .put("recallPercent", 90.0)
        .put("stationaryRepeats", 0)

    private fun bytes(value: String) = value.toByteArray(StandardCharsets.UTF_8)

    private data class SignedFixture(
        val envelope: String,
        val publicKey: String,
    )

    private companion object {
        const val YOUTUBE = "com.google.android.youtube"
    }
}
