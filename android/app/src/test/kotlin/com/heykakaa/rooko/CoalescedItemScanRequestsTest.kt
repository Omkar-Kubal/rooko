package com.heykakaa.rooko

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class CoalescedItemScanRequestsTest {
    @Test
    fun burstOfEventsKeepsOnlyTheLatestPendingRescan() {
        val requests = CoalescedItemScanRequests<Int>()

        assertTrue(requests.request("instagram", 1))
        for (item in 2..101) {
            assertFalse(requests.request("instagram", item))
        }

        assertEquals(101, requests.finish("instagram"))
        assertTrue(requests.request("instagram", 102))
        assertNull(requests.finish("instagram"))
    }

    @Test
    fun feedExitDiscardsThePendingRescanWithoutReleasingTheActiveWorker() {
        val requests = CoalescedItemScanRequests<Int>()

        assertTrue(requests.request("instagram", 1))
        assertFalse(requests.request("instagram", 2))
        requests.discardPending("instagram")

        assertNull(requests.finish("instagram"))
        assertTrue(requests.request("instagram", 3))
    }

    @Test
    fun appsKeepIndependentPendingRescans() {
        val requests = CoalescedItemScanRequests<Int>()

        assertTrue(requests.request("instagram", 1))
        assertTrue(requests.request("youtube", 10))
        assertFalse(requests.request("instagram", 2))

        assertNull(requests.finish("youtube"))
        assertEquals(2, requests.finish("instagram"))
    }
}
