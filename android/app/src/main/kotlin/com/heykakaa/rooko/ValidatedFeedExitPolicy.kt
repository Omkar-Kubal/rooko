package com.heykakaa.rooko

internal object ValidatedFeedExitPolicy {
    fun shouldReport(
        previouslyRecognized: Boolean,
        profileAvailable: Boolean,
        selected: Boolean,
        consentAcknowledged: Boolean,
        serviceOperational: Boolean,
        feedVisibleNow: Boolean,
    ): Boolean = previouslyRecognized &&
        profileAvailable &&
        selected &&
        consentAcknowledged &&
        serviceOperational &&
        !feedVisibleNow
}
