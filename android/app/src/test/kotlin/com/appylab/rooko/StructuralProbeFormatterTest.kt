package com.appylab.rooko

import org.junit.Assert.assertFalse
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class StructuralProbeFormatterTest {
    @Test
    fun acceptsOnlyResourceIdsFromTheSelectedPackage() {
        assertEquals(
            "clips_viewer_view_pager",
            StructuralProbeFormatter.resourceNameFor(
                "com.instagram.android:id/clips_viewer_view_pager",
                "com.instagram.android",
            ),
        )
        assertNull(StructuralProbeFormatter.resourceNameFor("privatecaption", "com.instagram.android"))
        assertNull(
            StructuralProbeFormatter.resourceNameFor(
                "com.other.app:id/clips_viewer_view_pager",
                "com.instagram.android",
            ),
        )
    }

    @Test
    fun keepsOnlyStructuralResourceNamesAndCoarseTime() {
        val line = StructuralProbeFormatter.format(
            appId = "instagram",
            versionName = "454.0.0.54.77",
            eventType = 4096,
            fromIndex = 0,
            toIndex = 1,
            sourceId = "clips_viewer_view_pager",
            viewIds = setOf("clips_viewer_view_pager", "private caption", "user@example.com"),
            nodeFeatures = listOf(
                StructuralNodeFeature(
                    resourceName = "clips_video_container",
                    className = "android.view.ViewGroup",
                    childCount = 3,
                    scrollable = false,
                    selected = false,
                    visible = true,
                    bounds = StructuralBounds(0, 32, 1024, 1984),
                ),
            ),
            elapsedRealtimeMillis = 1_234,
        )

        assertTrue(line.startsWith("1200\tinstagram\t454.0.0.54.77\t4096\t0\t1"))
        assertTrue(line.contains("clips_viewer_view_pager"))
        assertFalse(line.contains("private caption"))
        assertFalse(line.contains("user@example.com"))
        assertTrue(line.contains("clips_video_container|android.view.ViewGroup|3|false|false|true|0,32,1024,1984"))
    }

    @Test
    fun identityProbeWritesOnlyAContinuityLabel() {
        val line = StructuralProbeFormatter.format(
            appId = "youtube",
            versionName = "21.44.534",
            eventType = 2048,
            fromIndex = -1,
            toIndex = -1,
            sourceId = "reel_player_page_container",
            viewIds = setOf("reel_player_page_container"),
            nodeFeatures = listOf(
                StructuralNodeFeature(
                    resourceName = "reel_player_page_container",
                    className = "android.widget.FrameLayout",
                    childCount = 2,
                    scrollable = false,
                    selected = false,
                    visible = true,
                    bounds = StructuralBounds(0, 96, 1056, 2144),
                    identityOrdinal = 0,
                    uniqueIdRelation = UniqueIdRelation.CHANGED,
                ),
            ),
            elapsedRealtimeMillis = 2_000,
        )

        assertTrue(line.contains("|identity0=changed"))
        assertFalse(line.contains("private-unique-id"))
    }

    @Test
    fun alternativeIdentityProbeWritesOnlySignalRelationLabels() {
        val line = StructuralProbeFormatter.format(
            appId = "instagram",
            versionName = "454.0.0.54.77",
            eventType = 2048,
            fromIndex = -1,
            toIndex = -1,
            sourceId = "clips_video_container",
            viewIds = setOf("clips_video_container"),
            nodeFeatures = listOf(
                StructuralNodeFeature(
                    resourceName = "clips_video_container",
                    className = "android.view.ViewGroup",
                    childCount = 2,
                    scrollable = false,
                    selected = false,
                    visible = true,
                    bounds = StructuralBounds(0, 32, 1024, 1984),
                    identityOrdinal = 0,
                    alternativeIdentityRelations = AlternativeIdentityRelations(
                        nodeHandle = UniqueIdRelation.SAME,
                        topology = UniqueIdRelation.CHANGED,
                        state = UniqueIdRelation.SAME,
                    ),
                ),
            ),
            elapsedRealtimeMillis = 2_000,
        )

        assertTrue(line.contains("|nodehandle0=same|topology0=changed|state0=same"))
        assertFalse(line.contains("node-44"))
        assertFalse(line.contains("childA"))
    }
}
