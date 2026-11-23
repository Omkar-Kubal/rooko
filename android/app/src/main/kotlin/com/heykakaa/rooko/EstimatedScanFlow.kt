package com.heykakaa.rooko

import android.view.accessibility.AccessibilityEvent

/** Bounds expensive root reads during event bursts while preserving feed transitions. */
internal class EstimatedEventScanPolicy(private val intervalMillis: Long) {
    private var lastRoutineScanAt: Long? = null

    fun shouldScan(eventType: Int, elapsedRealtimeMillis: Long): Boolean {
        if (eventType == AccessibilityEvent.TYPE_VIEW_SCROLLED ||
            eventType == AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED
        ) return true
        val previous = lastRoutineScanAt
        if (previous != null && elapsedRealtimeMillis >= previous &&
            elapsedRealtimeMillis - previous < intervalMillis
        ) return false
        lastRoutineScanAt = elapsedRealtimeMillis
        return true
    }
}

/** Keeps the earliest pending confirmation despite intervening Accessibility events. */
internal class PendingEstimateRechecks {
    private val checks = mutableMapOf<String, Runnable>()

    fun schedule(
        appId: String,
        delayMillis: Long,
        postDelayed: (Runnable, Long) -> Unit,
        action: () -> Unit,
    ) {
        if (checks.containsKey(appId)) return
        lateinit var check: Runnable
        check = Runnable {
            if (checks[appId] !== check) return@Runnable
            checks.remove(appId)
            action()
        }
        checks[appId] = check
        postDelayed(check, delayMillis)
    }

    fun cancel(appId: String, removeCallback: (Runnable) -> Unit) {
        checks.remove(appId)?.let(removeCallback)
    }

    fun clear(removeCallback: (Runnable) -> Unit) {
        checks.values.forEach(removeCallback)
        checks.clear()
    }
}
