package com.appylab.rooko

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class CandidateDeadlineGuardTest {
    private val profile = AppDetectorProfile(
        appId = "instagram",
        packageName = "com.instagram.android",
        versionName = "454.0.0.54.77",
        feedMarkerViewIds = setOf("clips_viewer_view_pager"),
        transitionViewIds = setOf("clips_viewer_view_pager"),
    )

    @Test
    fun deadlineRequiresConsentPermissionSelectionAndExactVersion() {
        val allowed = CandidateDeadlineGuard.canRecheck(
            profile, setOf("instagram"), true, true, "454.0.0.54.77",
        )
        assertTrue(allowed)
        assertFalse(CandidateDeadlineGuard.canRecheck(profile, setOf("instagram"), false, true, "454.0.0.54.77"))
        assertFalse(CandidateDeadlineGuard.canRecheck(profile, setOf("instagram"), true, false, "454.0.0.54.77"))
        assertFalse(CandidateDeadlineGuard.canRecheck(profile, emptySet(), true, true, "454.0.0.54.77"))
        assertFalse(CandidateDeadlineGuard.canRecheck(profile, setOf("instagram"), true, true, "454.0.0.54.78"))
    }

    @Test
    fun deadlineRequiresCurrentRootIdentityToMatchTheCandidate() {
        assertTrue(CandidateDeadlineGuard.hasMatchingCurrentIdentity("candidate", "candidate"))
        assertFalse(CandidateDeadlineGuard.hasMatchingCurrentIdentity("candidate", "changed"))
        assertFalse(CandidateDeadlineGuard.hasMatchingCurrentIdentity("candidate", null))
        assertFalse(CandidateDeadlineGuard.hasMatchingCurrentIdentity("", ""))
    }

    @Test
    fun boundedTransitionFingerprintCannotRevalidateWithoutRootItemEvidence() {
        assertFalse(
            CandidateDeadlineGuard.hasCurrentCandidateAtDeadline(
                identityStrategy = ItemIdentityStrategy.BOUNDED_TRANSITION_FINGERPRINT,
                candidateIdentityHash = "candidate",
                activeIdentityHash = "candidate",
                candidateIndex = 2,
                activeIndex = 2,
                feedVisible = true,
                currentRootIdentityHash = null,
            ),
        )
    }

    @Test
    fun structuralCandidateMustMatchPairRederviedFromCurrentRoot() {
        assertTrue(
            CandidateDeadlineGuard.hasCurrentCandidateAtDeadline(
                identityStrategy = ItemIdentityStrategy.STRUCTURAL_NODE_PAIR,
                candidateIdentityHash = "candidate",
                activeIdentityHash = "candidate",
                candidateIndex = 2,
                activeIndex = 2,
                feedVisible = true,
                currentRootIdentityHash = "candidate",
            ),
        )
        assertFalse(
            CandidateDeadlineGuard.hasCurrentCandidateAtDeadline(
                identityStrategy = ItemIdentityStrategy.STRUCTURAL_NODE_PAIR,
                candidateIdentityHash = "candidate",
                activeIdentityHash = "candidate",
                candidateIndex = 2,
                activeIndex = 2,
                feedVisible = true,
                currentRootIdentityHash = null,
            ),
        )
        assertFalse(
            CandidateDeadlineGuard.hasCurrentCandidateAtDeadline(
                identityStrategy = ItemIdentityStrategy.STRUCTURAL_NODE_PAIR,
                candidateIdentityHash = "candidate",
                activeIdentityHash = "candidate",
                candidateIndex = 2,
                activeIndex = 2,
                feedVisible = true,
                currentRootIdentityHash = "changed",
            ),
        )
        assertFalse(
            CandidateDeadlineGuard.hasCurrentCandidateAtDeadline(
                identityStrategy = ItemIdentityStrategy.STRUCTURAL_NODE_PAIR,
                candidateIdentityHash = "candidate",
                activeIdentityHash = "newer-active-item",
                candidateIndex = 2,
                activeIndex = 2,
                feedVisible = true,
                currentRootIdentityHash = "candidate",
            ),
        )
        assertFalse(
            CandidateDeadlineGuard.hasCurrentCandidateAtDeadline(
                identityStrategy = ItemIdentityStrategy.STRUCTURAL_NODE_PAIR,
                candidateIdentityHash = "candidate",
                activeIdentityHash = "candidate",
                candidateIndex = 2,
                activeIndex = 3,
                feedVisible = false,
                currentRootIdentityHash = "candidate",
            ),
        )
    }

    @Test
    fun stableCandidateStillRequiresMatchingIdentityFromCurrentRoot() {
        assertTrue(
            CandidateDeadlineGuard.hasCurrentCandidateAtDeadline(
                identityStrategy = ItemIdentityStrategy.STABLE_OPAQUE_ACCESSIBILITY_TOKEN,
                candidateIdentityHash = "candidate",
                activeIdentityHash = "candidate",
                candidateIndex = 2,
                activeIndex = 2,
                feedVisible = true,
                currentRootIdentityHash = "candidate",
            ),
        )
        assertFalse(
            CandidateDeadlineGuard.hasCurrentCandidateAtDeadline(
                identityStrategy = ItemIdentityStrategy.STABLE_OPAQUE_ACCESSIBILITY_TOKEN,
                candidateIdentityHash = "candidate",
                activeIdentityHash = "candidate",
                candidateIndex = 2,
                activeIndex = 2,
                feedVisible = true,
                currentRootIdentityHash = null,
            ),
        )
        assertFalse(
            CandidateDeadlineGuard.hasCurrentCandidateAtDeadline(
                identityStrategy = ItemIdentityStrategy.NONE,
                candidateIdentityHash = "candidate",
                activeIdentityHash = "candidate",
                candidateIndex = 2,
                activeIndex = 2,
                feedVisible = true,
                currentRootIdentityHash = "candidate",
            ),
        )
    }

    @Test
    fun identityScanMustBeCompleteAndContainExactlyOneVisibleNode() {
        assertTrue(CandidateDeadlineGuard.hasUnambiguousIdentityScan(1, true))
        assertFalse(CandidateDeadlineGuard.hasUnambiguousIdentityScan(1, false))
        assertFalse(CandidateDeadlineGuard.hasUnambiguousIdentityScan(0, true))
        assertFalse(CandidateDeadlineGuard.hasUnambiguousIdentityScan(2, true))
    }

    @Test
    fun feedEntryWithoutPagerEventRequiresVisibleFeedAndRootIdentity() {
        assertTrue(
            CandidateDeadlineGuard.shouldSeedFirstRootIdentityFeedEntry(
                feedVisible = true,
                activeItemExists = false,
                identityStrategy = ItemIdentityStrategy.STABLE_OPAQUE_ACCESSIBILITY_TOKEN,
                identityHash = "candidate",
                fromIndex = -1,
                toIndex = -1,
            ),
        )
        assertFalse(
            CandidateDeadlineGuard.shouldSeedFirstRootIdentityFeedEntry(
                feedVisible = false,
                activeItemExists = false,
                identityStrategy = ItemIdentityStrategy.STABLE_OPAQUE_ACCESSIBILITY_TOKEN,
                identityHash = "candidate",
                fromIndex = -1,
                toIndex = -1,
            ),
        )
        assertFalse(
            CandidateDeadlineGuard.shouldSeedFirstRootIdentityFeedEntry(
                feedVisible = true,
                activeItemExists = false,
                identityStrategy = ItemIdentityStrategy.STABLE_OPAQUE_ACCESSIBILITY_TOKEN,
                identityHash = null,
                fromIndex = -1,
                toIndex = -1,
            ),
        )
        assertFalse(
            CandidateDeadlineGuard.shouldSeedFirstRootIdentityFeedEntry(
                feedVisible = true,
                activeItemExists = true,
                identityStrategy = ItemIdentityStrategy.STABLE_OPAQUE_ACCESSIBILITY_TOKEN,
                identityHash = "candidate",
                fromIndex = -1,
                toIndex = -1,
            ),
        )
        assertFalse(
            CandidateDeadlineGuard.shouldSeedFirstRootIdentityFeedEntry(
                feedVisible = true,
                activeItemExists = false,
                identityStrategy = ItemIdentityStrategy.BOUNDED_TRANSITION_FINGERPRINT,
                identityHash = "candidate",
                fromIndex = -1,
                toIndex = -1,
            ),
        )
        assertTrue(
            CandidateDeadlineGuard.shouldSeedFirstRootIdentityFeedEntry(
                feedVisible = true,
                activeItemExists = false,
                identityStrategy = ItemIdentityStrategy.STRUCTURAL_NODE_PAIR,
                identityHash = "candidate",
                fromIndex = -1,
                toIndex = -1,
            ),
        )
    }

    @Test
    fun foreignForegroundWindowCancelsActiveCandidate() {
        assertTrue(
            CandidateDeadlineGuard.foreignWindowReplacedCandidate(
                "com.instagram.android", "com.android.launcher",
            ),
        )
        assertFalse(
            CandidateDeadlineGuard.foreignWindowReplacedCandidate(
                "com.instagram.android", "com.instagram.android",
            ),
        )
    }
}
