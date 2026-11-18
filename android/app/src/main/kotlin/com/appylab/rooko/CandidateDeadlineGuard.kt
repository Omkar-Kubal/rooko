package com.appylab.rooko

internal object CandidateDeadlineGuard {
    fun shouldSeedFirstRootIdentityFeedEntry(
        feedVisible: Boolean,
        activeItemExists: Boolean,
        identityStrategy: ItemIdentityStrategy,
        identityHash: String?,
        fromIndex: Int,
        toIndex: Int,
    ): Boolean = feedVisible && !activeItemExists &&
        identityStrategy in setOf(
            ItemIdentityStrategy.STABLE_OPAQUE_ACCESSIBILITY_TOKEN,
            ItemIdentityStrategy.STRUCTURAL_NODE_PAIR,
        ) &&
        !identityHash.isNullOrBlank() &&
        isInitialFeedItem(previousIndex = null, fromIndex = fromIndex, toIndex = toIndex)

    fun hasUnambiguousIdentityScan(identityNodeCount: Int, scanComplete: Boolean): Boolean =
        scanComplete && identityNodeCount == 1

    fun hasMatchingCurrentIdentity(
        candidateIdentityHash: String,
        currentRootIdentityHash: String?,
    ): Boolean = candidateIdentityHash.isNotBlank() &&
        currentRootIdentityHash == candidateIdentityHash

    /** Requires the strategy's identity to be rederived from the current root at dwell deadline. */
    fun hasCurrentCandidateAtDeadline(
        identityStrategy: ItemIdentityStrategy,
        candidateIdentityHash: String,
        activeIdentityHash: String?,
        candidateIndex: Int,
        activeIndex: Int,
        feedVisible: Boolean,
        currentRootIdentityHash: String?,
    ): Boolean {
        if (
            candidateIdentityHash.isBlank() ||
            activeIdentityHash != candidateIdentityHash ||
            !feedVisible
        ) return false

        if (activeIndex != candidateIndex) return false
        return when (identityStrategy) {
            ItemIdentityStrategy.STABLE_OPAQUE_ACCESSIBILITY_TOKEN ->
                hasMatchingCurrentIdentity(candidateIdentityHash, currentRootIdentityHash)
            ItemIdentityStrategy.STRUCTURAL_NODE_PAIR ->
                hasMatchingCurrentIdentity(candidateIdentityHash, currentRootIdentityHash)
            ItemIdentityStrategy.BOUNDED_TRANSITION_FINGERPRINT,
            ItemIdentityStrategy.NONE,
            -> false
        }
    }

    fun foreignWindowReplacedCandidate(
        candidatePackage: String,
        windowPackage: String?,
    ): Boolean = candidatePackage != windowPackage

    fun canRecheck(
        profile: AppDetectorProfile,
        selectedAppIds: Set<String>,
        consentAcknowledged: Boolean,
        serviceEnabled: Boolean,
        installedVersion: String?,
    ): Boolean = consentAcknowledged && serviceEnabled &&
        profile.appId in selectedAppIds && installedVersion == profile.versionName
}
