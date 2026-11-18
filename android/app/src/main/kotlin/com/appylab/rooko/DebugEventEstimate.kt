package com.appylab.rooko

import javax.crypto.Mac
import javax.crypto.spec.SecretKeySpec
import java.util.UUID

/** A consented best-effort estimator; these mappings are never validated profiles. */
internal data class DebugTextProfile(
    val appId: String,
    val packageName: String,
    val versionName: String,
    val feedMarkerIds: Set<String>,
    val itemNodeId: String,
) {
    fun isRecognizedFeed(viewIds: Set<String>): Boolean =
        feedMarkerIds.isNotEmpty() &&
            viewIds.containsAll(feedMarkerIds) &&
            viewIds.none { it.contains("comments_sheet") || it.contains("comment_tray") }
}

internal object DebugTextProfiles {
    private val profiles = listOf(
        DebugTextProfile(
            "instagram", "com.instagram.android", "",
            setOf("clips_viewer_view_pager", "clips_video_container"),
            "clips_caption_component",
        ),
        DebugTextProfile(
            "youtube", "com.google.android.youtube", "",
            setOf("reel_recycler", "reel_player_page_container"),
            "reel_player_page_container",
        ),
    )

    fun forVersion(packageName: String, versionName: String): DebugTextProfile? =
        profiles.firstOrNull {
            versionName.isNotBlank() && it.packageName == packageName
        }?.copy(versionName = versionName)
}

/** Raw labels are used only in the call to [digest] and never enter count state or storage. */
internal class DebugTextKeyHasher(secret: String = UUID.randomUUID().toString()) {
    private val key = SecretKeySpec(secret.toByteArray(Charsets.UTF_8), "HmacSHA256")

    fun digest(labels: List<String>): String? {
        val normalized = labels.asSequence()
            .map { it.trim().replace(Regex("\\s+"), " ") }
            .filter(String::isNotBlank)
            .take(4)
            .toList()
        if (normalized.isEmpty()) return null
        val mac = Mac.getInstance("HmacSHA256")
        mac.init(key)
        return mac.doFinal(normalized.joinToString("\u001f").toByteArray(Charsets.UTF_8))
            .joinToString("") { "%02x".format(it) }
    }
}

internal enum class DebugEstimateOutcome {
    OutsideFeed, MissingKey, Candidate, Waiting, Stationary, Duplicate, Counted, BaselineSeeded,
}

/** Intentionally preserves the earlier 150 ms settle / 500 ms spacing test behavior. */
internal class DebugEventEstimateCounter(private val store: CountStore) {
    private data class State(
        var currentKey: String? = null,
        var pendingKey: String? = null,
        var pendingSince: Long = 0L,
        var lastAcceptedAt: Long? = null,
        var suppressInitialItem: Boolean = false,
        var outsideSince: Long? = null,
    )

    private val states = mutableMapOf<String, State>()

    fun clear() = states.clear()
    fun clear(appId: String) { states.remove(appId) }
    fun suppressInitialItem(appId: String) {
        states.getOrPut(appId, ::State).suppressInitialItem = true
    }

    fun observe(
        appId: String,
        key: String?,
        feedVisible: Boolean,
        elapsedRealtimeMillis: Long,
        localDateKey: String,
        wallClockMillis: Long,
    ): DebugEstimateOutcome {
        if (!feedVisible) {
            states[appId]?.let { state ->
                state.pendingKey = null
                if (state.outsideSince == null) state.outsideSince = elapsedRealtimeMillis
            }
            return DebugEstimateOutcome.OutsideFeed
        }
        if (key.isNullOrBlank()) {
            states[appId]?.pendingKey = null
            return DebugEstimateOutcome.MissingKey
        }
        val state = states.getOrPut(appId, ::State)
        state.outsideSince?.let { outsideSince ->
            if (elapsedRealtimeMillis < outsideSince ||
                elapsedRealtimeMillis - outsideSince >= ReelDetector.DEDUPE_WINDOW_MILLIS
            ) state.currentKey = null
        }
        state.outsideSince = null
        if (state.suppressInitialItem) {
            state.suppressInitialItem = false
            state.currentKey = key
            state.pendingKey = null
            return DebugEstimateOutcome.BaselineSeeded
        }
        if (key == state.currentKey) {
            state.pendingKey = null
            return DebugEstimateOutcome.Stationary
        }
        if (key != state.pendingKey) {
            state.pendingKey = key
            state.pendingSince = elapsedRealtimeMillis
            return DebugEstimateOutcome.Candidate
        }
        if (elapsedRealtimeMillis - state.pendingSince < 150 ||
            state.lastAcceptedAt?.let { elapsedRealtimeMillis - it < 500 } == true
        ) return DebugEstimateOutcome.Waiting

        state.pendingKey = null
        state.currentKey = key
        val committed = store.recordIfNew(
            appId, key, elapsedRealtimeMillis, localDateKey,
            CountConfidence.ESTIMATED, wallClockMillis,
        )
        if (committed) state.lastAcceptedAt = elapsedRealtimeMillis
        return if (committed) DebugEstimateOutcome.Counted else DebugEstimateOutcome.Duplicate
    }
}
