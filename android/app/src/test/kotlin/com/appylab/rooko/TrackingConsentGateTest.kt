package com.appylab.rooko

import org.junit.Assert.assertEquals
import org.junit.Test

class TrackingConsentGateTest {
    @Test
    fun accessibilitySettingsRequireAffirmativeConsent() {
        assertEquals(false, TrackingConsentGate.canOpenAccessibilitySettings(false))
        assertEquals(true, TrackingConsentGate.canOpenAccessibilitySettings(true))
    }

    @Test
    fun selectedPackagesAreUnavailableUntilConsentIsAcknowledged() {
        val selected = setOf("youtube", "instagram")

        assertEquals(emptySet<String>(), TrackingConsentGate.allowedApps(selected, false))
        assertEquals(selected, TrackingConsentGate.allowedApps(selected, true))
    }
}
