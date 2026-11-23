package com.heykakaa.rooko

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Test

class DebugEventEstimateTest {
    private class MemoryStore : CountStore {
        var recorded = 0
        var lastConfidence: CountConfidence? = null
        override fun recordIfNew(
            appId: String,
            itemIdentityHash: String,
            elapsedRealtimeMillis: Long,
            localDateKey: String,
            confidence: CountConfidence,
            wallClockMillis: Long,
        ): Boolean {
            recorded++
            lastConfidence = confidence
            return true
        }
    }

    @Test
    fun installedVersionsResolveWithoutPromotingProductionProfiles() {
        assertNotNull(DebugTextProfiles.forVersion(
            "com.instagram.android", "455.0.0.51.72",
        ))
        assertNotNull(DebugTextProfiles.forVersion(
            "com.google.android.youtube", "21.45.82",
        ))
        assertNotNull(DebugTextProfiles.forVersion("com.instagram.android", "new-version"))
        assertNull(DebugTextProfiles.forVersion("com.instagram.android", ""))
        assertNull(DebugTextProfiles.forVersion("com.example.other", "455.0.0.51.72"))
        assertNull(DetectorProfiles.forVersion("com.instagram.android", "455.0.0.51.72"))
    }

    @Test
    fun stableKeyCountsOnceAsEstimatedAndFeedExitClearsState() {
        val store = MemoryStore()
        val counter = DebugEventEstimateCounter(store)
        fun observe(key: String?, time: Long, visible: Boolean = true) = counter.observe(
            "instagram", key, visible, time, "2026-11-14", 1_000L + time,
        )

        assertEquals(DebugEstimateOutcome.Candidate, observe("a", 0))
        assertEquals(DebugEstimateOutcome.Waiting, observe("a", 100))
        assertEquals(DebugEstimateOutcome.Counted, observe("a", 150))
        assertEquals(DebugEstimateOutcome.Stationary, observe("a", 500))
        assertEquals(DebugEstimateOutcome.Candidate, observe("b", 600))
        assertEquals(DebugEstimateOutcome.Counted, observe("b", 750))
        assertEquals(2, store.recorded)
        assertEquals(CountConfidence.ESTIMATED, store.lastConfidence)
        assertEquals(DebugEstimateOutcome.OutsideFeed, observe(null, 800, false))
        assertEquals(DebugEstimateOutcome.Stationary, observe("b", 900))
        assertEquals(2, store.recorded)
        counter.suppressInitialItem("instagram")
        assertEquals(DebugEstimateOutcome.BaselineSeeded, observe("b", 950))
        assertEquals(2, store.recorded)
    }

    @Test
    fun tenDistinctSettledReelsProduceTenEstimatedEvents() {
        val store = MemoryStore()
        val counter = DebugEventEstimateCounter(store)

        for (index in 0 until 10) {
            val key = "reel-$index"
            val at = index * 1_000L
            assertEquals(
                DebugEstimateOutcome.Candidate,
                counter.observe("instagram", key, true, at, "2026-11-23", at),
            )
            assertEquals(
                DebugEstimateOutcome.Counted,
                counter.observe("instagram", key, true, at + 150L, "2026-11-23", at + 150L),
            )
            assertEquals(
                DebugEstimateOutcome.Stationary,
                counter.observe("instagram", key, true, at + 300L, "2026-11-23", at + 300L),
            )
        }

        assertEquals(10, store.recorded)
        assertEquals(CountConfidence.ESTIMATED, store.lastConfidence)
    }

    @Test
    fun transientLabelsProduceOnlyAProcessLocalDigest() {
        val one = DebugTextKeyHasher("one")
        val two = DebugTextKeyHasher("two")
        val labels = listOf(" example   label ")
        val digest = one.digest(labels)
        assertEquals(64, digest?.length)
        assertEquals(digest, one.digest(listOf("example label")))
        assertEquals(false, digest == two.digest(labels))
    }

    @Test
    fun returningToSameItemDoesNotRecountWithinDedupeWindow() {
        val store = MemoryStore()
        val counter = DebugEventEstimateCounter(store)
        fun observe(key: String?, time: Long, visible: Boolean = true) = counter.observe(
            "youtube", key, visible, time, "2026-11-14", 1_000L + time,
        )

        assertEquals(DebugEstimateOutcome.Candidate, observe("short-a", 0))
        assertEquals(DebugEstimateOutcome.Counted, observe("short-a", 150))
        assertEquals(DebugEstimateOutcome.OutsideFeed, observe(null, 1_000, false))
        assertEquals(DebugEstimateOutcome.Stationary, observe("short-a", 2_000))
        assertEquals(1, store.recorded)
        assertEquals(DebugEstimateOutcome.Candidate, observe("short-b", 2_100))
        assertEquals(DebugEstimateOutcome.Counted, observe("short-b", 2_250))
        assertEquals(2, store.recorded)
    }
}
