package com.heykakaa.rooko

import android.content.Context
import androidx.room.Room
import java.time.LocalDate
import java.time.ZoneId
import androidx.test.core.app.ApplicationProvider
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35])
class ProgressRepositoryTest {
    private lateinit var database: RookoDatabase
    private lateinit var repository: ProgressRepository

    @Before
    fun setUp() {
        val context = ApplicationProvider.getApplicationContext<Context>()
        database = Room.inMemoryDatabaseBuilder(context, RookoDatabase::class.java)
            .allowMainThreadQueries()
            .build()
        repository = ProgressRepository(database)
    }

    @After
    fun tearDown() {
        database.close()
    }

    @Test
    fun importsExistingAggregatesOnlyOnceAndKeepsUnknownLegacyMetadata() {
        val preferences = mapOf<String, Any?>(
            "daily_count|2026-11-06|instagram|confirmed" to 4,
            "daily_count|2026-11-06|youtube|estimated" to 7,
            "last_detection_at_ms|2026-11-06" to 1_800_000_000_000L,
        )

        repository.importLegacy(preferences)
        repository.importLegacy(preferences + ("daily_count|2026-11-06|instagram|confirmed" to 9))

        val day = repository.queryProgress("2026-11-06", "2026-11-06").single()
        assertNull(day.timeZoneId)
        assertEquals(ProgressCoverage.UNKNOWN, day.coverage)
        assertEquals(1_800_000_000_000L, day.lastDetectionAtMillis)
        assertEquals(4, day.apps.single { it.appId == "instagram" }.confirmedCount)
        assertEquals(7, day.apps.single { it.appId == "youtube" }.estimatedCount)
    }

    @Test
    fun correctionIsAppScopedAppendOnlyAndUndoCanOnlyBeAppliedOnce() {
        repository.recordCount(
            appId = "instagram",
            localDate = "2026-11-06",
            confidence = CountConfidence.CONFIRMED,
            wallClockMillis = 1_800_000_000_000L,
            timeZoneId = "Asia/Kolkata",
            offsetSeconds = 19_800,
        )

        val correction = repository.addCorrection(
            localDate = "2026-11-06",
            appId = "instagram",
            delta = -1,
            reason = "Duplicate",
            createdAtMillis = 1_800_000_000_100L,
        )
        repository.undoCorrection(correction.id, createdAtMillis = 1_800_000_000_200L)
        org.junit.Assert.assertThrows(InvalidCorrectionException::class.java) {
            repository.undoCorrection(correction.id, createdAtMillis = 1_800_000_000_300L)
        }

        val day = repository.queryProgress("2026-11-06", "2026-11-06").single()
        val app = day.apps.single()
        assertEquals(1, app.confirmedCount)
        assertEquals(0, app.correctionDelta)
        assertEquals(null, app.pendingUndoCorrectionId)
        assertEquals(2, repository.correctionCount("2026-11-06", "instagram"))
        assertEquals("Asia/Kolkata", day.timeZoneId)
    }

    @Test
    fun correctionCannotReduceAdjustedConfirmedTotalBelowZero() {
        repository.recordCount(
            appId = "instagram",
            localDate = "2026-11-06",
            confidence = CountConfidence.CONFIRMED,
            wallClockMillis = 1_800_000_000_000L,
            timeZoneId = "Asia/Kolkata",
            offsetSeconds = 19_800,
        )

        repository.addCorrection(
            localDate = "2026-11-06",
            appId = "instagram",
            delta = -1,
            reason = null,
            createdAtMillis = 1_800_000_000_100L,
        )

        org.junit.Assert.assertThrows(InvalidCorrectionException::class.java) {
            repository.addCorrection(
                localDate = "2026-11-06",
                appId = "instagram",
                delta = -1,
                reason = null,
                createdAtMillis = 1_800_000_000_200L,
            )
        }
    }

