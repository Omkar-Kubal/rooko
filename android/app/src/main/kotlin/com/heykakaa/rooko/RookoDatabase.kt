package com.heykakaa.rooko

import androidx.room.Dao
import androidx.room.Database
import androidx.room.Entity
import androidx.room.Index
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.PrimaryKey
import androidx.room.Query
import androidx.room.RoomDatabase
import androidx.room.migration.Migration
import androidx.sqlite.db.SupportSQLiteDatabase

@Entity(tableName = "progress_day")
internal data class ProgressDayEntity(
    @PrimaryKey val localDate: String,
    val timeZoneId: String?,
    val offsetSeconds: Int?,
    val coverage: String,
    val coverageReason: String?,
    val lastDetectionAtMillis: Long,
    val observedFeedDurationMillis: Long? = null,
)

@Entity(tableName = "progress_verification")
internal data class ProgressVerificationEntity(
    @PrimaryKey val localDate: String,
    val startedAtMillis: Long,
    val lastCheckpointMillis: Long,
    val timeZoneId: String,
    val offsetSeconds: Int,
    val selectedAppFingerprint: String,
    val profileFingerprint: String,
    val processInstanceId: String,
)

internal data class VerifiedDayCountRow(
    val localDate: String,
    val count: Long,
)

@Entity(
    tableName = "daily_app_aggregate",
    primaryKeys = ["localDate", "appId"],
)
internal data class DailyAppAggregateEntity(
    val localDate: String,
    val appId: String,
    val confirmedCount: Int,
    val estimatedCount: Int,
)

@Entity(tableName = "hourly_count", primaryKeys = ["localDate", "hour"])
internal data class HourlyCountEntity(
    val localDate: String,
    val hour: Int,
    val count: Int,
)

@Entity(
    tableName = "counted_event_time",
    indices = [Index(value = ["localDate", "wallClockMillis"])],
)
internal data class CountedEventTimeEntity(
    @PrimaryKey(autoGenerate = true) val id: Long = 0,
    val localDate: String,
    val appId: String,
    val wallClockMillis: Long,
    val offsetSeconds: Int,
)

@Entity(
    tableName = "count_correction",
    indices = [
        Index(value = ["localDate", "appId"]),
        Index(value = ["reversesCorrectionId"], unique = true),
    ],
)
internal data class CountCorrectionEntity(
    @PrimaryKey val id: String,
    val localDate: String,
    val appId: String,
    val delta: Int,
    val reason: String?,
    val createdAtMillis: Long,
    val reversesCorrectionId: String?,
)

@Entity(tableName = "database_metadata")
internal data class DatabaseMetadataEntity(
    @PrimaryKey val key: String,
    val value: String,
)

@Dao
internal interface ProgressDao {
    @Query("SELECT * FROM progress_day WHERE localDate = :localDate")
    fun day(localDate: String): ProgressDayEntity?

    @Query("SELECT * FROM progress_day WHERE localDate BETWEEN :startDate AND :endDate ORDER BY localDate")
    fun days(startDate: String, endDate: String): List<ProgressDayEntity>

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    fun putDay(day: ProgressDayEntity)

    @Query("SELECT * FROM progress_verification ORDER BY localDate")
    fun verificationDays(): List<ProgressVerificationEntity>

    @Query("SELECT * FROM progress_verification WHERE localDate = :localDate")
    fun verificationDay(localDate: String): ProgressVerificationEntity?

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    fun putVerificationDay(day: ProgressVerificationEntity)

    @Query("DELETE FROM progress_verification WHERE localDate = :localDate")
    fun deleteVerificationDay(localDate: String)

    @Query(
        """
        SELECT day.localDate AS localDate,
               COALESCE(SUM(aggregate.confirmedCount + aggregate.estimatedCount), 0) AS count
        FROM progress_day AS day
        LEFT JOIN daily_app_aggregate AS aggregate ON aggregate.localDate = day.localDate
        WHERE day.coverage = 'VERIFIED' AND day.localDate < :startDate
        GROUP BY day.localDate
        ORDER BY day.localDate
        """,
    )
    fun verifiedCountsBefore(startDate: String): List<VerifiedDayCountRow>

    @Query("SELECT * FROM daily_app_aggregate WHERE localDate = :localDate AND appId = :appId")
    fun aggregate(localDate: String, appId: String): DailyAppAggregateEntity?

    @Query("SELECT * FROM daily_app_aggregate WHERE localDate BETWEEN :startDate AND :endDate ORDER BY localDate, appId")
    fun aggregates(startDate: String, endDate: String): List<DailyAppAggregateEntity>

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    fun putAggregate(aggregate: DailyAppAggregateEntity)

    @Query("SELECT * FROM hourly_count WHERE localDate = :localDate ORDER BY hour")
    fun hourlyCounts(localDate: String): List<HourlyCountEntity>

    @Query("UPDATE hourly_count SET count = count + 1 WHERE localDate = :localDate AND hour = :hour")
    fun incrementHour(localDate: String, hour: Int): Int

    @Insert(onConflict = OnConflictStrategy.IGNORE)
    fun insertHour(hour: HourlyCountEntity)

