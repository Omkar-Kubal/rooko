package com.appylab.rooko

import android.content.Context
import android.database.sqlite.SQLiteDatabase
import androidx.room.Room
import java.io.Closeable
import java.io.File
import java.io.IOException
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.time.ZoneOffset
import java.util.UUID
import java.util.concurrent.Callable
import java.util.concurrent.ExecutorService
import java.util.concurrent.ExecutionException
import java.util.concurrent.Executors

internal enum class ProgressCoverage { UNKNOWN, PARTIAL, VERIFIED }

internal data class ProgressAppTotal(
    val appId: String,
    val confirmedCount: Int,
    val estimatedCount: Int,
    val correctionDelta: Int,
    val correctionCount: Int,
    val pendingUndoCorrectionId: String?,
) {
    val adjustedConfirmedCount: Int
        get() = (confirmedCount + correctionDelta).coerceAtLeast(0)
}

internal data class ProgressDay(
    val localDate: String,
    val timeZoneId: String?,
    val offsetSeconds: Int?,
    val coverage: ProgressCoverage,
    val coverageReason: String?,
    val lastDetectionAtMillis: Long,
    val apps: List<ProgressAppTotal>,
    val hourlyCounts: List<Int> = emptyList(),
    val countedTimes: List<CountedTime> = emptyList(),
    val hasHourlyBreakdown: Boolean = false,
    val isPersonalBest: Boolean = false,
    val observedFeedDurationMillis: Long? = null,
)

internal data class CountedTime(
    val appId: String,
    val wallClockMillis: Long,
    val offsetSeconds: Int,
)

internal data class StoredCorrection(
    val id: String,
    val localDate: String,
    val appId: String,
    val delta: Int,
    val reason: String?,
    val createdAtMillis: Long,
    val reversesCorrectionId: String?,
)

internal class InvalidCorrectionException(message: String) : IllegalArgumentException(message)

