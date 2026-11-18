package com.appylab.rooko

/** Keeps the selected-app allowlist empty until the user has affirmatively consented. */
internal object TrackingConsentGate {
    fun canOpenAccessibilitySettings(consentAcknowledged: Boolean): Boolean =
        consentAcknowledged

    fun allowedApps(selectedAppIds: Set<String>, consentAcknowledged: Boolean): Set<String> =
        if (consentAcknowledged) selectedAppIds.toSet() else emptySet()
}
