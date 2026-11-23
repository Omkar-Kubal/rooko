package com.heykakaa.rooko

import java.security.MessageDigest

internal interface PreferenceBackend {
    fun getInt(key: String, defaultValue: Int): Int
    fun putInt(key: String, value: Int)
    fun getLong(key: String, defaultValue: Long): Long
    fun putLong(key: String, value: Long)
    fun getString(key: String, defaultValue: String?): String?
    fun putString(key: String, value: String)
    fun allKeys(): Set<String>
    fun remove(key: String)
    fun putCountEventAtomically(
        dailyCountKey: String,
        nextDailyCount: Int,
        lastDetectionKey: String,
        wallClockMillis: Long,
    ): Boolean
}

internal data class DailyAppCount(
    val confirmed: Int,
    val estimated: Int,
) {
    /** Counts every event already stored for the app and local date. */
    val countedCount: Int
        get() = confirmed + estimated
}

/** Stores daily aggregates; duplicate hashes live only in process memory. */
internal class LocalCountStore(
    private val preferences: PreferenceBackend,
    private val installSalt: String,
) : CountStore {
    private val recent = mutableMapOf<String, Long>()

    @Synchronized
    fun clearRecentIdentities() = recent.clear()

    init {
        // Migrate away from the former on-disk duplicate cache.
        preferences.allKeys()
            .filter { it.startsWith(DUPLICATE_PREFIX) }
            .forEach(preferences::remove)
    }

    @Synchronized
    override fun recordIfNew(
        appId: String,
        itemIdentityHash: String,
        elapsedRealtimeMillis: Long,
        localDateKey: String,
        confidence: CountConfidence,
        wallClockMillis: Long,
    ): Boolean {
        pruneExpiredDuplicates(elapsedRealtimeMillis)
        val duplicateKey = duplicateKey(appId, itemIdentityHash)
        val previousCountedAt = recent[duplicateKey]
        if (
            previousCountedAt != null &&
            elapsedRealtimeMillis >= previousCountedAt &&
            elapsedRealtimeMillis - previousCountedAt < ReelDetector.DEDUPE_WINDOW_MILLIS
        ) {
            return false
        }

        val dailyKey = dailyCountKey(localDateKey, appId, confidence)
        val committed = preferences.putCountEventAtomically(
            dailyCountKey = dailyKey,
            nextDailyCount = preferences.getInt(dailyKey, 0) + 1,
            lastDetectionKey = lastDetectionKey(localDateKey),
            wallClockMillis = wallClockMillis,
        )
        if (committed) recent[duplicateKey] = elapsedRealtimeMillis
        return committed
    }

    fun lastDetectionAtMillis(localDateKey: String): Long =
        preferences.getLong(lastDetectionKey(localDateKey), NO_TIMESTAMP)

    fun countsFor(localDateKey: String, appIds: Set<String>): Map<String, DailyAppCount> =
        appIds.associateWith { appId ->
            DailyAppCount(
                confirmed = preferences.getInt(
                    dailyCountKey(localDateKey, appId, CountConfidence.CONFIRMED),
                    0,
                ),
                estimated = preferences.getInt(
                    dailyCountKey(localDateKey, appId, CountConfidence.ESTIMATED),
                    0,
                ),
            )
        }

    private fun pruneExpiredDuplicates(nowElapsedMillis: Long) {
        recent.keys.toList()
            .forEach { key ->
                val lastCountedAt = recent[key] ?: return@forEach
                if (
                    nowElapsedMillis < lastCountedAt ||
                    nowElapsedMillis - lastCountedAt >= ReelDetector.DEDUPE_WINDOW_MILLIS
                ) {
                    recent.remove(key)
                }
            }
    }

    private fun duplicateKey(appId: String, itemIdentityHash: String): String =
        DUPLICATE_PREFIX + sha256("$installSalt|$appId|$itemIdentityHash")

    private fun dailyCountKey(
        localDateKey: String,
        appId: String,
        confidence: CountConfidence,
    ): String = "$DAILY_COUNT_PREFIX$localDateKey|$appId|${confidence.name.lowercase()}"

    private fun lastDetectionKey(localDateKey: String): String =
        "$LAST_DETECTION_PREFIX$localDateKey"

    private fun sha256(value: String): String {
        val digest = MessageDigest.getInstance("SHA-256")
            .digest(value.toByteArray(Charsets.UTF_8))
        return digest.joinToString(separator = "") { byte -> "%02x".format(byte) }
    }

    private companion object {
        const val DAILY_COUNT_PREFIX = "daily_count|"
        const val DUPLICATE_PREFIX = "recent_item|"
        const val LAST_DETECTION_PREFIX = "last_detection_at_ms|"
        const val NO_TIMESTAMP = -1L
    }
}