internal class ProgressRepository(
    private val database: RookoDatabase,
    private val databaseExecutor: ExecutorService? = null,
    private val nowMillis: () -> Long = System::currentTimeMillis,
) : Closeable {
    private val dao = database.progressDao()

    fun importLegacy(values: Map<String, *>, partialCoverageDate: String? = null): Boolean =
        onDatabase {
            var imported = false
            database.runInTransaction {
                if (dao.metadata(LEGACY_IMPORT_MARKER) != null) return@runInTransaction

                val aggregates = values.entries.mapNotNull { (key, value) ->
                    LegacyProgressImporter.parseAggregate(key, value)
                }.groupBy { it.localDate to it.appId }

                aggregates.forEach { (dateAndApp, rows) ->
                    val (date, appId) = dateAndApp
                    val confirmed = rows.filter {
                        it.confidence == CountConfidence.CONFIRMED
                    }.sumOf { it.count }
                    val estimated = rows.filter {
                        it.confidence == CountConfidence.ESTIMATED
                    }.sumOf { it.count }
                    dao.putAggregate(
                        DailyAppAggregateEntity(
                            localDate = date,
                            appId = appId,
                            confirmedCount = confirmed,
                            estimatedCount = estimated,
                        ),
                    )
                    ensureLegacyDay(date)
                }

                values.entries.mapNotNull { (key, value) ->
                    LegacyProgressImporter.parseLastDetection(key, value)
                }.forEach { detection ->
                    val day = dao.day(detection.localDate) ?: newUnknownDay(detection.localDate)
                    dao.putDay(day.copy(lastDetectionAtMillis = detection.wallClockMillis))
                }

                partialCoverageDate?.let { date ->
                    if (validDate(date)) markCoveragePartialInternal(date, "Tracking service was interrupted")
                }
                dao.putMetadata(DatabaseMetadataEntity(LEGACY_IMPORT_MARKER, "complete"))
                imported = true
            }
            imported
        }

    fun recordCount(
        appId: String,
        localDate: String,
        confidence: CountConfidence,
        wallClockMillis: Long,
        timeZoneId: String = ZoneId.systemDefault().id,
        offsetSeconds: Int = ZoneId.systemDefault()
            .rules.getOffset(Instant.ofEpochMilli(wallClockMillis)).totalSeconds,
    ) = onDatabase {
        require(SupportedAppsNative.byId(appId) != null) { "Unsupported app id" }
        require(validDate(localDate)) { "Invalid local date" }
        database.runInTransaction {
            val day = dao.day(localDate)
            if (day == null) {
                dao.putDay(
                    ProgressDayEntity(
                        localDate = localDate,
                        timeZoneId = timeZoneId,
                        offsetSeconds = offsetSeconds,
                        coverage = ProgressCoverage.UNKNOWN.name,
                        coverageReason = null,
                        lastDetectionAtMillis = wallClockMillis,
                    ),
                )
            } else {
                val timezoneStillConsistent = day.timeZoneId == timeZoneId &&
                    day.offsetSeconds == offsetSeconds
                dao.putDay(
                    day.copy(
                        timeZoneId = if (timezoneStillConsistent) day.timeZoneId else null,
                        offsetSeconds = if (timezoneStillConsistent) day.offsetSeconds else null,
                        coverage = if (timezoneStillConsistent) {
                            day.coverage
                        } else {
                            ProgressCoverage.PARTIAL.name
                        },
                        coverageReason = if (timezoneStillConsistent) {
                            day.coverageReason
                        } else {
                            "Time zone evidence changed during the day"
                        },
                        lastDetectionAtMillis = maxOf(day.lastDetectionAtMillis, wallClockMillis),
                    ),
                )
                if (!timezoneStillConsistent) dao.deleteVerificationDay(localDate)
            }

            val old = dao.aggregate(localDate, appId)
            dao.putAggregate(
                when (confidence) {
                    CountConfidence.CONFIRMED -> DailyAppAggregateEntity(
                        localDate = localDate,
                        appId = appId,
                        confirmedCount = (old?.confirmedCount ?: 0) + 1,
                        estimatedCount = old?.estimatedCount ?: 0,
                    )
                    CountConfidence.ESTIMATED -> DailyAppAggregateEntity(
                        localDate = localDate,
                        appId = appId,
                        confirmedCount = old?.confirmedCount ?: 0,
                        estimatedCount = (old?.estimatedCount ?: 0) + 1,
                    )
                },
            )
            val hour = Instant.ofEpochMilli(wallClockMillis)
                .atOffset(ZoneOffset.ofTotalSeconds(offsetSeconds)).hour
            if (dao.incrementHour(localDate, hour) == 0) {
                dao.insertHour(HourlyCountEntity(localDate, hour, 1))
            }
            dao.insertCountedTime(
                CountedEventTimeEntity(
                    localDate = localDate,
                    appId = appId,
                    wallClockMillis = wallClockMillis,
                    offsetSeconds = offsetSeconds,
                ),
            )
            dao.pruneCountedTimes(nowMillis() - COUNTED_TIME_RETENTION_MILLIS)
        }
    }

    fun recordObservedFeedDuration(
        localDate: String,
        durationMillis: Long,
        timeZoneId: String,
        offsetSeconds: Int,
    ) = onDatabase {
        require(validDate(localDate)) { "Invalid local date" }
        if (durationMillis <= 0L) return@onDatabase

        database.runInTransaction {
            val existing = dao.day(localDate)
            val base = existing ?: ProgressDayEntity(
                localDate = localDate,
                timeZoneId = timeZoneId,
                offsetSeconds = offsetSeconds,
                coverage = ProgressCoverage.UNKNOWN.name,
                coverageReason = null,
                lastDetectionAtMillis = 0L,
            )
            val hasTimezoneEvidence = base.timeZoneId != null && base.offsetSeconds != null
            val timezoneStillConsistent = !hasTimezoneEvidence ||
                (base.timeZoneId == timeZoneId && base.offsetSeconds == offsetSeconds)
            val updatedBase = if (timezoneStillConsistent) {
                base
            } else {
                dao.deleteVerificationDay(localDate)
                base.copy(
                    timeZoneId = null,
                    offsetSeconds = null,
                    coverage = ProgressCoverage.PARTIAL.name,
                    coverageReason = "Time zone evidence changed during the day",
                )
            }
            dao.putDay(
                updatedBase.copy(
                    observedFeedDurationMillis =
                        (updatedBase.observedFeedDurationMillis ?: 0L) + durationMillis,
                ),
            )
        }
    }

    fun checkpointDayVerification(
        localDate: String,
        dayStartMillis: Long,
        environment: DailyVerificationEnvironment,
    ) = onDatabase {
        require(validDate(localDate)) { "Invalid local date" }
        database.runInTransaction {
            var hadCurrentCandidate = false
            dao.verificationDays().forEach { row ->
                val candidate = row.toCandidate()
                when {
                    row.localDate == localDate -> {
                        hadCurrentCandidate = true
                        if (DailyVerificationPolicy.canContinue(candidate, environment)) {
                            dao.putVerificationDay(
                                row.copy(lastCheckpointMillis = environment.nowMillis),
                            )
                        } else {
                            markVerificationFailed(row.localDate, candidate, environment)
                        }
                    }
                    row.localDate < localDate -> {
                        val oldDate = LocalDate.parse(row.localDate)
                        val oldZone = ZoneId.of(row.timeZoneId)
                        val oldStart = oldDate.atStartOfDay(oldZone).toInstant().toEpochMilli()
                        val oldEnd = oldDate.plusDays(1).atStartOfDay(oldZone)
                            .toInstant().toEpochMilli()
                        if (
                            DailyVerificationPolicy.canComplete(
                                candidate = candidate,
                                dayStartMillis = oldStart,
                                nextDayStartMillis = oldEnd,
                                environment = environment,
                            )
                        ) {
                            val day = dao.day(row.localDate) ?: newUnknownDay(row.localDate)
                            dao.putDay(
                                day.copy(
                                    coverage = ProgressCoverage.VERIFIED.name,
                                    coverageReason = null,
                                    timeZoneId = row.timeZoneId,
                                    offsetSeconds = row.offsetSeconds,
                                ),
                            )
                            dao.deleteVerificationDay(row.localDate)
                        } else {
                            markVerificationFailed(row.localDate, candidate, environment)
                        }
                    }
                    else -> markVerificationFailed(row.localDate, candidate, environment)
                }
            }

            if (
                !hadCurrentCandidate &&
                dao.verificationDay(localDate) == null &&
                DailyVerificationPolicy.canStart(dayStartMillis, environment)
            ) {
                val previousDay = dao.day(localDate) ?: newUnknownDay(localDate)
                dao.putDay(
                    previousDay.copy(
                        timeZoneId = environment.timeZoneId,
                        offsetSeconds = environment.offsetSeconds,
                    ),
                )
                dao.putVerificationDay(
                    ProgressVerificationEntity(
                        localDate = localDate,
                        startedAtMillis = environment.nowMillis,
                        lastCheckpointMillis = environment.nowMillis,
                        timeZoneId = environment.timeZoneId,
                        offsetSeconds = environment.offsetSeconds,
                        selectedAppFingerprint = environment.selectedAppFingerprint,
                        profileFingerprint = environment.profileFingerprint,
                        processInstanceId = environment.processInstanceId,
                    ),
                )
            }
        }
    }

    fun countsFor(localDate: String, appIds: Set<String>): Map<String, DailyAppCount> =
        onDatabase {
            appIds.associateWith { appId ->
                val row = dao.aggregate(localDate, appId)
                DailyAppCount(row?.confirmedCount ?: 0, row?.estimatedCount ?: 0)
            }
        }

    fun adjustedCountsFor(localDate: String, appIds: Set<String>): Map<String, DailyAppCount> =
        onDatabase {
            appIds.associateWith { appId ->
                val row = dao.aggregate(localDate, appId)
                DailyAppCount(
                    confirmed = ((row?.confirmedCount ?: 0) +
                        dao.correctionDelta(localDate, appId)).coerceAtLeast(0),
                    estimated = row?.estimatedCount ?: 0,
                )
            }
        }

    fun correctionDelta(localDate: String, appId: String): Int =
        onDatabase { dao.correctionDelta(localDate, appId) }

    fun correctionCount(localDate: String, appId: String): Int =
        onDatabase { dao.correctionCount(localDate, appId) }

    fun lastDetectionAtMillis(localDate: String): Long = onDatabase {
        dao.day(localDate)?.lastDetectionAtMillis ?: 0L
    }

    fun queryProgress(startDate: String, endDate: String): List<ProgressDay> = onDatabase {
        require(validDate(startDate) && validDate(endDate) && startDate <= endDate) {
            "Invalid progress date range"
        }
        dao.pruneCountedTimes(nowMillis() - COUNTED_TIME_RETENTION_MILLIS)
        val totalsByDate = dao.aggregates(startDate, endDate).groupBy { it.localDate }
        val rows = dao.days(startDate, endDate)
        var bestCount = dao.verifiedCountsBefore(startDate).minOfOrNull { it.count }
        var mostRecentPersonalBestDate: String? = null
        rows.forEach { day ->
            if (day.coverage != ProgressCoverage.VERIFIED.name) return@forEach
            val count = totalsByDate[day.localDate].orEmpty()
                .sumOf { it.confirmedCount + it.estimatedCount }.toLong()
            val previousBest = bestCount
            if (previousBest == null) {
                bestCount = count
            } else if (count < previousBest) {
                bestCount = count
                mostRecentPersonalBestDate = day.localDate
            }
        }
        rows.map { day ->
            val appTotals = totalsByDate[day.localDate].orEmpty().map { row ->
                ProgressAppTotal(
                    appId = row.appId,
                    confirmedCount = row.confirmedCount,
                    estimatedCount = row.estimatedCount,
                    correctionDelta = dao.correctionDelta(day.localDate, row.appId),
                    correctionCount = dao.correctionCount(day.localDate, row.appId),
                    pendingUndoCorrectionId = dao.pendingUndoCorrection(
                        day.localDate,
                        row.appId,
                    )?.id,
                )
            }.toMutableList()

            // A correction can create the first row for an otherwise empty app/day.
            correctionApps(day.localDate).forEach { appId ->
                if (appTotals.none { it.appId == appId }) {
                    appTotals += ProgressAppTotal(
                        appId = appId,
                        confirmedCount = 0,
                        estimatedCount = 0,
                        correctionDelta = dao.correctionDelta(day.localDate, appId),
                        correctionCount = dao.correctionCount(day.localDate, appId),
                        pendingUndoCorrectionId = dao.pendingUndoCorrection(
                            day.localDate,
                            appId,
                        )?.id,
                    )
                }
            }

            val hourlyRows = dao.hourlyCounts(day.localDate)
            val hourlyByHour = hourlyRows.associate { it.hour to it.count }
            ProgressDay(
                localDate = day.localDate,
                timeZoneId = day.timeZoneId,
                offsetSeconds = day.offsetSeconds,
                coverage = ProgressCoverage.valueOf(day.coverage),
                coverageReason = day.coverageReason,
                lastDetectionAtMillis = day.lastDetectionAtMillis,
                apps = appTotals.sortedBy { it.appId },
                hourlyCounts = List(24) { hour -> hourlyByHour[hour] ?: 0 },
                countedTimes = if (startDate == endDate) {
                    dao.countedTimes(day.localDate).map { time ->
                        CountedTime(time.appId, time.wallClockMillis, time.offsetSeconds)
                    }
                } else emptyList(),
                hasHourlyBreakdown = hourlyRows.sumOf { it.count } ==
                    appTotals.sumOf { it.confirmedCount + it.estimatedCount },
                isPersonalBest = day.localDate == mostRecentPersonalBestDate,
                observedFeedDurationMillis = day.observedFeedDurationMillis,
            )
        }
    }

    fun addCorrection(
        localDate: String,
        appId: String,
        delta: Int,
        reason: String?,
        createdAtMillis: Long,
    ): StoredCorrection = onDatabase {
        validateCorrectionTarget(localDate, appId, delta)
        database.runInTransaction(Callable {
            val aggregate = dao.aggregate(localDate, appId)
            val currentDelta = dao.correctionDelta(localDate, appId)
            if ((aggregate?.confirmedCount ?: 0) + currentDelta + delta < 0) {
                throw InvalidCorrectionException("Adjusted confirmed count cannot be negative")
            }
            markCoveragePartialInternal(localDate, "Progress counts were changed")
            val row = CountCorrectionEntity(
                id = UUID.randomUUID().toString(),
                localDate = localDate,
                appId = appId,
                delta = delta,
                reason = reason?.trim()?.takeIf { it.isNotEmpty() },
                createdAtMillis = createdAtMillis,
                reversesCorrectionId = null,
            )
            dao.insertCorrection(row)
            row.toStoredCorrection()
        })
    }

    fun undoCorrection(id: String, createdAtMillis: Long): StoredCorrection = onDatabase {
        database.runInTransaction(Callable {
            val original = dao.correction(id)
                ?: throw InvalidCorrectionException("Correction was not found")
            if (original.reversesCorrectionId != null || dao.hasReversal(original.id)) {
                throw InvalidCorrectionException("Correction was already undone")
            }
            val aggregate = dao.aggregate(original.localDate, original.appId)
            val currentDelta = dao.correctionDelta(original.localDate, original.appId)
            if ((aggregate?.confirmedCount ?: 0) + currentDelta - original.delta < 0) {
                throw InvalidCorrectionException("Undo would make adjusted confirmed count negative")
            }
            markCoveragePartialInternal(
                original.localDate,
                "Progress counts were changed",
            )
            val reversal = CountCorrectionEntity(
                id = UUID.randomUUID().toString(),
                localDate = original.localDate,
                appId = original.appId,
                delta = -original.delta,
                reason = null,
                createdAtMillis = createdAtMillis,
                reversesCorrectionId = original.id,
            )
            dao.insertCorrection(reversal)
            reversal.toStoredCorrection()
        })
    }

    fun markCoveragePartial(localDate: String, reason: String) = onDatabase {
        require(validDate(localDate)) { "Invalid local date" }
        database.runInTransaction { markCoveragePartialInternal(localDate, reason) }
    }

    fun invalidateDayVerification(localDate: String, reason: String) = onDatabase {
        require(validDate(localDate)) { "Invalid local date" }
        database.runInTransaction { markCoveragePartialInternal(localDate, reason) }
    }

    override fun close() {
        // The application-level provider owns and shares the database lifecycle.
    }

    private fun correctionApps(localDate: String): Set<String> =
        dao.correctionApps(localDate).toSet()

    private fun validateCorrectionTarget(localDate: String, appId: String, delta: Int) {
        require(validDate(localDate)) { "Invalid local date" }
        require(SupportedAppsNative.byId(appId) != null) { "Unsupported app id" }
        if (delta == 0) throw InvalidCorrectionException("Correction must change the count")
    }

    private fun ensureLegacyDay(localDate: String) {
        if (dao.day(localDate) == null) dao.putDay(newUnknownDay(localDate))
    }

    private fun markCoveragePartialInternal(localDate: String, reason: String) {
        val old = dao.day(localDate) ?: newUnknownDay(localDate)
        dao.putDay(old.copy(coverage = ProgressCoverage.PARTIAL.name, coverageReason = reason))
        dao.deleteVerificationDay(localDate)
    }

    private fun markVerificationFailed(
        localDate: String,
        candidate: DailyVerificationCandidate,
        environment: DailyVerificationEnvironment,
    ) {
        val reason = when {
            !environment.trackingAvailable -> "Monitoring or validated app coverage was unavailable"
            candidate.processInstanceId != environment.processInstanceId ->
                "Tracking service restarted during the day"
            candidate.selectedAppFingerprint != environment.selectedAppFingerprint ->
                "Selected apps changed during the day"
            candidate.profileFingerprint != environment.profileFingerprint ->
                "A selected app version was not validated throughout the day"
            candidate.timeZoneId != environment.timeZoneId ||
                candidate.offsetSeconds != environment.offsetSeconds ->
                "Time zone evidence changed during the day"
            environment.nowMillis - candidate.lastCheckpointMillis >
                DailyVerificationPolicy.MAX_CHECKPOINT_GAP_MILLIS ->
                "A monitoring continuity checkpoint was missed"
            else -> "Full-day verification evidence was incomplete"
        }
        markCoveragePartialInternal(localDate, reason)
    }

    private fun ProgressVerificationEntity.toCandidate() = DailyVerificationCandidate(
        localDate = localDate,
        startedAtMillis = startedAtMillis,
        lastCheckpointMillis = lastCheckpointMillis,
        timeZoneId = timeZoneId,
        offsetSeconds = offsetSeconds,
        selectedAppFingerprint = selectedAppFingerprint,
        profileFingerprint = profileFingerprint,
        processInstanceId = processInstanceId,
        valid = true,
    )

    private fun newUnknownDay(localDate: String) = ProgressDayEntity(
        localDate = localDate,
        timeZoneId = null,
        offsetSeconds = null,
        coverage = ProgressCoverage.UNKNOWN.name,
        coverageReason = null,
        lastDetectionAtMillis = 0L,
    )

    private fun validDate(value: String): Boolean = try {
        LocalDate.parse(value).toString() == value
    } catch (_: Exception) {
        false
    }

    private fun <T> onDatabase(block: () -> T): T {
        val executor = databaseExecutor ?: return block()
        return try {
            executor.submit(Callable(block)).get()
        } catch (error: ExecutionException) {
            throw error.cause ?: error
        }
    }

    private fun CountCorrectionEntity.toStoredCorrection() = StoredCorrection(
        id = id,
        localDate = localDate,
        appId = appId,
        delta = delta,
        reason = reason,
        createdAtMillis = createdAtMillis,
        reversesCorrectionId = reversesCorrectionId,
    )

    private companion object {
        const val COUNTED_TIME_RETENTION_MILLIS = 7 * 24 * 60 * 60 * 1000L
        const val LEGACY_IMPORT_MARKER = "shared_preferences_import_v1"
    }
}

