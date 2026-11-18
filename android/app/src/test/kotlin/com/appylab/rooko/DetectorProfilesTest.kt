package com.appylab.rooko

import org.junit.Assert.assertFalse
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class DetectorProfilesTest {
    @Test
    fun youtubeShortsVersionWithoutAccessibleItemTransitionsIsUnsupported() {
        assertNull(
            DetectorProfiles.forVersion(
                "com.google.android.youtube",
                "21.43.523",
            ),
        )
    }

    @Test
    fun instagramVersionWithoutIndependentItemIdentityFailsClosed() {
        assertNull(DetectorProfiles.forVersion("com.instagram.android", "454.0.0.54.77"))
        assertNull(
            DetectorProfiles.forVersion("com.instagram.android", "454.0.0.54.78"),
        )
    }

    @Test
    fun monitoredPackagesIncludeOnlySelectedExactProfileVersions() {
        val packages = DetectorProfiles.packageNamesForSelection(
            selectedAppIds = setOf("youtube", "instagram", "retired_app"),
            installedVersion = { packageName ->
                when (packageName) {
                    "com.google.android.youtube" -> "21.43.523"
                    "com.instagram.android" -> "454.0.0.54.77"
                    else -> null
                }
            },
        )

        assertTrue(packages.isEmpty())
    }

    @Test
    fun noSelectionProducesNoMonitoredPackages() {
        assertTrue(
            DetectorProfiles.packageNamesForSelection(
                selectedAppIds = emptySet(),
                installedVersion = { "21.43.523" },
            ).isEmpty(),
        )
    }

    @Test
    fun compatibleExactVersionsCanShareOneBundledProfile() {
        val profile = AppDetectorProfile(
            appId = "youtube",
            packageName = YOUTUBE,
            versionName = "21.45.82",
            feedMarkerViewIds = setOf("feed"),
            transitionViewIds = setOf("pager"),
            identityStrategy = ItemIdentityStrategy.STABLE_OPAQUE_ACCESSIBILITY_TOKEN,
            confidence = CountConfidence.CONFIRMED,
            profileId = "youtube.shorts.v1",
        )
        val versions = listOf("21.45.82", "21.46.83")
        val registry = registry(versions.map { entry(it, DetectorRegistryEntryStatus.SUPPORTED) })

        val resolved = versions.map { version ->
            DetectorProfiles.forVersion(
                packageName = YOUTUBE,
                versionName = version,
                registry = registry,
                bundledProfiles = mapOf(profile.profileId to profile),
            )
        }

        assertEquals(versions, resolved.map { it?.versionName })
        assertEquals(setOf(profile.profileId), resolved.mapNotNull { it?.profileId }.toSet())
    }

    @Test
    fun exactSupportedVersionsResolveOneSignedRemoteProfile() {
        val remoteProfile = DetectorRegistryProfile(
            profileId = "youtube.shorts.remote.v1",
            packageName = YOUTUBE,
            strategyId = "accessibility_structure_v1",
            feedMarkerViewIds = setOf("$YOUTUBE:id/shorts_feed"),
            transitionViewIds = setOf("$YOUTUBE:id/shorts_pager"),
            identityStrategy = ItemIdentityStrategy.STRUCTURAL_NODE_PAIR,
            identityNodeViewId = "$YOUTUBE:id/shorts_item",
        )
        val versions = listOf("21.45.82", "21.46.83")
        val entries = versions.map { versionName ->
            DetectorRegistryEntry(
                packageName = YOUTUBE,
                versionName = versionName,
                status = DetectorRegistryEntryStatus.SUPPORTED,
                profileId = remoteProfile.profileId,
                sourceUrl = "https://example.org/releases/$versionName",
                validation = passingValidation("youtube-$versionName"),
            )
        }
        val registry = VerifiedDetectorRegistry(
            sequence = 1L,
            schemaVersion = 2,
            issuedAtEpochSeconds = System.currentTimeMillis() / 1_000L - 60,
            expiresAtEpochSeconds = System.currentTimeMillis() / 1_000L + 86_400,
            entries = entries,
            profiles = mapOf(remoteProfile.profileId to remoteProfile),
            payloadDigest = "remote-profile-test",
        )

        val resolved = versions.map { versionName ->
            DetectorProfiles.forVersion(YOUTUBE, versionName, registry)
        }

        assertEquals(versions, resolved.map { it?.versionName })
        assertEquals(setOf(remoteProfile.profileId), resolved.mapNotNull { it?.profileId }.toSet())
        assertEquals(remoteProfile.feedMarkerViewIds, resolved.first()?.feedMarkerViewIds)
        assertEquals(remoteProfile.identityNodeViewId, resolved.first()?.identityNodeViewId)
        assertTrue(resolved.all { it?.confidence == CountConfidence.CONFIRMED })
    }

    @Test
    fun legacyRegistryCannotDeliverRemoteDetectorLogic() {
        val remoteProfile = DetectorRegistryProfile(
            profileId = "youtube.shorts.remote.v1",
            packageName = YOUTUBE,
            strategyId = "accessibility_structure_v1",
            feedMarkerViewIds = setOf("$YOUTUBE:id/shorts_feed"),
            transitionViewIds = setOf("$YOUTUBE:id/shorts_pager"),
            identityStrategy = ItemIdentityStrategy.STRUCTURAL_NODE_PAIR,
            identityNodeViewId = "$YOUTUBE:id/shorts_item",
        )
        val registry = VerifiedDetectorRegistry(
            sequence = 1L,
            schemaVersion = 1,
            issuedAtEpochSeconds = System.currentTimeMillis() / 1_000L - 60,
            expiresAtEpochSeconds = System.currentTimeMillis() / 1_000L + 86_400,
            entries = listOf(
                entry("21.45.82", DetectorRegistryEntryStatus.SUPPORTED)
                    .copy(profileId = remoteProfile.profileId),
            ),
            profiles = mapOf(remoteProfile.profileId to remoteProfile),
            payloadDigest = "legacy-remote-profile-test",
        )

        assertNull(DetectorProfiles.forVersion(YOUTUBE, "21.45.82", registry))
    }

    @Test
    fun remoteProfileDoesNotEnableCataloguedOrMismatchedVersions() {
        val remoteProfile = DetectorRegistryProfile(
            profileId = "youtube.shorts.remote.v1",
            packageName = YOUTUBE,
            strategyId = "accessibility_structure_v1",
            feedMarkerViewIds = setOf("$YOUTUBE:id/shorts_feed"),
            transitionViewIds = setOf("$YOUTUBE:id/shorts_pager"),
            identityStrategy = ItemIdentityStrategy.STRUCTURAL_NODE_PAIR,
            identityNodeViewId = "$YOUTUBE:id/shorts_item",
        )
        val registry = VerifiedDetectorRegistry(
            sequence = 1L,
            schemaVersion = 2,
            issuedAtEpochSeconds = System.currentTimeMillis() / 1_000L - 60,
            expiresAtEpochSeconds = System.currentTimeMillis() / 1_000L + 86_400,
            entries = listOf(
                DetectorRegistryEntry(
                    packageName = YOUTUBE,
                    versionName = "21.45.82",
                    status = DetectorRegistryEntryStatus.CATALOGUED,
                    profileId = null,
                    sourceUrl = "https://example.org/releases/21.45.82",
                ),
            ),
            profiles = mapOf(remoteProfile.profileId to remoteProfile),
            payloadDigest = "catalogued-remote-profile-test",
        )

        assertNull(DetectorProfiles.forVersion(YOUTUBE, "21.45.82", registry))
        assertNull(DetectorProfiles.forVersion(YOUTUBE, "21.46.83", registry))
        assertNull(DetectorProfiles.forVersion("com.instagram.android", "21.45.82", registry))
    }

    @Test
    fun unknownOrDisabledVersionCannotResolveToSharedProfile() {
        val profile = AppDetectorProfile(
            appId = "youtube",
            packageName = YOUTUBE,
            versionName = "21.45.82",
            feedMarkerViewIds = setOf("feed"),
            transitionViewIds = setOf("pager"),
            identityStrategy = ItemIdentityStrategy.STABLE_OPAQUE_ACCESSIBILITY_TOKEN,
            profileId = "youtube.shorts.v1",
        )
        val registry = registry(
            listOf(entry("21.45.82", DetectorRegistryEntryStatus.DISABLED)),
        )

        assertNull(
            DetectorProfiles.forVersion(
                packageName = YOUTUBE,
                versionName = "21.45.82",
                registry = registry,
                bundledProfiles = mapOf(profile.profileId to profile),
            ),
        )
        assertNull(
            DetectorProfiles.forVersion(
                packageName = YOUTUBE,
                versionName = "21.46.83",
                registry = registry,
                bundledProfiles = mapOf(profile.profileId to profile),
            ),
        )
    }

    private fun registry(entries: List<DetectorRegistryEntry>) = VerifiedDetectorRegistry(
        sequence = 1L,
        issuedAtEpochSeconds = System.currentTimeMillis() / 1_000L - 60,
        expiresAtEpochSeconds = System.currentTimeMillis() / 1_000L + 86_400,
        entries = entries,
        payloadDigest = "detector-profiles-test",
    )

    private fun entry(versionName: String, status: DetectorRegistryEntryStatus) =
        DetectorRegistryEntry(
            packageName = YOUTUBE,
            versionName = versionName,
            status = status,
            profileId = "youtube.shorts.v1".takeIf { status != DetectorRegistryEntryStatus.CATALOGUED },
            sourceUrl = "https://archive.example/youtube/$versionName",
        )

    private fun passingValidation(reportId: String) = DetectorVersionValidation(
        reportId = reportId,
        transitionCases = 200L,
        stationaryCases = 100L,
        deviceFamilies = 3L,
        precisionPercent = 98.0,
        recallPercent = 90.0,
        stationaryRepeats = 0L,
    )

    private companion object {
        const val YOUTUBE = "com.google.android.youtube"
    }
}
