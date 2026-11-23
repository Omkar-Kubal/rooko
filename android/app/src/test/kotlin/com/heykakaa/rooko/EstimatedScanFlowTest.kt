package com.heykakaa.rooko

import android.view.accessibility.AccessibilityEvent
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class EstimatedScanFlowTest {
    @Test
    fun repeatedContentEventsCannotCrowdOutFreshItemScans() {
        val policy = EstimatedEventScanPolicy(250L)

        assertTrue(policy.shouldScan(AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED, 1_000L))
        repeat(40) { index ->
            assertFalse(policy.shouldScan(
                AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED,
                1_001L + index * 5L,
            ))
        }
        assertTrue(policy.shouldScan(AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED, 1_250L))
        assertTrue(policy.shouldScan(AccessibilityEvent.TYPE_VIEW_SCROLLED, 1_251L))
        assertTrue(policy.shouldScan(AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED, 1_252L))
    }

    @Test
    fun candidateConfirmationSurvivesAnEventBurstAndCanBeScheduledAgain() {
        val rechecks = PendingEstimateRechecks()
        val scheduled = mutableListOf<Runnable>()
        var scans = 0
        fun request() = rechecks.schedule("instagram", 150L, { runnable, _ ->
            scheduled.add(runnable)
        }) { scans++ }

        request()
        repeat(40) { request() }
        assertEquals(1, scheduled.size)
        scheduled.removeAt(0).run()
        assertEquals(1, scans)

        request()
        assertEquals(1, scheduled.size)
        scheduled.removeAt(0).run()
        assertEquals(2, scans)
    }

    @Test
    fun feedExitCancelsThePendingConfirmation() {
        val rechecks = PendingEstimateRechecks()
        val scheduled = mutableListOf<Runnable>()
        var scans = 0
        rechecks.schedule("instagram", 150L, { runnable, _ -> scheduled.add(runnable) }) {
            scans++
        }

        rechecks.cancel("instagram") { scheduled.remove(it) }
        assertTrue(scheduled.isEmpty())
        assertEquals(0, scans)
    }
}
