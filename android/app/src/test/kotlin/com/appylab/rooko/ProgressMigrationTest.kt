package com.appylab.rooko

import android.content.Context
import android.database.sqlite.SQLiteDatabase
import androidx.room.Room
import androidx.test.core.app.ApplicationProvider
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35])
class ProgressMigrationTest {
    @Test
    fun `version one history migrates into progress without verifying legacy days`() {
        val context = ApplicationProvider.getApplicationContext<Context>()
        val databaseName = "history-v1-migration-test.db"
        context.deleteDatabase(databaseName)
        val file = context.getDatabasePath(databaseName)
        file.parentFile?.mkdirs()

        @Suppress("DEPRECATION")
        SQLiteDatabase.openOrCreateDatabase(file, null).use { oldDatabase ->
            oldDatabase.execSQL(
                """
                CREATE TABLE history_day (
                    localDate TEXT NOT NULL PRIMARY KEY,
                    timeZoneId TEXT,
                    offsetSeconds INTEGER,
                    coverage TEXT NOT NULL,
                    coverageReason TEXT,
                    lastDetectionAtMillis INTEGER NOT NULL
                )
                """.trimIndent(),
            )
            oldDatabase.execSQL(
                """
                CREATE TABLE daily_app_aggregate (
                    localDate TEXT NOT NULL,
                    appId TEXT NOT NULL,
                    confirmedCount INTEGER NOT NULL,
                    estimatedCount INTEGER NOT NULL,
                    PRIMARY KEY(localDate, appId)
                )
                """.trimIndent(),
            )
            oldDatabase.execSQL(
                """
                CREATE TABLE count_correction (
                    id TEXT NOT NULL PRIMARY KEY,
                    localDate TEXT NOT NULL,
                    appId TEXT NOT NULL,
                    delta INTEGER NOT NULL,
                    reason TEXT,
                    createdAtMillis INTEGER NOT NULL,
                    reversesCorrectionId TEXT
                )
                """.trimIndent(),
            )
            oldDatabase.execSQL(
                "CREATE INDEX index_count_correction_localDate_appId " +
                    "ON count_correction(localDate, appId)",
            )
            oldDatabase.execSQL(
                "CREATE UNIQUE INDEX index_count_correction_reversesCorrectionId " +
                    "ON count_correction(reversesCorrectionId)",
            )
            oldDatabase.execSQL(
                "CREATE TABLE database_metadata (`key` TEXT NOT NULL PRIMARY KEY, value TEXT NOT NULL)",
            )
            oldDatabase.execSQL(
                "CREATE TABLE room_master_table (id INTEGER PRIMARY KEY, identity_hash TEXT)",
            )
            oldDatabase.execSQL(
                "INSERT INTO room_master_table (id, identity_hash) VALUES " +
                    "(42, 'a238d00c18caaaf595e4aa135f37e3d7')",
            )
            oldDatabase.execSQL(
                "INSERT INTO history_day VALUES " +
                    "('2026-11-06', NULL, NULL, 'UNKNOWN', NULL, 1800000000000)",
            )
            oldDatabase.execSQL(
                "INSERT INTO daily_app_aggregate VALUES " +
                    "('2026-11-06', 'youtube', 3, 2)",
            )
            oldDatabase.version = 1
        }

        val migrated = Room.databaseBuilder(
            context,
            RookoDatabase::class.java,
            databaseName,
        )
            .addMigrations(
                RookoDatabase.MIGRATION_1_2,
                RookoDatabase.MIGRATION_2_3,
                RookoDatabase.MIGRATION_3_4,
                RookoDatabase.MIGRATION_4_5,
            )
            .allowMainThreadQueries()
            .build()
        try {
            val versionCursor = migrated.openHelper.writableDatabase.query("PRAGMA user_version")
            val version = versionCursor.use {
                assertTrue(it.moveToFirst())
                it.getInt(0)
            }
            val day = ProgressRepository(migrated).queryProgress(
                "2026-11-06",
                "2026-11-06",
            ).single()

            assertEquals(5, version)
            assertEquals(ProgressCoverage.UNKNOWN, day.coverage)
            assertEquals(false, day.hasHourlyBreakdown)
            assertTrue(day.countedTimes.isEmpty())
            assertEquals(
                5,
                day.apps.single().confirmedCount + day.apps.single().estimatedCount,
            )
            assertTrue(migrated.progressDao().verificationDays().isEmpty())
        } finally {
            migrated.close()
            context.deleteDatabase(databaseName)
        }
    }

