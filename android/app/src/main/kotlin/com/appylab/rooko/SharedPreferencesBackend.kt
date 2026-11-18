package com.appylab.rooko

import android.content.SharedPreferences

internal class SharedPreferencesBackend(
    private val preferences: SharedPreferences,
) : PreferenceBackend {
    override fun getInt(key: String, defaultValue: Int): Int =
        preferences.getInt(key, defaultValue)

    override fun putInt(key: String, value: Int) {
        preferences.edit().putInt(key, value).apply()
    }

    override fun getLong(key: String, defaultValue: Long): Long =
        preferences.getLong(key, defaultValue)

    override fun putLong(key: String, value: Long) {
        preferences.edit().putLong(key, value).apply()
    }

    override fun getString(key: String, defaultValue: String?): String? =
        preferences.getString(key, defaultValue)

    override fun putString(key: String, value: String) {
        preferences.edit().putString(key, value).apply()
    }

    override fun allKeys(): Set<String> = preferences.all.keys

    override fun remove(key: String) {
        preferences.edit().remove(key).apply()
    }

    override fun putCountEventAtomically(
        dailyCountKey: String,
        nextDailyCount: Int,
        lastDetectionKey: String,
        wallClockMillis: Long,
    ): Boolean = preferences.edit()
        .putInt(dailyCountKey, nextDailyCount)
        .putLong(lastDetectionKey, wallClockMillis)
        .commit()
}
