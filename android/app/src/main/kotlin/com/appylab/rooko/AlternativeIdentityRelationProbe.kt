package com.appylab.rooko

/** Categorical continuity labels for debug-only, transient identity experiments. */
internal data class AlternativeIdentityRelations(
    val nodeHandle: UniqueIdRelation,
    val topology: UniqueIdRelation,
    val state: UniqueIdRelation,
)

/** Hashes each candidate signal in process memory and returns relation labels only. */
internal class AlternativeIdentityRelationProbe {
    private val nodeHandleTracker = UniqueIdRelationTracker()
    private val topologyTracker = UniqueIdRelationTracker()
    private val stateTracker = UniqueIdRelationTracker()

    fun observe(
        appId: String,
        versionName: String,
        resourceName: String,
        occurrence: Int,
        nodeHandle: String?,
        topologySignature: String?,
        stateSignature: String?,
        elapsedRealtimeMillis: Long,
    ): AlternativeIdentityRelations {
        return AlternativeIdentityRelations(
            nodeHandle = observeSignal(
                nodeHandleTracker,
                appId,
                versionName,
                resourceName,
                occurrence,
                nodeHandle,
                elapsedRealtimeMillis,
            ),
            topology = observeSignal(
                topologyTracker,
                appId,
                versionName,
                resourceName,
                occurrence,
                topologySignature,
                elapsedRealtimeMillis,
            ),
            state = observeSignal(
                stateTracker,
                appId,
                versionName,
                resourceName,
                occurrence,
                stateSignature,
                elapsedRealtimeMillis,
            ),
        )
    }

    fun clear() {
        nodeHandleTracker.clear()
        topologyTracker.clear()
        stateTracker.clear()
    }

    private fun observeSignal(
        tracker: UniqueIdRelationTracker,
        appId: String,
        versionName: String,
        resourceName: String,
        occurrence: Int,
        value: String?,
        elapsedRealtimeMillis: Long,
    ): UniqueIdRelation = tracker.observe(
        appId = appId,
        versionName = versionName,
        resourceName = resourceName,
        occurrence = occurrence,
        opaqueUniqueId = value,
        elapsedRealtimeMillis = elapsedRealtimeMillis,
        apiAvailable = true,
    )
}
