package com.appylab.rooko

/** Keeps one active scan and the latest request for a fresh rescan per app. */
internal class CoalescedItemScanRequests<T> {
    private val inFlight = mutableSetOf<String>()
    private val pending = mutableMapOf<String, T>()

    /** Returns true when the caller should start a scan now. */
    fun request(appId: String, latest: T): Boolean {
        if (inFlight.add(appId)) return true
        pending[appId] = latest
        return false
    }

    /** Releases the active scan and returns a newer request, if one arrived. */
    fun finish(appId: String): T? {
        if (!inFlight.remove(appId)) return null
        return pending.remove(appId)
    }

    fun discardPending(appId: String) {
        pending.remove(appId)
    }

    fun discardAllPending() {
        pending.clear()
    }
}