internal object ProgressRepositoryProvider {
    private val lock = Any()
    private val databaseExecutor = Executors.newSingleThreadExecutor()

    @Volatile
    private var repository: ProgressRepository? = null

    fun get(context: Context): ProgressRepository = repository ?: synchronized(lock) {
        repository ?: run {
            val appContext = context.applicationContext
            val preferences = appContext.getSharedPreferences(
                SelectedAppAccessibilityService.TRACKING_PREFERENCES,
                Context.MODE_PRIVATE,
            )
            LegacyProgressDatabaseMover.prepare(appContext)
            val database = Room.databaseBuilder(
                appContext,
                RookoDatabase::class.java,
                DATABASE_NAME,
            )
                .addMigrations(
                    RookoDatabase.MIGRATION_1_2,
                    RookoDatabase.MIGRATION_2_3,
                    RookoDatabase.MIGRATION_3_4,
                    RookoDatabase.MIGRATION_4_5,
                    RookoDatabase.MIGRATION_5_6,
                )
                .build()
            val progress = ProgressRepository(database, databaseExecutor)
            progress.importLegacy(
                values = preferences.all,
                partialCoverageDate = preferences.getString(
                    SelectedAppAccessibilityService.SERVICE_INTERRUPTED_LOCAL_DATE_KEY,
                    null,
                ),
            )
            preferences.edit().apply {
                preferences.all.keys
                    .filter { it.startsWith("recent_item|") }
                    .forEach(::remove)
            }.apply()
            progress.also { repository = it }
        }
    }