    @Test
    fun adjustedCountsIncludeCorrectionsAndKeepRawAggregatesUnchanged() {
        repository.recordCount(
            appId = "instagram",
            localDate = "2026-11-06",
            confidence = CountConfidence.CONFIRMED,
            wallClockMillis = 1_800_000_000_000L,
            timeZoneId = "Asia/Kolkata",
            offsetSeconds = 19_800,
        )
        repository.addCorrection(
            localDate = "2026-11-06",
            appId = "instagram",
            delta = 1,
            reason = "Missed item",
            createdAtMillis = 1_800_000_000_100L,
        )

        val raw = repository.countsFor("2026-11-06", setOf("instagram"))
        val adjusted = repository.adjustedCountsFor("2026-11-06", setOf("instagram"))

        assertEquals(1, raw.getValue("instagram").confirmed)
        assertEquals(2, adjusted.getValue("instagram").confirmed)
    }

    @Test
    fun correctionOnlyAppAppearsInProgress() {
        val correction = repository.addCorrection(
            localDate = "2026-11-06",
            appId = "instagram",
            delta = 1,
            reason = "Missed count",
            createdAtMillis = 1_800_000_000_100L,
        )

        val day = repository.queryProgress("2026-11-06", "2026-11-06").single()
        val app = day.apps.single()

        assertEquals("instagram", app.appId)
        assertEquals(0, app.confirmedCount)
        assertEquals(1, app.correctionDelta)
        assertEquals(1, app.correctionCount)
        assertEquals(correction.id, app.pendingUndoCorrectionId)
    }

    @Test
    fun countWritesKeepPerAppConfidenceAndLocalDate() {
        repository.recordCount(
            appId = "instagram",
            localDate = "2026-11-06",
            confidence = CountConfidence.CONFIRMED,
            wallClockMillis = 1_800_000_000_000L,
            timeZoneId = "Asia/Kolkata",
            offsetSeconds = 19_800,
        )
        repository.recordCount(
            appId = "instagram",
            localDate = "2026-11-06",
            confidence = CountConfidence.CONFIRMED,
            wallClockMillis = 1_800_000_000_100L,
            timeZoneId = "Asia/Kolkata",
            offsetSeconds = 19_800,
        )
        repository.recordCount(
            appId = "youtube",
            localDate = "2026-11-07",
            confidence = CountConfidence.ESTIMATED,
            wallClockMillis = 1_800_086_400_000L,
            timeZoneId = "Asia/Kolkata",
            offsetSeconds = 19_800,
        )

        val days = repository.queryProgress("2026-11-06", "2026-11-07")

        assertEquals(2, days.single { it.localDate == "2026-11-06" }
            .apps.single().confirmedCount)
        val nextDayApp = days.single { it.localDate == "2026-11-07" }.apps.single()
        assertEquals("youtube", nextDayApp.appId)
        assertEquals(1, nextDayApp.estimatedCount)
        assertEquals(0, nextDayApp.confirmedCount)
    }

    @Test
    fun hourlyBucketsFollowRecordedLocalTimeAndCombinedCount() {
        val first = java.time.LocalDateTime.of(2026, 11, 6, 8, 15)
            .toInstant(java.time.ZoneOffset.ofHoursMinutes(5, 30)).toEpochMilli()
        val second = java.time.LocalDateTime.of(2026, 11, 6, 21, 40)
            .toInstant(java.time.ZoneOffset.ofHoursMinutes(5, 30)).toEpochMilli()
        for ((appId, time) in listOf("instagram" to first, "youtube" to second)) {
            repository.recordCount(
                appId = appId,
                localDate = "2026-11-06",
                confidence = CountConfidence.ESTIMATED,
                wallClockMillis = time,
                timeZoneId = "Asia/Kolkata",
                offsetSeconds = 19_800,
            )
        }
        val day = repository.queryProgress("2026-11-06", "2026-11-06").single()
        assertTrue(day.hasHourlyBreakdown)
        assertEquals(2, day.hourlyCounts.sum())
        assertEquals(1, day.hourlyCounts[8])
        assertEquals(1, day.hourlyCounts[21])
    }

