package com.heykakaa.rooko

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class EstimatorProbeFormatterTest {
    @Test
    fun formatsOnlyAllowlistedPackageVersionAndStaticOutcome() {
        assertEquals(
            "instagram\t456.1.0.56.78\tOUTCOME_COUNTED",
            EstimatorProbeFormatter.format(
                appId = "instagram",
                versionName = "456.1.0.56.78",
                outcome = EstimatorProbeCategory.OUTCOME_COUNTED,
            ),
        )
    }

    @Test
    fun refusesUnexpectedAppIdsAndVersionText() {
        assertNull(
            EstimatorProbeFormatter.format(
                appId = "unknown",
                versionName = "1.0",
                outcome = EstimatorProbeCategory.FEED_RECOGNIZED,
            ),
        )
        assertNull(
            EstimatorProbeFormatter.format(
                appId = "instagram",
                versionName = "caption text",
                outcome = EstimatorProbeCategory.FEED_RECOGNIZED,
            ),
        )
    }
}
