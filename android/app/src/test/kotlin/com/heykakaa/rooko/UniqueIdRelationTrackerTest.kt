package com.heykakaa.rooko

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Test

class UniqueIdRelationTrackerTest {
    @Test
    fun permitsIdentityInspectionOnlyForObservedItemContainers() {
        assertEquals(
            true,
            UniqueIdProbeNodeIds.isCandidate("instagram", "clips_video_container"),
        )
        assertEquals(
            true,
            UniqueIdProbeNodeIds.isCandidate("youtube", "reel_player_page_container"),
        )
        assertEquals(false, UniqueIdProbeNodeIds.isCandidate("instagram", "clips_author_username"))
        assertEquals(false, UniqueIdProbeNodeIds.isCandidate("unsupported", "reel_player_page_container"))
    }

    @Test
    fun onlyApi33AndNewerCanReadThePlatformUniqueId() {
        assertEquals(false, UniqueIdRelationTracker.apiLevelSupportsUniqueId(32))
        assertEquals(true, UniqueIdRelationTracker.apiLevelSupportsUniqueId(33))
    }

    @Test
    fun comparesOpaqueIdsWithoutReturningTheIds() {
        val tracker = UniqueIdRelationTracker()

        assertEquals(
            UniqueIdRelation.FIRST,
            tracker.observe("instagram", "454.0.0.54.77", "clips_video_container", 0, "private-a", 0, true),
        )
        assertEquals(
            UniqueIdRelation.SAME,
            tracker.observe("instagram", "454.0.0.54.77", "clips_video_container", 0, "private-a", 100, true),
        )
        val changed = tracker.observe(
            "instagram", "454.0.0.54.77", "clips_video_container", 0, "private-b", 200, true,
        )
        assertEquals(UniqueIdRelation.CHANGED, changed)
        assertNotEquals("private-b", changed.wireValue)
    }

    @Test
    fun reportsApiUnavailableWithoutReadingAnIdentity() {
        val tracker = UniqueIdRelationTracker()

        assertEquals(
            UniqueIdRelation.API_UNAVAILABLE,
            tracker.observe("youtube", "21.44.534", "reel_player_page_container", 0, null, 10, false),
        )
    }

    @Test
    fun reportsMissingIdsWithoutRetainingThePreviousComparison() {
        val tracker = UniqueIdRelationTracker()
        tracker.observe("youtube", "21.44.534", "reel_player_page_container", 0, "private-a", 10, true)

        assertEquals(
            UniqueIdRelation.NO_VALUE,
            tracker.observe("youtube", "21.44.534", "reel_player_page_container", 0, null, 20, true),
        )
        assertEquals(
            UniqueIdRelation.FIRST,
            tracker.observe("youtube", "21.44.534", "reel_player_page_container", 0, "private-a", 30, true),
        )
    }

    @Test
    fun resetsTheComparisonAfterFiveMinutesAndClockReset() {
        val tracker = UniqueIdRelationTracker()
        tracker.observe("youtube", "21.44.534", "reel_player_page_container", 0, "private-a", 10, true)

        assertEquals(
            UniqueIdRelation.FIRST,
            tracker.observe("youtube", "21.44.534", "reel_player_page_container", 0, "private-a", 300_011, true),
        )
        assertEquals(
            UniqueIdRelation.FIRST,
            tracker.observe("youtube", "21.44.534", "reel_player_page_container", 0, "private-a", 5, true),
        )
    }

    @Test
    fun isolatesVersionsAndRepeatedNodeOrdinals() {
        val tracker = UniqueIdRelationTracker()
        tracker.observe("youtube", "21.44.534", "reel_player_page_container", 0, "private-a", 10, true)

        assertEquals(
            UniqueIdRelation.FIRST,
            tracker.observe("youtube", "21.45.100", "reel_player_page_container", 0, "private-a", 20, true),
        )
        assertEquals(
            UniqueIdRelation.FIRST,
            tracker.observe("youtube", "21.44.534", "reel_player_page_container", 1, "private-a", 30, true),
        )
    }

    @Test
    fun clearingTheTrackerStartsANewComparisonSession() {
        val tracker = UniqueIdRelationTracker()
        tracker.observe("instagram", "454.0.0.54.77", "clips_video_container", 0, "private-a", 10, true)
        assertEquals(
            UniqueIdRelation.SAME,
            tracker.observe("instagram", "454.0.0.54.77", "clips_video_container", 0, "private-a", 20, true),
        )

        tracker.clear()

        assertEquals(
            UniqueIdRelation.FIRST,
            tracker.observe("instagram", "454.0.0.54.77", "clips_video_container", 0, "private-a", 30, true),
        )
    }
}
