package com.heykakaa.rooko

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertFalse
import org.junit.Test

class ItemIdentityHasherTest {
    @Test
    fun sameItemAndProfileReuseHashWithinSaltWindow() {
        val preferences = MemoryPreferences()
        val hasher = AppScopedIdentityHasher(preferences) { "salt-1" }

        val first = hasher.hash("instagram", "454.0.0.54.77", "fixture-token", 100L)
        val second = hasher.hash("instagram", "454.0.0.54.77", "fixture-token", 200L)

        assertEquals(first, second)
    }

    @Test
    fun itemHashIsScopedToAppAndProfile() {
        val preferences = MemoryPreferences()
        val hasher = AppScopedIdentityHasher(preferences) { "salt-1" }

        val instagram = hasher.hash("instagram", "454.0.0.54.77", "fixture-token", 100L)
        val youtube = hasher.hash("youtube", "21.43.523", "fixture-token", 100L)

        assertNotEquals(instagram, youtube)
    }

    @Test
    fun saltRotatesAfterTwentyFourHours() {
        val preferences = MemoryPreferences()
        var saltNumber = 0
        val hasher = AppScopedIdentityHasher(preferences) { "salt-${++saltNumber}" }

        val first = hasher.hash("instagram", "454.0.0.54.77", "fixture-token", 100L)
        val afterRotation = hasher.hash(
            "instagram",
            "454.0.0.54.77",
            "fixture-token",
            100L + AppScopedIdentityHasher.SALT_ROTATION_MILLIS,
        )

        assertNotEquals(first, afterRotation)
    }

    @Test
    fun elapsedClockResetRotatesSaltAndRawTokenIsNotPersisted() {
        val preferences = MemoryPreferences()
        var saltNumber = 0
        val hasher = AppScopedIdentityHasher(preferences) { "salt-${++saltNumber}" }

        val first = hasher.hash("instagram", "454.0.0.54.77", "fixture-token", 2_000L)
        val afterReboot = hasher.hash("instagram", "454.0.0.54.77", "fixture-token", 10L)

        assertNotEquals(first, afterReboot)
        assertFalse(preferences.values.containsValue("fixture-token"))
        assertNotNull(afterReboot)
    }

    private class MemoryPreferences : PreferenceBackend {
        val values = mutableMapOf<String, Any>()

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
        ): Boolean = false
    }
}
