package com.appylab.rooko

/** Exact versions resolve through verified, bounded remote profiles or legacy bundled profiles. */
internal object DetectorProfiles {
    /** No production profile currently passes the independent item-identity and accuracy gates. */
    private val bundledProfilesById = emptyList<AppDetectorProfile>().associateBy { it.profileId }

    fun forVersion(
        packageName: String,
        versionName: String,
        registry: VerifiedDetectorRegistry? = null,
        bundledProfiles: Map<String, AppDetectorProfile> = bundledProfilesById,
    ): AppDetectorProfile? {
        val verifiedRegistry = registry?.takeIf { it.isUnexpired() } ?: return null
        if (verifiedRegistry.schemaVersion !in 1..2) return null
        val entry = verifiedRegistry.entryFor(packageName, versionName) ?: return null
        if (entry.status != DetectorRegistryEntryStatus.SUPPORTED) return null
        if (verifiedRegistry.schemaVersion == 2 && entry.validation?.passesGate() != true) return null
        val profileId = entry.profileId ?: return null
        val remoteProfile = if (verifiedRegistry.schemaVersion == 2) {
            verifiedRegistry.profileFor(profileId, packageName)?.toAppProfile(versionName)
        } else {
            null
        }
        val bundledProfile = bundledProfiles[profileId]
            ?.takeIf { it.confidence == CountConfidence.CONFIRMED }
        val profile = remoteProfile ?: bundledProfile
        return profile
            ?.takeIf { it.packageName == packageName }
            ?.copy(versionName = versionName)
    }

    fun forPackage(
        packageName: String,
        registry: VerifiedDetectorRegistry? = null,
    ): AppDetectorProfile? = registry?.entries
        ?.firstOrNull {
            it.packageName == packageName && it.status == DetectorRegistryEntryStatus.SUPPORTED
        }
        ?.let { forVersion(packageName, it.versionName, registry) }

    fun packageNamesForSelection(
        selectedAppIds: Set<String>,
        installedVersion: (String) -> String?,
        registry: VerifiedDetectorRegistry? = null,
    ): Array<String> = SupportedAppsNative.all.mapNotNull { app ->
        if (app.appId !in selectedAppIds) return@mapNotNull null
        val versionName = installedVersion(app.packageName) ?: return@mapNotNull null
        if (forVersion(app.packageName, versionName, registry) == null) return@mapNotNull null
        app.packageName
    }.toTypedArray()

    fun all(registry: VerifiedDetectorRegistry? = null): List<AppDetectorProfile> =
        registry?.entries.orEmpty().mapNotNull { entry ->
            if (entry.status != DetectorRegistryEntryStatus.SUPPORTED) return@mapNotNull null
            forVersion(entry.packageName, entry.versionName, registry)
        }

    private fun DetectorRegistryProfile.toAppProfile(versionName: String): AppDetectorProfile? {
        val app = SupportedAppsNative.all.firstOrNull { it.packageName == packageName } ?: return null
        return AppDetectorProfile(
            appId = app.appId,
            packageName = packageName,
            versionName = versionName,
            feedMarkerViewIds = feedMarkerViewIds,
            transitionViewIds = transitionViewIds,
            identityStrategy = identityStrategy,
            identityNodeViewId = identityNodeViewId,
            fixtureRevision = "signed-remote",
            // Registry support is granted only after the per-version accuracy gate passes.
            confidence = CountConfidence.CONFIRMED,
            profileId = profileId,
        )
    }
}

internal data class SupportedAppDefinition(
    val appId: String,
    val packageName: String,
)

internal object SupportedAppsNative {
    val all = listOf(
        SupportedAppDefinition("youtube", "com.google.android.youtube"),
        SupportedAppDefinition("instagram", "com.instagram.android"),
    )

    fun byId(appId: String): SupportedAppDefinition? =
        all.firstOrNull { it.appId == appId }
}
