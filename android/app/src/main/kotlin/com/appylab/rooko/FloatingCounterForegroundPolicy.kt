package com.appylab.rooko

/** Treats a known package change as a definite foreground exit before feed-gap grace applies. */
internal object FloatingCounterForegroundPolicy {
    fun shouldHide(
        activeCounterPackageName: String?,
        eventPackageName: String?,
        windowStateChanged: Boolean,
    ): Boolean {
        if (activeCounterPackageName == null) return false
        if (eventPackageName == null) return windowStateChanged
        return eventPackageName != activeCounterPackageName
    }
}
