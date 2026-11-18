package com.appylab.rooko

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class HostActivityResumePolicyTest {
    @Test
    fun `host resume consumes recognized feed exits exactly once`() {
        val recognized = mutableSetOf("youtube", "instagram")

        val exits = HostActivityResumePolicy.consumeRecognizedFeedExits(recognized)

        assertEquals(setOf("youtube", "instagram"), exits)
        assertTrue(recognized.isEmpty())
        assertTrue(HostActivityResumePolicy.consumeRecognizedFeedExits(recognized).isEmpty())
    }

    @Test
    fun `host resume has no feed exit to report without a recognized feed`() {
        val recognized = mutableSetOf<String>()

        assertTrue(HostActivityResumePolicy.consumeRecognizedFeedExits(recognized).isEmpty())
        assertTrue(recognized.isEmpty())
    }
}
