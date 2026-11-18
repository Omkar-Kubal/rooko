package com.appylab.rooko

/** The local-day scope used for one observed foreground-feed time aggregate. */
internal data class ObservedFeedTimeScope(
    val appId: String,
    val localDate: String,
    val timeZoneId: String,
    val offsetSeconds: Int,
)

internal data class ObservedFeedDurationBatch(
    val scope: ObservedFeedTimeScope,
    val durationMillis: Long,
)

/** Credits only short intervals whose endpoints both confirmed the same feed. */
internal class ObservedFeedTimeTracker(
    private val maximumSampleGapMillis: Long = MAX_CREDITED_SAMPLE_GAP_MILLIS,
    private val persistBatchMillis: Long = PERSIST_BATCH_MILLIS,
) {
    private data class Sample(
        val scope: ObservedFeedTimeScope,
        val elapsedRealtimeMillis: Long,
    )

    private var lastSample: Sample? = null
    private var pendingScope: ObservedFeedTimeScope? = null
    private var pendingDurationMillis = 0L

    /** Returns a batch when enough bounded time has accrued, or when scope changes. */
    fun observe(
        scope: ObservedFeedTimeScope,
        elapsedRealtimeMillis: Long,
    ): List<ObservedFeedDurationBatch> {
        val batches = mutableListOf<ObservedFeedDurationBatch>()
        val previous = lastSample
        if (previous != null) {
            val delta = elapsedRealtimeMillis - previous.elapsedRealtimeMillis
            if (previous.scope == scope && delta in 1..maximumSampleGapMillis) {
                if (pendingScope != null && pendingScope != previous.scope) {
                    flush()?.let(batches::add)
                }
                pendingScope = previous.scope
                pendingDurationMillis += delta
            } else {
                flush()?.let(batches::add)
            }
        }
        lastSample = Sample(scope, elapsedRealtimeMillis)
        if (pendingDurationMillis >= persistBatchMillis) {
            flush()?.let(batches::add)
        }
        return batches
    }

    /** Clears continuity and returns only already-bounded elapsed time. */
    fun stop(): ObservedFeedDurationBatch? {
        lastSample = null
        return flush()
    }

    private fun flush(): ObservedFeedDurationBatch? {
        val scope = pendingScope
        val durationMillis = pendingDurationMillis
        pendingScope = null
        pendingDurationMillis = 0L
        return if (scope != null && durationMillis > 0L) {
            ObservedFeedDurationBatch(scope, durationMillis)
        } else {
            null
        }
    }

    internal companion object {
        const val MAX_CREDITED_SAMPLE_GAP_MILLIS = 5_000L
        const val HEARTBEAT_INTERVAL_MILLIS = 4_000L
        const val PERSIST_BATCH_MILLIS = 30_000L
    }
}
