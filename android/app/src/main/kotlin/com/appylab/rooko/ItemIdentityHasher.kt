package com.appylab.rooko

import java.security.MessageDigest
import java.util.UUID

/** Hashes an opaque transient identity before it can enter detector or storage state. */
internal class AppScopedIdentityHasher(
    private val preferences: PreferenceBackend,
    private val saltFactory: () -> String = { UUID.randomUUID().toString() },
) {
    fun hash(
        appId: String,
        profileKey: String,
        opaqueToken: String,
        elapsedRealtimeMillis: Long,
    ): String {
        require(appId.isNotBlank())
        require(profileKey.isNotBlank())
        require(opaqueToken.isNotBlank())

        val scope = "$appId|$profileKey"
        val saltKey = "$SALT_PREFIX$scope"
        val createdAtKey = "$SALT_CREATED_AT_PREFIX$scope"
        val existingSalt = preferences.getString(saltKey, null)
        val createdAt = preferences.getLong(createdAtKey, NO_TIMESTAMP)
        val saltExpired =
            createdAt == NO_TIMESTAMP ||
                elapsedRealtimeMillis < createdAt ||
                elapsedRealtimeMillis - createdAt >= SALT_ROTATION_MILLIS
        val salt = if (existingSalt == null || saltExpired) {
            saltFactory().also { newSalt ->
                preferences.putString(saltKey, newSalt)
                preferences.putLong(createdAtKey, elapsedRealtimeMillis)
            }
        } else {
            existingSalt
        }

        return sha256("$salt|$scope|$opaqueToken")
    }

    private fun sha256(value: String): String {
        val digest = MessageDigest.getInstance("SHA-256")
            .digest(value.toByteArray(Charsets.UTF_8))
        return digest.joinToString(separator = "") { byte -> "%02x".format(byte) }
    }

    internal companion object {
        const val SALT_ROTATION_MILLIS = 24 * 60 * 60 * 1_000L
        private const val SALT_PREFIX = "item_identity_salt|"
        private const val SALT_CREATED_AT_PREFIX = "item_identity_salt_created_at|"
        private const val NO_TIMESTAMP = -1L
    }
}
