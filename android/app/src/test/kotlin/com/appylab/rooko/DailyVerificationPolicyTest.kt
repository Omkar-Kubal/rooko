package com.appylab.rooko

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class DailyVerificationPolicyTest {
    private val candidate = DailyVerificationCandidate(
        localDate = "2026-11-13",
        startedAtMillis = 1_000_000L,
        lastCheckpointMillis = 86_100_000L,
        timeZoneId = "Asia/Kolkata",
        offsetSeconds = 19_800,
        selectedAppFingerprint = "instagram,youtube",
        profileFingerprint = "profiles-v1",
        processInstanceId = "process-a",
        valid = true,
    )

    private fun environment(
        now: Long = 86_400_000L,
        timeZoneId: String = "Asia/Kolkata",
        offsetSeconds: Int = 19_800,
        selectedAppFingerprint: String = "instagram,youtube",
        profileFingerprint: String = "profiles-v1",
        processInstanceId: String = "process-a",
        trackingAvailable: Boolean = true,
    ) = DailyVerificationEnvironment(
        nowMillis = now,
        timeZoneId = timeZoneId,
        offsetSeconds = offsetSeconds,
        selectedAppFingerprint = selectedAppFingerprint,
        profileFingerprint = profileFingerprint,
        processInstanceId = processInstanceId,
        trackingAvailable = trackingAvailable,
    )

    @Test
    fun `starts only at local midnight with complete monitoring evidence`() {
        assertTrue(
            DailyVerificationPolicy.canStart(
                1_000_000L,
                environment(now = 1_000_000L),
            ),
        )
        assertFalse(
            DailyVerificationPolicy.canStart(
                1_000_000L,
                environment(now = 1_060_001L),
            ),
        )
        assertFalse(
            DailyVerificationPolicy.canStart(
                1_000_000L,
                environment(now = 1_000_000L, trackingAvailable = false),
            ),
        )
    }

    @Test
    fun `keeps a day eligible only with continuous matching evidence`() {
        assertTrue(DailyVerificationPolicy.canContinue(candidate, environment()))
        assertFalse(
            DailyVerificationPolicy.canContinue(
                candidate,
                environment(now = candidate.lastCheckpointMillis + 600_001L),
            ),
        )
        assertFalse(
            DailyVerificationPolicy.canContinue(
                candidate,
                environment(selectedAppFingerprint = "youtube"),
            ),
        )
        assertFalse(
            DailyVerificationPolicy.canContinue(
                candidate,
                environment(profileFingerprint = "profiles-v2"),
            ),
        )
        assertFalse(
            DailyVerificationPolicy.canContinue(
                candidate,
                environment(timeZoneId = "Europe/Paris", offsetSeconds = 3600),
            ),
        )
        assertFalse(
            DailyVerificationPolicy.canContinue(
                candidate,
                environment(processInstanceId = "process-b"),
            ),
        )
        assertFalse(
            DailyVerificationPolicy.canContinue(
                candidate,
                environment(trackingAvailable = false),
            ),
        )
    }

    @Test
    fun `completes only a fully observed day at its next local midnight`() {
        assertTrue(
            DailyVerificationPolicy.canComplete(
                candidate = candidate,
                dayStartMillis = 1_000_000L,
                nextDayStartMillis = 86_400_000L,
                environment = environment(),
            ),
        )
        assertFalse(
            DailyVerificationPolicy.canComplete(
                candidate = candidate,
                dayStartMillis = 1_000_000L,
                nextDayStartMillis = 86_400_000L,
                environment = environment(now = 87_000_001L),
            ),
        )
        assertFalse(
            DailyVerificationPolicy.canComplete(
                candidate = candidate,
                dayStartMillis = 1_000_000L,
                nextDayStartMillis = 86_400_000L,
                environment = environment(now = 85_000_000L),
            ),
        )
    }
}
