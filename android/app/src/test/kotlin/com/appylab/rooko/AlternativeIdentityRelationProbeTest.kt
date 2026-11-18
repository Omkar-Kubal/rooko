package com.appylab.rooko

import org.junit.Assert.assertEquals
import org.junit.Test

class AlternativeIdentityRelationProbeTest {
    @Test
    fun stationaryItemKeepsNodeHandleAndBothStructuralSignalsStable() {
        val probe = AlternativeIdentityRelationProbe()

        val first = probe.observe(
            appId = "instagram",
            versionName = "454.0.0.54.77",
            resourceName = "clips_video_container",
            occurrence = 0,
            nodeHandle = "node-44",
            topologySignature = "FrameLayout|2|childA,childB",
            stateSignature = "visible|selected|bounds=0,32,1024,1984",
            elapsedRealtimeMillis = 0,
        )
        val stationary = probe.observe(
            appId = "instagram",
            versionName = "454.0.0.54.77",
            resourceName = "clips_video_container",
            occurrence = 0,
            nodeHandle = "node-44",
            topologySignature = "FrameLayout|2|childA,childB",
            stateSignature = "visible|selected|bounds=0,32,1024,1984",
            elapsedRealtimeMillis = 100,
        )

        assertEquals(UniqueIdRelation.FIRST, first.nodeHandle)
        assertEquals(UniqueIdRelation.FIRST, first.topology)
        assertEquals(UniqueIdRelation.FIRST, first.state)
        assertEquals(UniqueIdRelation.SAME, stationary.nodeHandle)
        assertEquals(UniqueIdRelation.SAME, stationary.topology)
        assertEquals(UniqueIdRelation.SAME, stationary.state)
    }

    @Test
    fun changedItemCanChangeHandleAndTopologyWhileGeometryStaysTheSame() {
        val probe = AlternativeIdentityRelationProbe()

        probe.observe(
            appId = "youtube",
            versionName = "21.32.4",
            resourceName = "reel_player_page_container",
            occurrence = 0,
            nodeHandle = "node-44",
            topologySignature = "FrameLayout|2|childA,childB",
            stateSignature = "visible|bounds=0,96,1056,2144",
            elapsedRealtimeMillis = 0,
        )
        val changed = probe.observe(
            appId = "youtube",
            versionName = "21.32.4",
            resourceName = "reel_player_page_container",
            occurrence = 0,
            nodeHandle = "node-45",
            topologySignature = "FrameLayout|3|childA,childB,childC",
            stateSignature = "visible|bounds=0,96,1056,2144",
            elapsedRealtimeMillis = 100,
        )

        assertEquals(UniqueIdRelation.CHANGED, changed.nodeHandle)
        assertEquals(UniqueIdRelation.CHANGED, changed.topology)
        assertEquals(UniqueIdRelation.SAME, changed.state)
    }

    @Test
    fun missingAndOversizedSignalsDoNotProduceAContinuityClaim() {
        val probe = AlternativeIdentityRelationProbe()
        val missing = probe.observe(
            appId = "instagram",
            versionName = "454.0.0.54.77",
            resourceName = "clips_video_container",
            occurrence = 0,
            nodeHandle = null,
            topologySignature = null,
            stateSignature = null,
            elapsedRealtimeMillis = 0,
        )
        val oversized = probe.observe(
            appId = "instagram",
            versionName = "454.0.0.54.77",
            resourceName = "clips_video_container",
            occurrence = 0,
            nodeHandle = "node-44",
            topologySignature = "x".repeat(513),
            stateSignature = "visible",
            elapsedRealtimeMillis = 100,
        )

        assertEquals(UniqueIdRelation.NO_VALUE, missing.nodeHandle)
        assertEquals(UniqueIdRelation.NO_VALUE, missing.topology)
        assertEquals(UniqueIdRelation.NO_VALUE, missing.state)
        assertEquals(UniqueIdRelation.INVALID_VALUE, oversized.topology)
    }
}
