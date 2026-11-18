package com.appylab.rooko

/** Session-local transition identity. Pager position is evidence, never the identity. */
internal class FeedItemFingerprinter(private val sessionId: String) {
    private var ordinal = 0L
    private var currentIndex: Int? = null
    private var currentFingerprint: String? = null

    fun observe(
        index: Int,
        transitionObserved: Boolean,
        feedEntryObserved: Boolean,
    ): String? {
        if (index < 0) return null
        if (currentFingerprint == null) {
            if (!transitionObserved && !feedEntryObserved) return null
            ordinal += 1
            currentIndex = index
            return "$sessionId|$ordinal".also { currentFingerprint = it }
        }
        if (transitionObserved) {
            ordinal += 1
            currentIndex = index
            return "$sessionId|$ordinal".also { currentFingerprint = it }
        }
        return currentFingerprint.takeIf { currentIndex == index }
    }
}
