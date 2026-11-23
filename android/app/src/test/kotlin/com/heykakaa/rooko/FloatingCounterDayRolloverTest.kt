package com.heykakaa.rooko

import java.time.LocalDate
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class FloatingCounterDayRolloverTest {
    @Test
    fun `local midnight refreshes the active counter pose and same-day checkpoints do not`() {
        val yesterday = LocalDate.parse("2026-11-13")
        val today = yesterday.plusDays(1)
        val rollover = FloatingCounterDayRollover(yesterday)
        val recognized = setOf("instagram")

        assertEquals(emptySet<String>(), rollover.appsToRefresh(today.minusDays(1), recognized, counterVisible = true))
        assertEquals(setOf("instagram"), rollover.appsToRefresh(today, recognized, counterVisible = true))
        assertTrue(rollover.appsToRefresh(today, recognized, counterVisible = true).isEmpty())
    }

    @Test
    fun `midnight does not refresh stale recognition after the counter was hidden`() {
        val yesterday = LocalDate.parse("2026-11-13")
        val today = yesterday.plusDays(1)
        val rollover = FloatingCounterDayRollover(yesterday)

        assertTrue(
            rollover.appsToRefresh(
                localDate = today,
                recognizedFeedAppIds = setOf("youtube"),
                counterVisible = false,
            ).isEmpty(),
        )
        assertTrue(
            rollover.appsToRefresh(
                localDate = today,
                recognizedFeedAppIds = setOf("youtube"),
                counterVisible = true,
            ).isEmpty(),
        )
    }

    @Test
    fun `midnight advances even without an active counter`() {
        val yesterday = LocalDate.parse("2026-11-13")
        val today = yesterday.plusDays(1)
        val rollover = FloatingCounterDayRollover(yesterday)

        assertTrue(rollover.appsToRefresh(today, emptySet(), counterVisible = false).isEmpty())
        assertTrue(rollover.appsToRefresh(today, setOf("youtube"), counterVisible = false).isEmpty())
    }
}