    private const val DATABASE_NAME = "rooko_progress.db"
}

/** Copies the previous database into the new name after checkpointing its WAL. */
internal object LegacyProgressDatabaseMover {
    private const val LEGACY_DATABASE_NAME = "sync_scroll_history.db"
    private const val PROGRESS_DATABASE_NAME = "rooko_progress.db"

    fun prepare(context: Context) {
        val progressFile = context.getDatabasePath(PROGRESS_DATABASE_NAME)
        if (progressFile.exists()) return
        val legacyFile = context.getDatabasePath(LEGACY_DATABASE_NAME)
        if (!legacyFile.exists()) return

        SQLiteDatabase.openDatabase(legacyFile.path, null, SQLiteDatabase.OPEN_READWRITE).use { database ->
            database.rawQuery("PRAGMA wal_checkpoint(TRUNCATE)", null).use { cursor ->
                if (!cursor.moveToFirst() || cursor.getInt(0) != 0) {
                    throw IOException("Could not checkpoint the previous progress database")
                }
            }
        }

        val stagedFile = File(progressFile.parentFile, "$PROGRESS_DATABASE_NAME.migrating")
        if (stagedFile.exists() && !stagedFile.delete()) {
            throw IOException("Could not clear the staged progress database")
        }
        legacyFile.copyTo(stagedFile)
        if (!stagedFile.renameTo(progressFile)) {
            throw IOException("Could not prepare the progress database")
        }
    }
}
