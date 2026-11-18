package com.appylab.rooko

import android.content.Context
import java.io.File

/** Opt-in, short-lived structural fixture capture for debug builds only. */
internal object DetectorStructuralProbe {
    private const val MARKER = "detector_probe_enabled"
    private const val IDENTITY_RELATION_MARKER = "detector_probe_identity_relations_enabled"
    private const val OUTPUT = "detector_probe.tsv"
    private const val STATUS = "detector_probe_status.tsv"
    private const val MAX_CAPTURE_AGE_MILLIS = 10 * 60 * 1_000L
    private const val MAX_OUTPUT_BYTES = 128 * 1_024L

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

    fun recordConfig(context: Context, rows: List<String>) {
        if (!isEnabled(context)) return
        File(context.filesDir, STATUS).writeText(rows.joinToString("\n"), Charsets.UTF_8)
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