    @Insert
    fun insertCountedTime(time: CountedEventTimeEntity)

    @Query("SELECT * FROM counted_event_time WHERE localDate = :localDate ORDER BY wallClockMillis, id")
    fun countedTimes(localDate: String): List<CountedEventTimeEntity>

    @Query("DELETE FROM counted_event_time WHERE wallClockMillis < :cutoffMillis")
    fun pruneCountedTimes(cutoffMillis: Long)

    @Query("SELECT COALESCE(SUM(delta), 0) FROM count_correction WHERE localDate = :localDate AND appId = :appId")
    fun correctionDelta(localDate: String, appId: String): Int

    @Query("SELECT COUNT(*) FROM count_correction WHERE localDate = :localDate AND appId = :appId")
    fun correctionCount(localDate: String, appId: String): Int

    @Query("SELECT DISTINCT appId FROM count_correction WHERE localDate = :localDate")
    fun correctionApps(localDate: String): List<String>

    @Query("""
        SELECT correction.* FROM count_correction AS correction
        WHERE correction.localDate = :localDate
          AND correction.appId = :appId
          AND correction.reversesCorrectionId IS NULL
          AND NOT EXISTS (
            SELECT 1 FROM count_correction AS reversal
            WHERE reversal.reversesCorrectionId = correction.id
          )
        ORDER BY correction.createdAtMillis DESC, correction.id DESC
        LIMIT 1
        """)
    fun pendingUndoCorrection(localDate: String, appId: String): CountCorrectionEntity?

    @Query("SELECT * FROM count_correction WHERE id = :id")
    fun correction(id: String): CountCorrectionEntity?

    @Query("SELECT EXISTS(SELECT 1 FROM count_correction WHERE reversesCorrectionId = :id)")
    fun hasReversal(id: String): Boolean

    @Insert(onConflict = OnConflictStrategy.ABORT)
    fun insertCorrection(correction: CountCorrectionEntity)

    @Query("SELECT value FROM database_metadata WHERE `key` = :key")
    fun metadata(key: String): String?

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    fun putMetadata(metadata: DatabaseMetadataEntity)
}

@Database(
    entities = [
        ProgressDayEntity::class,
        ProgressVerificationEntity::class,
        DailyAppAggregateEntity::class,
        HourlyCountEntity::class,
        CountedEventTimeEntity::class,
        CountCorrectionEntity::class,
        DatabaseMetadataEntity::class,
    ],
    version = 6,
    exportSchema = true,
)
internal abstract class RookoDatabase : RoomDatabase() {
    abstract fun progressDao(): ProgressDao

    companion object {
        val MIGRATION_1_2 = object : Migration(1, 2) {
            override fun migrate(database: SupportSQLiteDatabase) {
                database.execSQL(
                    """
                    CREATE TABLE IF NOT EXISTS history_verification (
                        localDate TEXT NOT NULL,
                        startedAtMillis INTEGER NOT NULL,
                        lastCheckpointMillis INTEGER NOT NULL,
                        timeZoneId TEXT NOT NULL,
                        offsetSeconds INTEGER NOT NULL,
                        selectedAppFingerprint TEXT NOT NULL,
                        profileFingerprint TEXT NOT NULL,
                        processInstanceId TEXT NOT NULL,
                        PRIMARY KEY(localDate)
                    )
                    """.trimIndent(),
                )
            }
        }

        val MIGRATION_2_3 = object : Migration(2, 3) {
            override fun migrate(database: SupportSQLiteDatabase) {
                database.execSQL("ALTER TABLE history_day RENAME TO progress_day")
                database.execSQL("ALTER TABLE history_verification RENAME TO progress_verification")
            }
        }

        val MIGRATION_3_4 = object : Migration(3, 4) {
            override fun migrate(database: SupportSQLiteDatabase) {
                database.execSQL(
                    "CREATE TABLE IF NOT EXISTS hourly_count (" +
                        "localDate TEXT NOT NULL, hour INTEGER NOT NULL, " +
                        "count INTEGER NOT NULL, PRIMARY KEY(localDate, hour))",
                )
            }
        }

        val MIGRATION_4_5 = object : Migration(4, 5) {
            override fun migrate(database: SupportSQLiteDatabase) {
                database.execSQL(
                    "CREATE TABLE IF NOT EXISTS counted_event_time (" +
                        "id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL, " +
                        "localDate TEXT NOT NULL, appId TEXT NOT NULL, " +
                        "wallClockMillis INTEGER NOT NULL, offsetSeconds INTEGER NOT NULL)",
                )
                database.execSQL(
                    "CREATE INDEX IF NOT EXISTS index_counted_event_time_localDate_wallClockMillis " +
                        "ON counted_event_time(localDate, wallClockMillis)",
                )
            }
        }

        val MIGRATION_5_6 = object : Migration(5, 6) {
            override fun migrate(database: SupportSQLiteDatabase) {
                database.execSQL(
                    "ALTER TABLE progress_day ADD COLUMN observedFeedDurationMillis INTEGER",
                )
            }
        }
    }
}
