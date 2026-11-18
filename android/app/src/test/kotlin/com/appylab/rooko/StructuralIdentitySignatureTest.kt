package com.appylab.rooko

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertNull
import org.junit.Test

class StructuralIdentitySignatureTest {
    @Test
    fun topologySignatureUsesOnlyBoundedChildStructure() {
        val signature = StructuralIdentitySignature.topology(
            className = "android.widget.FrameLayout",
            childCount = 2,
            children = listOf(
                StructuralChildSignal("item_media", "android.view.View", 0, true),
                StructuralChildSignal("item_controls", "android.view.ViewGroup", 1, true),
            ),
        )

        assertEquals(
            "android.widget.FrameLayout|2|item_media:android.view.View:0:true|" +
                "item_controls:android.view.ViewGroup:1:true",
            signature,
        )
    }

    @Test
    fun incompleteOrOversizedTopologyDoesNotCreateASignature() {
        assertNull(
            StructuralIdentitySignature.topology(
                className = "android.widget.FrameLayout",
                childCount = 2,
                children = listOf(StructuralChildSignal("item_media", "android.view.View", 0, true)),
            ),
        )
        assertNull(
            StructuralIdentitySignature.topology(
                className = "android.widget.FrameLayout",
                childCount = 17,
                children = emptyList(),
            ),
        )
    }

    @Test
    fun rootItemIdentityCombinesNodeHandleAndBoundedTopology() {
        val topology = StructuralIdentitySignature.topology(
            className = "android.widget.FrameLayout",
            childCount = 1,
            children = listOf(StructuralChildSignal("item_media", "android.view.View", 0, true)),
        )

        val identity = StructuralIdentitySignature.nodeHandleAndTopology(42, topology)

        assertEquals("handle=42|topology=android.widget.FrameLayout|1|item_media:android.view.View:0:true", identity)
        assertNotEquals(identity, StructuralIdentitySignature.nodeHandleAndTopology(43, topology))
        assertNull(StructuralIdentitySignature.nodeHandleAndTopology(42, null))
    }

    @Test
    fun stateSignatureContainsOnlyVisibilitySelectionScrollAndCoarseBounds() {
        assertEquals(
            "visible=true|selected=false|scrollable=true|bounds=0,32,1024,1984",
            StructuralIdentitySignature.state(
                visible = true,
                selected = false,
                scrollable = true,
                bounds = StructuralBounds(0, 32, 1024, 1984),
            ),
        )
    }
}
