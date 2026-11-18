package com.appylab.rooko

internal object DayVerificationInvalidationPolicy {
    const val PROFILE_UNAVAILABLE_REASON =
        "A selected app version did not have a validated detector profile"
    const val PROFILE_CHANGED_REASON = "A selected app detector profile changed during the day"

    fun reasonForProfileObservation(
        profileAvailable: Boolean,
        previousFingerprint: String?,
        currentFingerprint: String?,
    ): String? = when {
        !profileAvailable -> PROFILE_UNAVAILABLE_REASON
        previousFingerprint != null && previousFingerprint != currentFingerprint ->
            PROFILE_CHANGED_REASON
        else -> null
    }
}
