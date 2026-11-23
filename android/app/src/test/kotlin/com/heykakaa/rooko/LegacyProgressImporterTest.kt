package com.heykakaa.rooko

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class LegacyProgressImporterTest {
    @Test
    fun parsesExistingEstimatedAggregateWithoutChangingItsDateOrConfidence() {
        val aggregate = LegacyProgressImporter.parseAggregate(
            key = "daily_count|2026-11-06|youtube|estimated",
            value = 9,
        )

        assertEquals(
            LegacyDailyAggregate(
                localDate = "2026-11-06",
                appId = "youtube",
                confidence = CountConfidence.ESTIMATED,
                count = 9,
            ),
            aggregate,
        )
    }

    @Test
    fun rejectsMalformedOrNegativeLegacyCounts() {
        assertNull(
            LegacyProgressImporter.parseAggregate(
                key = "daily_count|bad-date|youtube|confirmed",
                value = 3,
            ),
        )
        assertNull(
            LegacyProgressImporter.parseAggregate(
                key = "daily_count|2026-11-06|youtube|confirmed",
                value = -1,
            ),
        )
    }

    @Test
    fun parsesLastDetectionOnlyForAValidLocalDate() {
        assertEquals(
            LegacyLastDetection("2026-11-06", 1_800_000_000_000L),
            LegacyProgressImporter.parseLastDetection(
                key = "last_detection_at_ms|2026-11-06",
                value = 1_800_000_000_000L,
            ),
        )
        assertNull(
            LegacyProgressImporter.parseLastDetection(
                key = "last_detection_at_ms|not-a-date",
                value = 10L,
            ),
        )
    }
}
