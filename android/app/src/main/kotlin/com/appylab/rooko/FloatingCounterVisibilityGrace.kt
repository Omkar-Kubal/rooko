package com.appylab.rooko

/** Holds an already-visible counter through a short, non-extendable feed scan gap. */
internal class FloatingCounterVisibilityGrace(
    private val graceMillis: Long,
) {
    private var deadlineMillis: Long? = null

    fun onTransientGap(nowMillis: Long, counterVisible: Boolean): Long? {
        if (!counterVisible) return null
        if (deadlineMillis == null) deadlineMillis = nowMillis + graceMillis
        return deadlineMillis
    }

    fun onRecognizedFeed() {
        deadlineMillis = null
    }

    fun onDefiniteFeedExit() {
        deadlineMillis = null
    }

    fun shouldHideAt(nowMillis: Long): Boolean {
        val deadline = deadlineMillis ?: return false
        if (nowMillis < deadline) return false
        deadlineMillis = null
        return true
    }
}
