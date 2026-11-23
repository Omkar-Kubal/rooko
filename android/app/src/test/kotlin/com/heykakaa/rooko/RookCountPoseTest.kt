package com.heykakaa.rooko

import org.junit.Assert.assertEquals
import org.junit.Test

class RookCountPoseTest {
    @Test
    fun `combined count selects the five fixed counter bands`() {
        listOf(
            0 to RookCountPose.READY,
            49 to RookCountPose.READY,
            50 to RookCountPose.STRAINED,
            99 to RookCountPose.STRAINED,
            100 to RookCountPose.INJURED,
            149 to RookCountPose.INJURED,
            150 to RookCountPose.QUEASY,
            199 to RookCountPose.QUEASY,
            200 to RookCountPose.VOMITING,
            1000 to RookCountPose.VOMITING,
        ).forEach { (count, expected) ->
            assertEquals("count $count", expected, RookCountPose.fromCount(count))
        }
    }

    @Test(expected = IllegalArgumentException::class)
    fun `negative count is rejected`() {
        RookCountPose.fromCount(-1)
    }
}
