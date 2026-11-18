package com.appylab.rooko

import android.content.Context
import androidx.room.Room
import androidx.test.core.app.ApplicationProvider
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35])
class RoomCountStoreTest {
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
    fun acceptedDetectionWritesRoomAndDuplicateIdentityStaysProcessLocal() {
        val store = RoomCountStore(repository, installSalt = "test-salt")

        assertTrue(store.recordIfNew(
            appId = "instagram",
            itemIdentityHash = "transient-hash",
            elapsedRealtimeMillis = 1_000L,
            localDateKey = "2026-11-06",
            confidence = CountConfidence.CONFIRMED,
            wallClockMillis = 1_800_000_000_000L,
        ))
        assertFalse(store.recordIfNew(
            appId = "instagram",
            itemIdentityHash = "transient-hash",
            elapsedRealtimeMillis = 2_000L,
            localDateKey = "2026-11-06",
            confidence = CountConfidence.CONFIRMED,
            wallClockMillis = 1_800_000_001_000L,
        ))

        assertEquals(1, store.countsFor("2026-11-06", setOf("instagram"))
            .getValue("instagram").confirmed)
        assertEquals(1_800_000_000_000L, store.lastDetectionAtMillis("2026-11-06"))
        assertFalse(database.openHelper.writableDatabase.query(
            "SELECT COUNT(*) FROM database_metadata WHERE value LIKE '%transient-hash%'",
        ).use { it.moveToFirst() && it.getInt(0) > 0 })
    }
}
