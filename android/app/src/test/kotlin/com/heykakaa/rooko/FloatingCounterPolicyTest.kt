package com.heykakaa.rooko

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class FloatingCounterPolicyTest {
    private fun canShow(
        enabled: Boolean = true,
        overlayGranted: Boolean = true,
        trackingConsent: Boolean = true,
        serviceOperational: Boolean = true,
        selected: Boolean = true,
        profileAvailable: Boolean = true,
        recognizedFeed: Boolean = true,
    ) = FloatingCounterPolicy.canShow(
        enabled, overlayGranted, trackingConsent, serviceOperational,
        selected, profileAvailable, recognizedFeed,
    )

    @Test
    fun displaysOnlyWhenAllPermissionsAndFeedSignalsArePresent() {
        assertTrue(canShow())
        assertFalse(canShow(enabled = false))
        assertFalse(canShow(overlayGranted = false))
        assertFalse(canShow(trackingConsent = false))
        assertFalse(canShow(serviceOperational = false))
        assertFalse(canShow(selected = false))
        assertFalse(canShow(profileAvailable = false))
        assertFalse(canShow(recognizedFeed = false))
    }
}