    @Test
    fun exactCountTimesKeepEachRecordedSecondAndExpireWithoutChangingTotals() {
        val offset = java.time.ZoneOffset.ofHoursMinutes(5, 30)
        val now = java.time.LocalDateTime.of(2026, 11, 17, 18, 0)
            .toInstant(offset).toEpochMilli()
        val first = java.time.LocalDateTime.of(2026, 11, 17, 17, 12, 34)
            .toInstant(offset).toEpochMilli()
        val second = java.time.LocalDateTime.of(2026, 11, 17, 17, 58, 6)
            .toInstant(offset).toEpochMilli()
        val recentRepository = ProgressRepository(database, nowMillis = { now })
        recentRepository.recordCount("instagram", "2026-11-17", CountConfidence.ESTIMATED,
            first, "Asia/Kolkata", 19_800)
        recentRepository.recordCount("youtube", "2026-11-17", CountConfidence.CONFIRMED,
            second, "Asia/Kolkata", 19_800)

        val day = recentRepository.queryProgress("2026-11-17", "2026-11-17").single()
        assertEquals(2, day.hourlyCounts[17])
        assertEquals(listOf(first, second), day.countedTimes.map { it.wallClockMillis })
        assertEquals(listOf("instagram", "youtube"), day.countedTimes.map { it.appId })
        assertTrue(day.countedTimes.all { it.offsetSeconds == 19_800 })

        val afterRetention = ProgressRepository(database,
            nowMillis = { now + 8 * 24 * 60 * 60 * 1000L })
            .queryProgress("2026-11-17", "2026-11-17").single()
        assertTrue(afterRetention.countedTimes.isEmpty())
        assertEquals(2, afterRetention.hourlyCounts[17])
        assertEquals(2, afterRetention.apps.sumOf { it.confirmedCount + it.estimatedCount })
    }

    @Test
    fun importedInterruptionMarksOnlyKnownDatePartial() {
        repository.importLegacy(
            values = mapOf(
                "daily_count|2026-11-06|instagram|confirmed" to 2,
                "daily_count|2026-11-07|youtube|estimated" to 3,
            ),
            partialCoverageDate = "2026-11-06",
        )

        val days = repository.queryProgress("2026-11-06", "2026-11-07")

        assertEquals(ProgressCoverage.PARTIAL, days[0].coverage)
        assertEquals(null, days[0].timeZoneId)
        assertEquals(ProgressCoverage.UNKNOWN, days[1].coverage)
        assertEquals(null, days[1].timeZoneId)
    }

    @Test
    fun personalBestRequiresAStrictlyLowerVerifiedCountAndShowsTheLatestRecord() {
        putVerifiedDay("2026-11-01", 7)
        putVerifiedDay("2026-11-06", 5)
        putVerifiedDay("2026-11-07", 5)
        putVerifiedDay("2026-11-08", 4)
        putVerifiedDay("2026-11-09", 0, coverage = ProgressCoverage.PARTIAL)
        putVerifiedDay("2026-11-10", 1, coverage = ProgressCoverage.UNKNOWN)

        val days = repository.queryProgress("2026-11-01", "2026-11-10")

        assertEquals("2026-11-08", days.single { it.isPersonalBest }.localDate)
        assertFalse(days.single { it.localDate == "2026-11-01" }.isPersonalBest)
        assertFalse(days.single { it.localDate == "2026-11-07" }.isPersonalBest)
        assertFalse(days.single { it.localDate == "2026-11-09" }.isPersonalBest)
        assertFalse(days.single { it.localDate == "2026-11-10" }.isPersonalBest)
    }

    @Test
    fun verifiedZeroCountCanSetAPersonalBest() {
        putVerifiedDay("2026-11-06", 4)
        putVerifiedDay("2026-11-07", null)

        val zeroDay = repository.queryProgress("2026-11-07", "2026-11-07").single()

        assertEquals(0, zeroDay.apps.sumOf { it.confirmedCount + it.estimatedCount })
        assertTrue(zeroDay.isPersonalBest)
    }

