package com.heykakaa.rooko

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class LocalCountStoreTest {
    @Test
    fun combinedProductTotalIncludesPersistedEventsAcrossCategories() {
        val combined = listOf(
            DailyAppCount(confirmed = 2, estimated = 5),
            DailyAppCount(confirmed = 1, estimated = 4),
        ).sumOf { it.countedCount }

        assertEquals(12, combined)
    }

    @Test
    fun previouslyPersistedDuplicateHashesAreRemovedOnStoreOpen() {
        val preferences = MemoryPreferences()
        preferences.putLong("recent_item|legacy", 100L)

        LocalCountStore(preferences, installSalt = "test-salt")

        assertFalse(preferences.allKeys().any { it.startsWith("recent_item|") })
    }

    @Test
    fun acceptedAggregateAndLastDetectionAreCommittedInOneUpdate() {
        val preferences = MemoryPreferences()
        val store = LocalCountStore(preferences, installSalt = "test-salt")

        assertTrue(
            store.recordIfNew(
                appId = "youtube",
                itemIdentityHash = "hashed-item-a",
                elapsedRealtimeMillis = 1_000,
                localDateKey = "2026-11-06",
                confidence = CountConfidence.ESTIMATED,
            ),
        )

        assertEquals(1, preferences.atomicCountUpdateCount)
    }

    @Test
    fun dailyCountsPersistByAppAndConfidence() {
        val preferences = MemoryPreferences()
        val firstProcess = LocalCountStore(preferences, installSalt = "test-salt")

        assertTrue(
            firstProcess.recordIfNew(
                appId = "youtube",
                itemIdentityHash = "hashed-item-a",
                elapsedRealtimeMillis = 1_000,
                localDateKey = "2026-11-06",
                confidence = CountConfidence.ESTIMATED,
            ),
        )

        val afterRestart = LocalCountStore(preferences, installSalt = "test-salt")
        assertEquals(
            DailyAppCount(confirmed = 0, estimated = 1),
            afterRestart.countsFor("2026-11-06", setOf("youtube"))["youtube"],
        )
        assertEquals(
            DailyAppCount(confirmed = 0, estimated = 0),
            afterRestart.countsFor("2026-11-07", setOf("youtube"))["youtube"],
        )
    }

    @Test
    fun duplicateHashRemainsOnlyInMemoryAndExpiresWithinFiveMinutes() {
        val preferences = MemoryPreferences()
        val firstProcess = LocalCountStore(preferences, installSalt = "test-salt")
        val restartedProcess = LocalCountStore(preferences, installSalt = "test-salt")

        assertTrue(firstProcess.recordIfNew("youtube", "hashed-item-a", 1_000, "2026-11-06", CountConfidence.ESTIMATED))
        assertFalse(firstProcess.recordIfNew("youtube", "hashed-item-a", 299_999, "2026-11-06", CountConfidence.ESTIMATED))
        assertFalse(preferences.allKeys().any { it.startsWith("recent_item|") })
        assertTrue(firstProcess.recordIfNew("youtube", "hashed-item-a", 301_000, "2026-11-06", CountConfidence.ESTIMATED))
        assertTrue(restartedProcess.recordIfNew("youtube", "hashed-item-a", 302_000, "2026-11-06", CountConfidence.ESTIMATED))
        assertEquals(
            DailyAppCount(confirmed = 0, estimated = 3),
            restartedProcess.countsFor("2026-11-06", setOf("youtube"))["youtube"],
        )
    }

    private class MemoryPreferences : PreferenceBackend {
        private val values = mutableMapOf<String, Any>()
        var atomicCountUpdateCount = 0
            private set

        override fun getInt(key: String, defaultValue: Int): Int =
            values[key] as? Int ?: defaultValue

        override fun putInt(key: String, value: Int) {
            values[key] = value
        }

        override fun getLong(key: String, defaultValue: Long): Long =
            values[key] as? Long ?: defaultValue

        override fun putLong(key: String, value: Long) {
            values[key] = value
        }

        override fun getString(key: String, defaultValue: String?): String? =
            values[key] as? String ?: defaultValue

        override fun putString(key: String, value: String) {
            values[key] = value
        }

        override fun allKeys(): Set<String> = values.keys.toSet()

        override fun remove(key: String) {
            values.remove(key)
        }

        override fun putCountEventAtomically(
            dailyCountKey: String,
            nextDailyCount: Int,
            lastDetectionKey: String,
            wallClockMillis: Long,
        ): Boolean {
            atomicCountUpdateCount += 1
            values[dailyCountKey] = nextDailyCount
            values[lastDetectionKey] = wallClockMillis
            return true
        }
    }
}
