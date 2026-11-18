package com.appylab.rooko

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class ReelDetectorTest {
    private val youtubeProfile = AppDetectorProfile(
        appId = "youtube",
        packageName = "com.google.android.youtube",
        versionName = "21.43.523",
        feedMarkerViewIds = setOf("reel_watch_fragment_root", "reel_watch_pager_view_pager"),
        transitionViewIds = setOf("reel_watch_pager_view_pager"),
        identityStrategy = ItemIdentityStrategy.BOUNDED_TRANSITION_FINGERPRINT,
    )

    @Test
    fun unknownVersionFailsClosed() {
        val store = FakeCountStore()
        val detector = ReelDetector(listOf(youtubeProfile), store)
        detector.setSelectedApps(setOf("youtube"))

        val result = detector.observe(observation(versionName = "21.44.100"))

        assertEquals(DetectionOutcome.UnsupportedAppOrVersion, result)
        assertEquals(0, store.total)
    }

    @Test
    fun unselectedPackageDoesNotCount() {
        val store = FakeCountStore()
        val detector = ReelDetector(listOf(youtubeProfile), store)

        val result = detector.observe(observation())

        assertEquals(DetectionOutcome.NotSelected, result)
        assertEquals(0, store.total)
    }

    @Test
    fun unrecognizedScreenDoesNotCount() {
        val store = FakeCountStore()
        val detector = ReelDetector(listOf(youtubeProfile), store)
        detector.setSelectedApps(setOf("youtube"))

        val result = detector.observe(observation(isFeedVisible = false))

        assertEquals(DetectionOutcome.OutsideRecognizedFeed, result)
        assertEquals(0, store.total)
    }

    @Test
    fun stationaryItemDoesNotCountWithoutATransition() {
        val store = FakeCountStore()
        val detector = detector(store)

        assertEquals(DetectionOutcome.CandidateStarted, detector.observe(observation(at = 100)))
        assertEquals(DetectionOutcome.StationaryItem, detector.observe(observation(at = 850)))
        assertEquals(DetectionOutcome.StationaryItem, detector.observe(observation(at = 1_200)))
        assertEquals(0, store.total)
    }

    @Test
    fun itemSeenForLessThanOneSecondIsNotCounted() {
        val store = FakeCountStore()
        val detector = detector(store)

        detector.observe(
            observation(at = 0, identity = "item-a", transitionObserved = true),
        )
        val result = detector.observe(
            observation(at = 999, identity = "item-b", transitionObserved = true),
        )

        assertEquals(DetectionOutcome.CandidateStarted, result)
        assertEquals(0, store.total)
    }

    @Test
    fun firstEligibleItemRequiresOneFullSecondBeforeItCounts() {
        val store = FakeCountStore()
        val detector = detector(store)

        detector.observe(
            observation(at = 0, identity = "first-item", transitionObserved = true),
        )
        val beforeThreshold = detector.observe(
            observation(at = 999, identity = "first-item"),
        )

        assertEquals(DetectionOutcome.DwellNotReached, beforeThreshold)
        assertEquals(0, store.total)

        val atThreshold = detector.observe(
            observation(at = 1_000, identity = "first-item"),
        )

        assertEquals(
            DetectionOutcome.Counted(
                "youtube",
                "2026-11-06",
                CountConfidence.ESTIMATED,
            ),
            atThreshold,
        )
        assertEquals(1, store.total)
    }

    @Test
    fun oneSecondExposureRequiresIdentityRevalidatedFromCurrentRoot() {
        val store = FakeCountStore()
        val detector = detector(store)
        detector.observe(
            observation(
                at = 0,
                identity = "item-a",
                transitionObserved = true,
                identityRevalidatedAtCurrentRoot = true,
            ),
        )

        val withoutRevalidation = detector.observe(
            observation(
                at = 1_000,
                identity = "item-a",
                identityRevalidatedAtCurrentRoot = false,
            ),
        )
        assertEquals(DetectionOutcome.IdentityNotRevalidated, withoutRevalidation)
        assertEquals(0, store.total)

        val withRevalidation = detector.observe(
            observation(
                at = 1_001,
                identity = "item-a",
                identityRevalidatedAtCurrentRoot = true,
            ),
        )
        assertTrue(withRevalidation is DetectionOutcome.Counted)
        assertEquals(1, store.total)
    }

    @Test
    fun initialFeedItemCountsAfterOneSecondWithoutPagerTransition() {
        val store = FakeCountStore()
        val detector = detector(store)

        val started = detector.observe(
            observation(
                at = 0,
                identity = "initial-item",
                feedEntryObserved = true,
            ),
        )
        val beforeThreshold = detector.observe(
            observation(at = 999, identity = "initial-item"),
        )
        val atThreshold = detector.observe(
            observation(at = 1_000, identity = "initial-item"),
        )

        assertEquals(DetectionOutcome.CandidateStarted, started)
        assertEquals(DetectionOutcome.DwellNotReached, beforeThreshold)
        assertTrue(atThreshold is DetectionOutcome.Counted)
        assertEquals(1, store.total)
    }

    @Test
    fun initialFeedItemLeavingBeforeOneSecondIsNotCounted() {
        val store = FakeCountStore()
        val detector = detector(store)

        detector.observe(
            observation(
                at = 0,
                identity = "initial-item",
                feedEntryObserved = true,
            ),
        )
        val result = detector.observe(
            observation(at = 999, identity = null, isFeedVisible = false),
        )

        assertEquals(DetectionOutcome.OutsideRecognizedFeed, result)
        assertEquals(0, store.total)
    }

    @Test
    fun lateTransitionDoesNotBackdateOneSecondDwell() {
        val store = FakeCountStore()
        val detector = detector(store)
        detector.observe(observation(at = 0, identity = "item-a"))

        val lateSignal = detector.observe(
            observation(at = 900, identity = "item-a", transitionObserved = true),
        )
        val tooSoon = detector.observe(observation(at = 1_000, identity = "item-a"))
        val eligible = detector.observe(observation(at = 1_900, identity = "item-a"))

        assertEquals(DetectionOutcome.CandidateStarted, lateSignal)
        assertEquals(DetectionOutcome.DwellNotReached, tooSoon)
        assertTrue(eligible is DetectionOutcome.Counted)
        assertEquals(1, store.total)
    }

    @Test
    fun transitionAfterOneSecondDoesNotConfirmPreviousItemWithoutRevalidation() {
        val store = FakeCountStore()
        val detector = detector(store)

        detector.observe(observation(at = 100, identity = "item-a"))
        val result = detector.observe(
            observation(at = 1_100, identity = "item-b", transitionObserved = true),
        )

        assertEquals(DetectionOutcome.CandidateStarted, result)
        assertEquals(0, store.total)
    }

    @Test
    fun feedExitAfterThresholdCancelsUnconfirmedCandidate() {
        val store = FakeCountStore()
        val detector = detector(store)
        detector.observe(observation(at = 0, identity = "item-a", feedEntryObserved = true))

        val result = detector.observe(observation(at = 1_200, isFeedVisible = false))

        assertEquals(DetectionOutcome.OutsideRecognizedFeed, result)
        assertEquals(0, store.total)
    }

    @Test
    fun missingIdentityCancelsPendingCandidate() {
        val store = FakeCountStore()
        val detector = detector(store)
        detector.observe(observation(at = 0, identity = "item-a", feedEntryObserved = true))
        detector.observe(observation(at = 500, identity = null))

        val result = detector.observe(observation(at = 1_000, identity = "item-a"))

        assertEquals(DetectionOutcome.CandidateStarted, result)
        assertEquals(0, store.total)
    }

    @Test
    fun structuralIdentityCannotProduceConfirmedEvent() {
        val store = FakeCountStore()
        val confirmedProfile = youtubeProfile.copy(
            identityStrategy = ItemIdentityStrategy.STRUCTURAL_NODE_PAIR,
            identityNodeViewId = "shorts_item_container",
            confidence = CountConfidence.CONFIRMED,
        )
        val detector = ReelDetector(listOf(confirmedProfile), store)
        detector.setSelectedApps(setOf("youtube"))

        detector.observe(
            observation(
                at = 0,
                identity = "pair-a",
                identityStrategy = ItemIdentityStrategy.STRUCTURAL_NODE_PAIR,
                feedEntryObserved = true,
            ),
        )
        val result = detector.observe(
            observation(
                at = 1_000,
                identity = "pair-a",
                identityStrategy = ItemIdentityStrategy.STRUCTURAL_NODE_PAIR,
                identityRevalidatedAtCurrentRoot = true,
            ),
        )

        assertEquals(DetectionOutcome.MissingItemIdentity, result)
        assertEquals(0, store.total)
    }

    @Test
    fun rootStructuralPairCountsOnlyAsEstimatedAndCanStartChangedCandidate() {
        val store = FakeCountStore()
        val structuralProfile = youtubeProfile.copy(
            identityStrategy = ItemIdentityStrategy.STRUCTURAL_NODE_PAIR,
            identityNodeViewId = "shorts_item_container",
        )
        val detector = ReelDetector(listOf(structuralProfile), store).also {
            it.setSelectedApps(setOf("youtube"))
        }

        detector.observe(
            observation(
                identity = "pair-a",
                identityStrategy = ItemIdentityStrategy.STRUCTURAL_NODE_PAIR,
                feedEntryObserved = true,
                at = 0,
            ),
        )
        val firstCount = detector.observe(
            observation(
                identity = "pair-a",
                identityStrategy = ItemIdentityStrategy.STRUCTURAL_NODE_PAIR,
                identityRevalidatedAtCurrentRoot = true,
                at = 1_000,
            ),
        )
        val nextCandidate = detector.observe(
            observation(
                identity = "pair-b",
                identityStrategy = ItemIdentityStrategy.STRUCTURAL_NODE_PAIR,
                transitionObserved = true,
                at = 1_200,
            ),
        )
        val nextCount = detector.observe(
            observation(
                identity = "pair-b",
                identityStrategy = ItemIdentityStrategy.STRUCTURAL_NODE_PAIR,
                identityRevalidatedAtCurrentRoot = true,
                at = 2_200,
            ),
        )

        assertEquals(
            DetectionOutcome.Counted("youtube", "2026-11-06", CountConfidence.ESTIMATED),
            firstCount,
        )
        assertEquals(DetectionOutcome.CandidateStarted, nextCandidate)
        assertEquals(
            DetectionOutcome.Counted("youtube", "2026-11-06", CountConfidence.ESTIMATED),
            nextCount,
        )
        assertEquals(2, store.total)
    }

    @Test
    fun structuralSignatureChangeWithoutPagerTransitionCannotCountAnItem() {
        val store = FakeCountStore()
        val structuralProfile = youtubeProfile.copy(
            identityStrategy = ItemIdentityStrategy.STRUCTURAL_NODE_PAIR,
            identityNodeViewId = "shorts_item_container",
        )
        val detector = ReelDetector(listOf(structuralProfile), store).also {
            it.setSelectedApps(setOf("youtube"))
        }

        detector.observe(
            observation(
                identity = "pair-a",
                identityStrategy = ItemIdentityStrategy.STRUCTURAL_NODE_PAIR,
                feedEntryObserved = true,
                at = 0,
            ),
        )
        detector.observe(
            observation(
                identity = "pair-a",
                identityStrategy = ItemIdentityStrategy.STRUCTURAL_NODE_PAIR,
                identityRevalidatedAtCurrentRoot = true,
                at = 1_000,
            ),
        )
        detector.observe(
            observation(
                identity = "pair-b",
                identityStrategy = ItemIdentityStrategy.STRUCTURAL_NODE_PAIR,
                at = 1_100,
            ),
        )
        val stationaryLayoutChange = detector.observe(
            observation(
                identity = "pair-b",
                identityStrategy = ItemIdentityStrategy.STRUCTURAL_NODE_PAIR,
                identityRevalidatedAtCurrentRoot = true,
                at = 2_100,
            ),
        )

        assertEquals(DetectionOutcome.StationaryItem, stationaryLayoutChange)
        assertEquals(1, store.total)
    }

    @Test
    fun changedCurrentPagerIndexConfirmsTransitionWhenEventIndexesMatch() {
        val store = FakeCountStore()
        val detector = detector(store)
        val transitionObserved = hasObservedIndexTransition(
            previousIndex = 1,
            fromIndex = 2,
            toIndex = 2,
        )

        assertTrue(transitionObserved)
        detector.observe(
            observation(
                at = 100,
                identity = "item-2",
                transitionObserved = transitionObserved,
            ),
        )
        val result = detector.observe(
            observation(at = 1_100, identity = "item-2"),
        )

        assertEquals(
            DetectionOutcome.Counted(
                "youtube",
                "2026-11-06",
                CountConfidence.ESTIMATED,
            ),
            result,
        )
        assertEquals(1, store.total)
    }

    @Test
    fun sameCurrentPagerIndexDoesNotSignalASecondTransition() {
        assertFalse(
            hasObservedIndexTransition(
                previousIndex = 2,
                fromIndex = 2,
                toIndex = 2,
            ),
        )
    }

    @Test
    fun repeatedScrollEndingAtCurrentIndexDoesNotSignalAnotherItem() {
        assertFalse(
            hasObservedIndexTransition(
                previousIndex = 1,
                fromIndex = 0,
                toIndex = 1,
            ),
        )
    }

    @Test
    fun firstPagerItemWithoutPriorTransitionIsRecognizedAsFeedEntry() {
        assertTrue(
            isInitialFeedItem(
                previousIndex = null,
                fromIndex = 0,
                toIndex = 0,
            ),
        )
    }

    @Test
    fun firstFeedItemWithoutPagerIndexesIsRecognizedAsFeedEntry() {
        assertTrue(
            isInitialFeedItem(
                previousIndex = null,
                fromIndex = -1,
                toIndex = -1,
            ),
        )
    }

    @Test
    fun firstObservedSwipeDoesNotPretendThePriorItemWasSeen() {
        assertFalse(
            isInitialFeedItem(
                previousIndex = null,
                fromIndex = 0,
                toIndex = 1,
            ),
        )
    }

    @Test
    fun stableIdentityChangeCanStartNextCandidateWithoutPagerEvent() {
        val store = FakeCountStore()
        val stableProfile = youtubeProfile.copy(
            identityStrategy = ItemIdentityStrategy.STABLE_OPAQUE_ACCESSIBILITY_TOKEN,
            identityNodeViewId = "shorts_item_container",
        )
        val stableDetector = ReelDetector(listOf(stableProfile), store).also {
            it.setSelectedApps(setOf("youtube"))
        }

        stableDetector.observe(
            observation(
                identity = "item-a",
                identityStrategy = ItemIdentityStrategy.STABLE_OPAQUE_ACCESSIBILITY_TOKEN,
                feedEntryObserved = true,
                at = 0,
            ),
        )
        val firstItem = stableDetector.observe(
            observation(
                identity = "item-a",
                identityStrategy = ItemIdentityStrategy.STABLE_OPAQUE_ACCESSIBILITY_TOKEN,
                at = 1_000,
            ),
        )
        val nextCandidate = stableDetector.observe(
            observation(
                identity = "item-b",
                identityStrategy = ItemIdentityStrategy.STABLE_OPAQUE_ACCESSIBILITY_TOKEN,
                at = 1_200,
            ),
        )
        val nextItem = stableDetector.observe(
            observation(
                identity = "item-b",
                identityStrategy = ItemIdentityStrategy.STABLE_OPAQUE_ACCESSIBILITY_TOKEN,
                at = 2_200,
            ),
        )

        assertTrue(firstItem is DetectionOutcome.Counted)
        assertEquals(DetectionOutcome.CandidateStarted, nextCandidate)
        assertTrue(nextItem is DetectionOutcome.Counted)
        assertEquals(2, store.total)
    }

    @Test
    fun revisitingAnItemWithinFiveMinutesDoesNotCountAgain() {
        val store = FakeCountStore()
        val detector = detector(store)

        detector.observe(observation(at = 0, identity = "item-a", feedEntryObserved = true))
        detector.observe(observation(at = 1_000, identity = "item-a"))
        detector.observe(
            observation(at = 1_500, identity = "item-b", transitionObserved = true),
        )
        detector.observe(observation(at = 2_500, identity = "item-b"))
        detector.observe(observation(at = 2_600, isFeedVisible = false))

        detector.observe(
            observation(at = 10_000, identity = "item-a", transitionObserved = true),
        )
        val revisit = detector.observe(observation(at = 11_000, identity = "item-a"))

        assertEquals(DetectionOutcome.RecentDuplicate, revisit)
        assertEquals(2, store.total)
    }

    @Test
    fun revisitAfterFiveMinutesCanCountAgain() {
        val store = FakeCountStore()
        val detector = detector(store)

        detector.observe(
            observation(at = 0, identity = "item-a", transitionObserved = true),
        )
        detector.observe(observation(at = 1_000, identity = "item-a"))
        detector.observe(observation(at = 1_000, isFeedVisible = false))
        detector.observe(
            observation(at = 301_000, identity = "item-a", transitionObserved = true),
        )
        val revisit = detector.observe(observation(at = 302_000, identity = "item-a"))

        assertTrue(revisit is DetectionOutcome.Counted)
        assertEquals(2, store.total)
    }

    private fun detector(store: FakeCountStore) = ReelDetector(listOf(youtubeProfile), store).also {
        it.setSelectedApps(setOf("youtube"))
    }

    private fun observation(
        versionName: String = "21.43.523",
        identity: String? = "item-a",
        isFeedVisible: Boolean = true,
        transitionObserved: Boolean = false,
        feedEntryObserved: Boolean = false,
        identityRevalidatedAtCurrentRoot: Boolean = true,
        identityStrategy: ItemIdentityStrategy = ItemIdentityStrategy.BOUNDED_TRANSITION_FINGERPRINT,
        at: Long = 0,
    ) = ReelObservation(
        packageName = "com.google.android.youtube",
        versionName = versionName,
        isFeedVisible = isFeedVisible,
        itemIdentity = identity?.let {
            ItemIdentity(it, identityStrategy)
        },
        transitionObserved = transitionObserved,
        feedEntryObserved = feedEntryObserved,
        identityRevalidatedAtCurrentRoot = identityRevalidatedAtCurrentRoot,
        elapsedRealtimeMillis = at,
        localDateKey = "2026-11-06",
    )

    private class FakeCountStore : CountStore {
        private val recent = mutableMapOf<String, Long>()
        var total = 0
            private set

        override fun recordIfNew(
            appId: String,
            itemIdentityHash: String,
            elapsedRealtimeMillis: Long,
            localDateKey: String,
            confidence: CountConfidence,
            wallClockMillis: Long,
        ): Boolean {
            val key = "$appId:$itemIdentityHash"
            val previous = recent[key]
            if (previous != null && elapsedRealtimeMillis >= previous &&
                elapsedRealtimeMillis - previous < ReelDetector.DEDUPE_WINDOW_MILLIS
            ) {
                return false
            }
            recent[key] = elapsedRealtimeMillis
            total += 1
            return true
        }
    }
}
