package com.appylab.rooko

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertNull
import org.junit.Test

class FeedItemFingerprinterTest {
    @Test
    fun feedEntryStartsOneIdentityAndStationaryEventsReuseIt() {
        val fingerprint = FeedItemFingerprinter("session")
        val first = fingerprint.observe(0, transitionObserved = false, feedEntryObserved = true)

        assertEquals(first, fingerprint.observe(0, false, false))
    }

    @Test
    fun newTransitionMayReusePagerIndexWithoutReusingIdentity() {
        val fingerprint = FeedItemFingerprinter("session")
        val first = fingerprint.observe(0, false, true)

        val next = fingerprint.observe(0, true, false)

        assertNotEquals(first, next)
    }

    @Test
    fun unobservedIndexChangeCannotInventAnItem() {
        val fingerprint = FeedItemFingerprinter("session")
        fingerprint.observe(0, false, true)

        assertNull(fingerprint.observe(1, false, false))
    }
}
