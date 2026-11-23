package com.appylab.rooko

internal data class AppDetectorProfile(
    val appId: String,
    val packageName: String,
    val versionName: String,
    val feedMarkerViewIds: Set<String>,
    val transitionViewIds: Set<String>,
    val identityStrategy: ItemIdentityStrategy = ItemIdentityStrategy.NONE,
    /** Exact allowlisted node used to rederive the configured item identity from the root. */
    val identityNodeViewId: String? = null,
    val fixtureRevision: String = "synthetic",
    val confidence: CountConfidence = CountConfidence.ESTIMATED,
    /** Stable shared ruleset ID; app versions are assigned to it by the signed registry. */
    val profileId: String = "",
) {
    fun isRecognizedFeed(viewIds: Set<String>): Boolean =
        feedMarkerViewIds.isNotEmpty() && viewIds.containsAll(feedMarkerViewIds)

    fun isTransitionSource(viewId: String?): Boolean =
        viewId != null && viewId in transitionViewIds
}

internal enum class ItemIdentityStrategy {
    NONE,
    STABLE_OPAQUE_ACCESSIBILITY_TOKEN,
    STRUCTURAL_NODE_PAIR,
    BOUNDED_TRANSITION_FINGERPRINT,
}

/** Only a digest and its structural provenance may enter detector state. */
internal data class ItemIdentity(
    val saltedHash: String,
    val evidence: ItemIdentityStrategy,
)

internal data class ReelObservation(
    val packageName: String,
    val versionName: String,
    val isFeedVisible: Boolean,
    /** A salted hash and evidence label. Never pass node text here. */
    val itemIdentity: ItemIdentity?,
    /** True only for a scroll event whose source reports different from/to indexes. */
    val transitionObserved: Boolean = false,
    /** True when this is the first identified item on a newly recognized feed. */
    val feedEntryObserved: Boolean = false,
    /** True only when this observation's identity was rederived or matched against the current root. */
    val identityRevalidatedAtCurrentRoot: Boolean = false,
    val elapsedRealtimeMillis: Long,
    val wallClockMillis: Long = 0L,
    val localDateKey: String,
)

internal enum class CountConfidence {
    CONFIRMED,
    ESTIMATED,
}

/** Handles pagers that report the current item in both event index fields. */
internal fun hasObservedIndexTransition(
    previousIndex: Int?,
    fromIndex: Int,
    toIndex: Int,
): Boolean {
    if (toIndex < 0) return false
    if (previousIndex == toIndex) return false
    if (fromIndex >= 0 && fromIndex != toIndex) return true
    return previousIndex != null && previousIndex >= 0 && previousIndex != toIndex
}

/** A feed-entry candidate may have unknown indexes, but must not follow an observed advance. */
internal fun isInitialFeedItem(
    previousIndex: Int?,
    fromIndex: Int,
    toIndex: Int,
): Boolean {
    if (previousIndex != null) return false
    if (fromIndex < 0 && toIndex < 0) return true
    return toIndex >= 0 && !hasObservedIndexTransition(previousIndex, fromIndex, toIndex)
}

internal interface CountStore {
    /** Returns true only when a new daily count was committed. */
    fun recordIfNew(
        appId: String,
        itemIdentityHash: String,
        elapsedRealtimeMillis: Long,
        localDateKey: String,
        confidence: CountConfidence,
        wallClockMillis: Long = 0L,
    ): Boolean
}

internal sealed interface DetectionOutcome {
    data object NotSelected : DetectionOutcome
    data object UnsupportedAppOrVersion : DetectionOutcome
    data object OutsideRecognizedFeed : DetectionOutcome
    data object MissingItemIdentity : DetectionOutcome
    data object CandidateStarted : DetectionOutcome
    data object StationaryItem : DetectionOutcome
    data object DwellNotReached : DetectionOutcome
    data object IdentityNotRevalidated : DetectionOutcome
    data object RecentDuplicate : DetectionOutcome
    data class Counted(
        val appId: String,
        val localDateKey: String,
        val confidence: CountConfidence,
    ) : DetectionOutcome
}

