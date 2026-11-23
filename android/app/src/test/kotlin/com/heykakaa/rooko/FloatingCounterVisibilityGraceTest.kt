package com.heykakaa.rooko

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class FloatingCounterVisibilityGraceTest {
    @Test
    fun repeatedTransientGapsKeepTheOriginalDeadline() {
        val grace = FloatingCounterVisibilityGrace(graceMillis = 1_500L)

        assertEquals(2_000L, grace.onTransientGap(nowMillis = 500L, counterVisible = true))
        assertEquals(2_000L, grace.onTransientGap(nowMillis = 1_000L, counterVisible = true))
        assertFalse(grace.shouldHideAt(nowMillis = 1_999L))
        assertTrue(grace.shouldHideAt(nowMillis = 2_000L))
        assertFalse(grace.shouldHideAt(nowMillis = 2_001L))
    }

    @Test
    fun recognizedFeedCancelsPendingHide() {
        val grace = FloatingCounterVisibilityGrace(graceMillis = 1_500L)
        grace.onTransientGap(nowMillis = 500L, counterVisible = true)

        grace.onRecognizedFeed()

        assertFalse(grace.shouldHideAt(nowMillis = 5_000L))
        assertEquals(6_600L, grace.onTransientGap(nowMillis = 5_100L, counterVisible = true))
    }

    @Test
    fun transientGapCannotShowAnOverlayThatWasAlreadyHidden() {
        val grace = FloatingCounterVisibilityGrace(graceMillis = 1_500L)

        assertNull(grace.onTransientGap(nowMillis = 500L, counterVisible = false))
        assertFalse(grace.shouldHideAt(nowMillis = 5_000L))
    }

    @Test
    fun definiteFeedExitCancelsPendingGrace() {
        val grace = FloatingCounterVisibilityGrace(graceMillis = 1_500L)
        grace.onTransientGap(nowMillis = 500L, counterVisible = true)

        grace.onDefiniteFeedExit()

        assertFalse(grace.shouldHideAt(nowMillis = 5_000L))
    }
}
