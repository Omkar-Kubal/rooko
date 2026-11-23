package com.heykakaa.rooko

internal data class DailyVerificationCandidate(
    val localDate: String,
    val startedAtMillis: Long,
    val lastCheckpointMillis: Long,
    val timeZoneId: String,
    val offsetSeconds: Int,
    val selectedAppFingerprint: String,
    val profileFingerprint: String,
    val processInstanceId: String,
    val valid: Boolean,
)

internal data class DailyVerificationEnvironment(
    val nowMillis: Long,
    val timeZoneId: String,
    val offsetSeconds: Int,
    val selectedAppFingerprint: String,
    val profileFingerprint: String,
    val processInstanceId: String,
    val trackingAvailable: Boolean,
)

internal object DailyVerificationPolicy {
    const val START_WINDOW_MILLIS = 30_000L
    const val MAX_CHECKPOINT_GAP_MILLIS = 10 * 60 * 1_000L

    fun canStart(dayStartMillis: Long, environment: DailyVerificationEnvironment): Boolean =
        environment.trackingAvailable &&
            (environment.nowMillis - dayStartMillis).absoluteValue() <= START_WINDOW_MILLIS

    fun canContinue(
        candidate: DailyVerificationCandidate,
        environment: DailyVerificationEnvironment,
    ): Boolean {
        val gap = environment.nowMillis - candidate.lastCheckpointMillis
        return candidate.valid &&
            environment.trackingAvailable &&
            gap in 0..MAX_CHECKPOINT_GAP_MILLIS &&
            environment.nowMillis >= candidate.startedAtMillis &&
            candidate.timeZoneId == environment.timeZoneId &&
            candidate.selectedAppFingerprint == environment.selectedAppFingerprint &&
            candidate.profileFingerprint == environment.profileFingerprint &&
            candidate.processInstanceId == environment.processInstanceId
    }

    fun canComplete(
        candidate: DailyVerificationCandidate,
        dayStartMillis: Long,
        nextDayStartMillis: Long,
        environment: DailyVerificationEnvironment,
    ): Boolean {
        val completionDelay = environment.nowMillis - nextDayStartMillis
        val lastCheckpointAge = nextDayStartMillis - candidate.lastCheckpointMillis
        return canContinue(candidate, environment) &&
            (candidate.startedAtMillis - dayStartMillis).absoluteValue() <= START_WINDOW_MILLIS &&
            completionDelay in 0..MAX_CHECKPOINT_GAP_MILLIS &&
            lastCheckpointAge in 0..MAX_CHECKPOINT_GAP_MILLIS
    }

    private fun Long.absoluteValue(): Long = if (this < 0) -this else this
}