/** Applies version, selection, feed, dwell, identity revalidation and duplicate gates. */
internal class ReelDetector(
    private val profiles: List<AppDetectorProfile>,
    private val countStore: CountStore,
    private val minimumDwellMillis: Long = MINIMUM_DWELL_MILLIS,
) {
    private data class Candidate(
        val itemIdentityHash: String,
        val startedAtElapsedMillis: Long,
        var transitionObserved: Boolean,
        var feedEntryObserved: Boolean,
        var counted: Boolean = false,
    )

    private val selectedAppIds = mutableSetOf<String>()
    private val candidates = mutableMapOf<String, Candidate>()

    fun setSelectedApps(appIds: Set<String>) {
        selectedAppIds.clear()
        selectedAppIds.addAll(profiles.map { it.appId }.filter { it in appIds })
        candidates.keys.retainAll(selectedAppIds)
    }

    fun clearCandidate(appId: String) {
        candidates.remove(appId)
    }

    fun observe(observation: ReelObservation): DetectionOutcome {
        val profile = profiles.firstOrNull {
            it.packageName == observation.packageName &&
                it.versionName == observation.versionName
        }
        if (profile == null) {
            profiles.firstOrNull { it.packageName == observation.packageName }
                ?.let { candidates.remove(it.appId) }
            return DetectionOutcome.UnsupportedAppOrVersion
        }
        if (profile.appId !in selectedAppIds) {
            candidates.remove(profile.appId)
            return DetectionOutcome.NotSelected
        }

        if (!observation.isFeedVisible) {
            candidates.remove(profile.appId)
            return DetectionOutcome.OutsideRecognizedFeed
        }

        val identity = observation.itemIdentity
            ?.takeIf { it.saltedHash.isNotBlank() && it.evidence == profile.identityStrategy }
            ?: run {
                candidates.remove(profile.appId)
                return DetectionOutcome.MissingItemIdentity
            }
        if (profile.confidence == CountConfidence.CONFIRMED &&
            identity.evidence != ItemIdentityStrategy.STABLE_OPAQUE_ACCESSIBILITY_TOKEN
        ) {
            candidates.remove(profile.appId)
            return DetectionOutcome.MissingItemIdentity
        }
        val identityHash = identity.saltedHash

        val candidate = candidates[profile.appId]
        if (candidate == null) {
            candidates[profile.appId] = Candidate(
                itemIdentityHash = identityHash,
                startedAtElapsedMillis = observation.elapsedRealtimeMillis,
                transitionObserved = observation.transitionObserved,
                feedEntryObserved = observation.feedEntryObserved,
            )
            return DetectionOutcome.CandidateStarted
        }

        if (candidate.itemIdentityHash == identityHash) {
            if (!candidate.transitionObserved && !candidate.feedEntryObserved &&
                (observation.transitionObserved || observation.feedEntryObserved)
            ) {
                candidates[profile.appId] = Candidate(
                    itemIdentityHash = identityHash,
                    startedAtElapsedMillis = observation.elapsedRealtimeMillis,
                    transitionObserved = observation.transitionObserved,
                    feedEntryObserved = observation.feedEntryObserved,
                )
                return DetectionOutcome.CandidateStarted
            }
            candidate.transitionObserved =
                candidate.transitionObserved || observation.transitionObserved
            candidate.feedEntryObserved =
                candidate.feedEntryObserved || observation.feedEntryObserved
            if (candidate.counted) return DetectionOutcome.StationaryItem
            return confirmIfEligible(
                profile,
                candidate,
                observation,
            )
                ?: DetectionOutcome.DwellNotReached
        }

        val stableIdentityChanged =
            profile.identityStrategy == ItemIdentityStrategy.STABLE_OPAQUE_ACCESSIBILITY_TOKEN
        candidates[profile.appId] = Candidate(
            itemIdentityHash = identityHash,
            startedAtElapsedMillis = observation.elapsedRealtimeMillis,
            transitionObserved = observation.transitionObserved || stableIdentityChanged,
            feedEntryObserved = observation.feedEntryObserved,
        )
        return DetectionOutcome.CandidateStarted
    }

    private fun confirmIfEligible(
        profile: AppDetectorProfile,
        candidate: Candidate?,
        observation: ReelObservation,
    ): DetectionOutcome? {
        if (candidate == null || candidate.counted) return null
        if (
            !candidate.feedEntryObserved &&
            !candidate.transitionObserved
        ) {
            return DetectionOutcome.StationaryItem
        }
        val dwellMillis = observation.elapsedRealtimeMillis -
            candidate.startedAtElapsedMillis
        if (dwellMillis < minimumDwellMillis || dwellMillis < 0) return null
        if (!observation.identityRevalidatedAtCurrentRoot) {
            return DetectionOutcome.IdentityNotRevalidated
        }

        val committed = countStore.recordIfNew(
            appId = profile.appId,
            itemIdentityHash = candidate.itemIdentityHash,
            elapsedRealtimeMillis = observation.elapsedRealtimeMillis,
            wallClockMillis = observation.wallClockMillis,
            localDateKey = observation.localDateKey,
            confidence = profile.confidence,
        )
        // A failed write leaves the candidate retryable; a stored duplicate is settled.
        candidate.counted = true
        return if (committed) {
            DetectionOutcome.Counted(
                appId = profile.appId,
                localDateKey = observation.localDateKey,
                confidence = profile.confidence,
            )
        } else {
            DetectionOutcome.RecentDuplicate
        }
    }

    internal companion object {
        const val MINIMUM_DWELL_MILLIS = 1_000L
        const val DEDUPE_WINDOW_MILLIS = 5 * 60 * 1000L
    }
}
