package com.appylab.rooko

import android.content.Context
import android.os.SystemClock
import java.io.File

/** Opt-in, short-lived structural fixture capture for debug builds only. */
internal object DetectorStructuralProbe {
    private const val MARKER = "detector_probe_enabled"
    private const val IDENTITY_RELATION_MARKER = "detector_probe_identity_relations_enabled"
    private const val OUTPUT = "detector_probe.tsv"
    private const val ESTIMATOR_OUTPUT = "detector_estimator_probe.tsv"
    private const val ESTIMATOR_SUMMARY_MARKER = "detector_estimator_summary_enabled"
    private const val ESTIMATOR_SUMMARY_OUTPUT = "detector_estimator_summary.tsv"
    private const val STATUS = "detector_probe_status.tsv"
    private const val MAX_CAPTURE_AGE_MILLIS = 10 * 60 * 1_000L
    private const val MAX_OUTPUT_BYTES = 128 * 1_024L
    private const val MAX_ESTIMATOR_OUTPUT_BYTES = 32 * 1_024L
    private const val SUMMARY_FLUSH_INTERVAL_MILLIS = 2_000L
    private val estimatorSummaryCounts = sortedMapOf<String, Int>()
    private var estimatorSummaryDirty = false
    private var lastEstimatorSummaryFlushAt = 0L

    fun isEnabled(context: Context): Boolean {
        if (!BuildConfig.DEBUG) return false
        val marker = File(context.filesDir, MARKER)
        if (!marker.exists()) return false
        if (System.currentTimeMillis() - marker.lastModified() > MAX_CAPTURE_AGE_MILLIS) {
            marker.delete()
            return false
        }
        return true
    }

    /** Requires a second, separately consented debug marker in addition to the structural probe. */
    fun isIdentityRelationCaptureEnabled(context: Context): Boolean {
        val marker = File(context.filesDir, IDENTITY_RELATION_MARKER)
        if (!isEnabled(context)) {
            marker.delete()
            return false
        }
        if (!marker.exists()) return false
        if (System.currentTimeMillis() - marker.lastModified() > MAX_CAPTURE_AGE_MILLIS) {
            marker.delete()
            return false
        }
        return true
    }

    fun record(context: Context, line: String) {
        if (!isEnabled(context)) return
        val output = File(context.filesDir, OUTPUT)
        BoundedProbeOutput.appendLine(output, line, MAX_OUTPUT_BYTES)
    }

    fun recordEstimatorOutcome(
        context: Context,
        appId: String,
        versionName: String,
        outcome: EstimatorProbeCategory,
    ) {
        val row = EstimatorProbeFormatter.format(appId, versionName, outcome) ?: return
        if (isEstimatorSummaryEnabled(context)) {
            estimatorSummaryCounts[row] = (estimatorSummaryCounts[row] ?: 0) + 1
            estimatorSummaryDirty = true
            if (SystemClock.elapsedRealtime() - lastEstimatorSummaryFlushAt >=
                SUMMARY_FLUSH_INTERVAL_MILLIS
            ) {
                flushEstimatorSummary(context)
            }
        }
        if (!isEnabled(context)) return
        BoundedProbeOutput.appendLine(
            File(context.filesDir, ESTIMATOR_OUTPUT),
            row,
            MAX_ESTIMATOR_OUTPUT_BYTES,
        )
    }

    /** Writes aggregate categories only; no event sequence or content is retained. */
    fun flushEstimatorSummary(context: Context) {
        if (!isEstimatorSummaryEnabled(context)) {
            estimatorSummaryCounts.clear()
            estimatorSummaryDirty = false
            return
        }
        if (!estimatorSummaryDirty) return
        val rows = estimatorSummaryCounts.entries.joinToString("\n") { (category, count) ->
            "$category\t$count"
        }
        File(context.filesDir, ESTIMATOR_SUMMARY_OUTPUT).writeText(rows, Charsets.UTF_8)
        estimatorSummaryDirty = false
        lastEstimatorSummaryFlushAt = SystemClock.elapsedRealtime()
    }

    private fun isEstimatorSummaryEnabled(context: Context): Boolean {
        if (!BuildConfig.DEBUG) return false
        val marker = File(context.filesDir, ESTIMATOR_SUMMARY_MARKER)
        if (!marker.exists()) return false
        if (System.currentTimeMillis() - marker.lastModified() > MAX_CAPTURE_AGE_MILLIS) {
            marker.delete()
            return false
        }
        return true
    }

    fun recordConfig(context: Context, rows: List<String>) {
        if (!isEnabled(context)) return
        File(context.filesDir, STATUS).writeText(rows.joinToString("\n"), Charsets.UTF_8)
    }
}

/** Static pipeline outcomes only: never labels, hashes, item IDs, counts, or timestamps. */
internal enum class EstimatorProbeCategory {
    FEED_RECOGNIZED,
    FEED_NOT_RECOGNIZED,
    COMMENTS_SURFACE,
    ROOT_MISSING,
    ROOT_PACKAGE_CHANGED,
    EVENT_ROOT_OWN_PACKAGE,
    EVENT_ROOT_OTHER_PACKAGE,
    RESULT_ROOT_OWN_PACKAGE,
    RESULT_ROOT_OTHER_PACKAGE,
    ITEM_NODE_FOUND,
    ITEM_NODE_MISSING,
    ITEM_SCAN_STARTED,
    ITEM_SCAN_QUEUED,
    ITEM_SCAN_DROPPED,
    ESTIMATOR_UNAVAILABLE,
    WORKER_SKIPPED,
    WORKER_FAILED,
    WORKER_UNDER_250_MS,
    WORKER_250_TO_999_MS,
    WORKER_1000_TO_1999_MS,
    WORKER_2000_MS_OR_MORE,
    LABELS_EMPTY,
    SPONSORED_ITEM,
    HASH_AVAILABLE,
    HASH_MISSING,
    FEED_REVALIDATION_FAILED,
    FEED_REVALIDATED,
    OUTCOME_MISSING_KEY,
    OUTCOME_CANDIDATE,
    OUTCOME_WAITING,
    OUTCOME_COUNTED,
    OUTCOME_STATIONARY,
    OUTCOME_DUPLICATE,
    OUTCOME_PERSISTENCE_UNAVAILABLE,
    OUTCOME_BASELINE_SEEDED,
    OUTCOME_OUTSIDE_FEED,
}

internal object EstimatorProbeFormatter {
    private val safeVersion = Regex("[A-Za-z0-9._-]{1,80}")

    fun format(
        appId: String,
        versionName: String,
        outcome: EstimatorProbeCategory,
    ): String? {
        if (appId !in setOf("instagram", "youtube") || !safeVersion.matches(versionName)) {
            return null
        }
        return "$appId\t$versionName\t${outcome.name}"
    }
}

internal object BoundedProbeOutput {
    fun appendLine(file: File, line: String, maximumBytes: Long): Boolean {
        if (maximumBytes < 0) return false
        val bytes = (line + "\n").toByteArray(Charsets.UTF_8)
        val currentBytes = file.length()
        if (currentBytes > maximumBytes || bytes.size.toLong() > maximumBytes - currentBytes) {
            return false
        }
        file.appendBytes(bytes)
        return true
    }
}
