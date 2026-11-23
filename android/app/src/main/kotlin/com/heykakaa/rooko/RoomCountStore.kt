package com.heykakaa.rooko

import java.security.MessageDigest

/** Writes durable daily aggregates to Room and keeps duplicate identities in process memory only. */
internal class RoomCountStore(
    private val progress: ProgressRepository,
    private val installSalt: String,
) : CountStore {
    private val recent = mutableMapOf<String, Long>()

    @Synchronized
    fun clearRecentIdentities() = recent.clear()

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
        val key = duplicateKey(appId, itemIdentityHash)
        val previous = recent[key]
        if (
            previous != null && elapsedRealtimeMillis >= previous &&
            elapsedRealtimeMillis - previous < ReelDetector.DEDUPE_WINDOW_MILLIS
        ) return false

        progress.recordCount(
            appId = appId,
            localDate = localDateKey,
            confidence = confidence,
            wallClockMillis = wallClockMillis,
        )
        recent[key] = elapsedRealtimeMillis
        return true
    }

    fun countsFor(localDateKey: String, appIds: Set<String>): Map<String, DailyAppCount> =
        progress.countsFor(localDateKey, appIds)

    fun lastDetectionAtMillis(localDateKey: String): Long =
        progress.lastDetectionAtMillis(localDateKey)

    private fun pruneExpiredDuplicates(nowElapsedMillis: Long) {
        recent.keys.toList().forEach { key ->
            val countedAt = recent[key] ?: return@forEach
            if (
                nowElapsedMillis < countedAt ||
                nowElapsedMillis - countedAt >= ReelDetector.DEDUPE_WINDOW_MILLIS
            ) recent.remove(key)
        }
    }

    private fun duplicateKey(appId: String, identityHash: String): String {
        val digest = MessageDigest.getInstance("SHA-256")
            .digest("$installSalt|$appId|$identityHash".toByteArray(Charsets.UTF_8))
        return digest.joinToString(separator = "") { "%02x".format(it) }
    }
}
