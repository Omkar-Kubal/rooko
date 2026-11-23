package com.heykakaa.rooko

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class DayVerificationInvalidationPolicyTest {
    @Test
    fun `profile availability gap invalidates immediately even if profile later returns`() {
        val gapReason = DayVerificationInvalidationPolicy.reasonForProfileObservation(
            profileAvailable = false,
            previousFingerprint = "validated-profile-v1",
            currentFingerprint = null,
        )
        val restoredReason = DayVerificationInvalidationPolicy.reasonForProfileObservation(
            profileAvailable = true,
            previousFingerprint = "validated-profile-v1",
            currentFingerprint = "validated-profile-v1",
        )

        assertEquals(
            "A selected app version did not have a validated detector profile",
            gapReason,
        )
        assertNull(restoredReason)
    }

    @Test
    fun `changed validated profile fingerprints invalidate the day`() {
        assertEquals(
            "A selected app detector profile changed during the day",
            DayVerificationInvalidationPolicy.reasonForProfileObservation(
                profileAvailable = true,
                previousFingerprint = "validated-profile-v1",
                currentFingerprint = "validated-profile-v2",
            ),
        )
        assertNull(
            DayVerificationInvalidationPolicy.reasonForProfileObservation(
                profileAvailable = true,
                previousFingerprint = "validated-profile-v1",
                currentFingerprint = "validated-profile-v1",
            ),
        )
    }
}
