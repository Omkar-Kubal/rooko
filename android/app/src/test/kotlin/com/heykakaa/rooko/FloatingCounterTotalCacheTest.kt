package com.heykakaa.rooko

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class FloatingCounterTotalCacheTest {
    @Test
    fun countRecordedDuringLoadPreventsAnOlderQueryFromOverwritingIt() {
        val cache = FloatingCounterTotalCache()
        cache.setScope("2026-11-22", setOf("instagram", "youtube"))
        val initialQuery = cache.beginLoad()

        cache.recordCountedEvent()
        val refreshedQuery = cache.beginLoad()

        assertFalse(cache.acceptLoad(initialQuery, total = 20))
        assertTrue(cache.acceptLoad(refreshedQuery, total = 21))
        assertEquals(21, cache.total)
    }

    @Test
    fun countedEventAfterCacheLoadsIncrementsCachedTotal() {
        val cache = FloatingCounterTotalCache()
        cache.setScope("2026-11-22", setOf("instagram"))
        assertTrue(cache.acceptLoad(cache.beginLoad(), total = 12))

        assertEquals(13, cache.recordCountedEvent())
        assertEquals(13, cache.total)
    }

    @Test
    fun dateOrAppSelectionChangeClearsThePreviousScope() {
        val cache = FloatingCounterTotalCache()
        cache.setScope("2026-11-22", setOf("instagram"))
        val oldScopeQuery = cache.beginLoad()
        assertTrue(cache.acceptLoad(oldScopeQuery, total = 12))

        assertTrue(cache.setScope("2026-11-23", setOf("youtube")))

        assertEquals(0, cache.total)
        assertFalse(cache.acceptLoad(oldScopeQuery, total = 12))
        assertEquals(0, cache.total)
    }
}