    @Test
    fun `version two history file and rows migrate into progress`() {
        val context = ApplicationProvider.getApplicationContext<Context>()
        val oldName = "sync_scroll_history.db"
        val newName = "rooko_progress.db"
        context.deleteDatabase(oldName)
        context.deleteDatabase(newName)
        val oldFile = context.getDatabasePath(oldName)
        oldFile.parentFile?.mkdirs()

        @Suppress("DEPRECATION")
        SQLiteDatabase.openOrCreateDatabase(oldFile, null).use { oldDatabase ->
            oldDatabase.enableWriteAheadLogging()
            oldDatabase.execSQL(
                "CREATE TABLE history_day (localDate TEXT NOT NULL PRIMARY KEY, " +
                    "timeZoneId TEXT, offsetSeconds INTEGER, coverage TEXT NOT NULL, " +
                    "coverageReason TEXT, lastDetectionAtMillis INTEGER NOT NULL)",
            )
            oldDatabase.execSQL(
                "CREATE TABLE history_verification (localDate TEXT NOT NULL PRIMARY KEY, " +
                    "startedAtMillis INTEGER NOT NULL, lastCheckpointMillis INTEGER NOT NULL, " +
                    "timeZoneId TEXT NOT NULL, offsetSeconds INTEGER NOT NULL, " +
                    "selectedAppFingerprint TEXT NOT NULL, profileFingerprint TEXT NOT NULL, " +
                    "processInstanceId TEXT NOT NULL)",
            )
            oldDatabase.execSQL(
                "CREATE TABLE daily_app_aggregate (localDate TEXT NOT NULL, appId TEXT NOT NULL, " +
                    "confirmedCount INTEGER NOT NULL, estimatedCount INTEGER NOT NULL, " +
                    "PRIMARY KEY(localDate, appId))",
            )
            oldDatabase.execSQL(
                "CREATE TABLE count_correction (id TEXT NOT NULL PRIMARY KEY, " +
                    "localDate TEXT NOT NULL, appId TEXT NOT NULL, delta INTEGER NOT NULL, " +
                    "reason TEXT, createdAtMillis INTEGER NOT NULL, reversesCorrectionId TEXT)",
            )
            oldDatabase.execSQL(
                "CREATE INDEX index_count_correction_localDate_appId " +
                    "ON count_correction(localDate, appId)",
            )
            oldDatabase.execSQL(
                "CREATE UNIQUE INDEX index_count_correction_reversesCorrectionId " +
                    "ON count_correction(reversesCorrectionId)",
            )
            oldDatabase.execSQL(
                "CREATE TABLE database_metadata (`key` TEXT NOT NULL PRIMARY KEY, value TEXT NOT NULL)",
            )
            oldDatabase.execSQL(
                "CREATE TABLE room_master_table (id INTEGER PRIMARY KEY, identity_hash TEXT)",
            )
            oldDatabase.execSQL(
                "INSERT INTO room_master_table VALUES " +
                    "(42, 'fd0cf3dc6293a3e0eb03147e764c821b')",
            )
            oldDatabase.execSQL(
                "INSERT INTO history_day VALUES " +
                    "('2026-11-06', 'Asia/Kolkata', 19800, 'VERIFIED', NULL, 1800000000000)",
            )
            oldDatabase.execSQL(
                "INSERT INTO history_verification VALUES " +
                    "('2026-11-06', 1799990000000, 1800000000000, 'Asia/Kolkata', " +
                    "19800, 'apps', 'profiles', 'process')",
            )
            oldDatabase.execSQL(
                "INSERT INTO daily_app_aggregate VALUES ('2026-11-06', 'youtube', 3, 2)",
            )
            oldDatabase.version = 2
        }

        LegacyProgressDatabaseMover.prepare(context)
        assertTrue(context.getDatabasePath(oldName).exists())
        assertTrue(context.getDatabasePath(newName).exists())
        val migrated = Room.databaseBuilder(context, RookoDatabase::class.java, newName)
            .addMigrations(
                RookoDatabase.MIGRATION_1_2,
                RookoDatabase.MIGRATION_2_3,
                RookoDatabase.MIGRATION_3_4,
                RookoDatabase.MIGRATION_4_5,
            )
            .allowMainThreadQueries()
            .build()
        try {
            val day = ProgressRepository(migrated).queryProgress("2026-11-06", "2026-11-06").single()
            assertEquals(ProgressCoverage.VERIFIED, day.coverage)
            assertEquals(5, day.apps.single().confirmedCount + day.apps.single().estimatedCount)
            assertEquals(1, migrated.progressDao().verificationDays().size)
            val versionCursor = migrated.openHelper.writableDatabase.query("PRAGMA user_version")
            versionCursor.use {
                assertTrue(it.moveToFirst())
                assertEquals(5, it.getInt(0))
            }
            LegacyProgressDatabaseMover.prepare(context)
        } finally {
            migrated.close()
            context.deleteDatabase(newName)
            context.deleteDatabase(oldName)
        }
    }
}