    @Test
    fun completeEmptyDayCanBeVerifiedAfterContinuousMidnightCheckpoints() {
        val zone = ZoneId.of("Asia/Kolkata")
        val day = LocalDate.parse("2026-11-06")
        val nextDay = day.plusDays(1)
        val dayStart = day.atStartOfDay(zone).toInstant().toEpochMilli()
        val nextDayStart = nextDay.atStartOfDay(zone).toInstant().toEpochMilli()
        var checkpoint = dayStart + 1_000L
        val selectedFingerprint = "selected-apps-digest"
        val profileFingerprint = "profiles-digest"
        val processInstanceId = "process-a"

        while (checkpoint < nextDayStart - DailyVerificationPolicy.MAX_CHECKPOINT_GAP_MILLIS) {
            repository.checkpointDayVerification(
                localDate = day.toString(),
                dayStartMillis = dayStart,
                environment = verificationEnvironment(
                    now = checkpoint,
                    selectedFingerprint = selectedFingerprint,
                    profileFingerprint = profileFingerprint,
                    processInstanceId = processInstanceId,
                ),
            )
            checkpoint += 5 * 60 * 1_000L
        }

        val nearMidnight = nextDayStart - 5 * 60 * 1_000L
        repository.checkpointDayVerification(
            localDate = day.toString(),
            dayStartMillis = dayStart,
            environment = verificationEnvironment(
                now = nearMidnight,
                selectedFingerprint = selectedFingerprint,
                profileFingerprint = profileFingerprint,
                processInstanceId = processInstanceId,
            ),
        )
        repository.checkpointDayVerification(
            localDate = nextDay.toString(),
            dayStartMillis = nextDayStart,
            environment = verificationEnvironment(
                now = nextDayStart + 1_000L,
                selectedFingerprint = selectedFingerprint,
                profileFingerprint = profileFingerprint,
                processInstanceId = processInstanceId,
            ),
        )

        val verified = repository.queryProgress(day.toString(), day.toString()).single()
        assertEquals(ProgressCoverage.VERIFIED, verified.coverage)
        assertEquals(0, verified.apps.sumOf { it.confirmedCount + it.estimatedCount })
        assertFalse(verified.isPersonalBest)
    }

    @Test
    fun profileLossBetweenCheckpointsStaysUnverifiedAfterTheProfileReturns() {
        val zone = ZoneId.of("Asia/Kolkata")
        val day = LocalDate.parse("2026-11-06")
        val dayStart = day.atStartOfDay(zone).toInstant().toEpochMilli()
        val knownProfile = "profiles-digest"

        repository.checkpointDayVerification(
            localDate = day.toString(),
            dayStartMillis = dayStart,
            environment = verificationEnvironment(
                now = dayStart + 1_000L,
                selectedFingerprint = "selected-apps-digest",
                profileFingerprint = knownProfile,
                processInstanceId = "process-a",
            ),
        )
        val reason = DayVerificationInvalidationPolicy.reasonForProfileObservation(
            profileAvailable = false,
            previousFingerprint = knownProfile,
            currentFingerprint = null,
        )
        repository.invalidateDayVerification(day.toString(), requireNotNull(reason))

        repository.checkpointDayVerification(
            localDate = day.toString(),
            dayStartMillis = dayStart,
            environment = verificationEnvironment(
                now = dayStart + 6 * 60 * 1_000L,
                selectedFingerprint = "selected-apps-digest",
                profileFingerprint = knownProfile,
                processInstanceId = "process-a",
            ),
        )

        val record = repository.queryProgress(day.toString(), day.toString()).single()
        assertEquals(ProgressCoverage.PARTIAL, record.coverage)
        assertEquals(
            "A selected app version did not have a validated detector profile",
            record.coverageReason,
        )
        assertTrue(database.progressDao().verificationDays().isEmpty())
    }

    private fun putVerifiedDay(
        localDate: String,
        count: Int?,
        coverage: ProgressCoverage = ProgressCoverage.VERIFIED,
    ) {
        database.progressDao().putDay(
            ProgressDayEntity(
                localDate = localDate,
                timeZoneId = "Asia/Kolkata",
                offsetSeconds = 19_800,
                coverage = coverage.name,
                coverageReason = null,
                lastDetectionAtMillis = 0L,
            ),
        )
        if (count != null) {
            database.progressDao().putAggregate(
                DailyAppAggregateEntity(
                    localDate = localDate,
                    appId = "youtube",
                    confirmedCount = count,
                    estimatedCount = 0,
                ),
            )
        }
    }

    private fun verificationEnvironment(
        now: Long,
        selectedFingerprint: String,
        profileFingerprint: String,
        processInstanceId: String,
    ) = DailyVerificationEnvironment(
        nowMillis = now,
        timeZoneId = "Asia/Kolkata",
        offsetSeconds = 19_800,
        selectedAppFingerprint = selectedFingerprint,
        profileFingerprint = profileFingerprint,
        processInstanceId = processInstanceId,
        trackingAvailable = true,
    )
}
