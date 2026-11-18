package com.appylab.rooko

import java.time.LocalDate

internal data class LegacyDailyAggregate(
    val localDate: String,
    val appId: String,
    val confidence: CountConfidence,
    val count: Int,
)

internal data class LegacyLastDetection(
    val localDate: String,
    val wallClockMillis: Long,
)

/** Parses the existing SharedPreferences keys without assigning missing metadata. */
internal object LegacyProgressImporter {
    fun parseAggregate(key: String, value: Any?): LegacyDailyAggregate? {
        val parts = key.split('|')
        if (parts.size != 4 || parts[0] != DAILY_COUNT_PREFIX) return null
        val date = parseDate(parts[1]) ?: return null
        if (SupportedAppsNative.byId(parts[2]) == null) return null
        val confidence = when (parts[3]) {
            "confirmed" -> CountConfidence.CONFIRMED
            "estimated" -> CountConfidence.ESTIMATED
            else -> return null
        }
        val count = (value as? Number)?.toInt()?.takeIf { it > 0 } ?: return null
        return LegacyDailyAggregate(date.toString(), parts[2], confidence, count)
    }

    fun parseLastDetection(key: String, value: Any?): LegacyLastDetection? {
        val parts = key.split('|')
        if (parts.size != 2 || parts[0] != LAST_DETECTION_PREFIX) return null
        val date = parseDate(parts[1]) ?: return null
        val timestamp = (value as? Number)?.toLong()?.takeIf { it >= 0L } ?: return null
        return LegacyLastDetection(date.toString(), timestamp)
    }

    private fun parseDate(value: String): LocalDate? = try {
        LocalDate.parse(value)
    } catch (_: Exception) {
        null
    }

    private const val DAILY_COUNT_PREFIX = "daily_count"
    private const val LAST_DETECTION_PREFIX = "last_detection_at_ms"
}
