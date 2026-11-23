package com.heykakaa.rooko

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class ValidatedFeedExitPolicyTest {
    private fun shouldReportExit(
        previouslyRecognized: Boolean = true,
        profileAvailable: Boolean = true,
        selected: Boolean = true,
        consentAcknowledged: Boolean = true,
        serviceOperational: Boolean = true,
        feedVisibleNow: Boolean = false,
    ) = ValidatedFeedExitPolicy.shouldReport(
        previouslyRecognized = previouslyRecognized,
        profileAvailable = profileAvailable,
        selected = selected,
        consentAcknowledged = consentAcknowledged,
        serviceOperational = serviceOperational,
        feedVisibleNow = feedVisibleNow,
    )

    @Test
    fun `reports only a transition out of a currently validated selected feed`() {
        assertTrue(shouldReportExit())
        assertFalse(shouldReportExit(previouslyRecognized = false))
        assertFalse(shouldReportExit(profileAvailable = false))
        assertFalse(shouldReportExit(selected = false))
        assertFalse(shouldReportExit(consentAcknowledged = false))
        assertFalse(shouldReportExit(serviceOperational = false))
        assertFalse(shouldReportExit(feedVisibleNow = true))
    }
}
