package com.appylab.rooko

/** The overlay never turns an unsupported or unconsented observation into coverage. */
internal object FloatingCounterPolicy {
    fun canShow(
        enabled: Boolean,
        overlayGranted: Boolean,
        trackingConsent: Boolean,
        serviceOperational: Boolean,
        selected: Boolean,
        profileAvailable: Boolean,
        recognizedFeed: Boolean,
    ): Boolean = enabled && overlayGranted && trackingConsent &&
        serviceOperational && selected && profileAvailable && recognizedFeed
}
