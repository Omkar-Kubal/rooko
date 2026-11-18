package com.appylab.rooko

import android.content.Context
import androidx.room.Room
import androidx.test.core.app.ApplicationProvider
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.Robolectric
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35])
class DetectorRegistryRevocationTest {
    private val context = ApplicationProvider.getApplicationContext<Context>()
    private lateinit var database: RookoDatabase
    private lateinit var progress: ProgressRepository

    @Before
    fun setUp() {
        database = Room.inMemoryDatabaseBuilder(context, RookoDatabase::class.java)
            .allowMainThreadQueries()
            .build()
        progress = ProgressRepository(database)
    }

    @After
    fun tearDown() {
        database.close()
    }

    @Test
    fun acceptedDisableUpdateClearsPendingCandidateBeforeItCanRecord() {
        val profile = AppDetectorProfile(
            appId = "youtube",
            packageName = YOUTUBE,
            versionName = VERSION,
            feedMarkerViewIds = setOf("feed"),
            transitionViewIds = setOf("pager"),
            identityStrategy = ItemIdentityStrategy.STABLE_OPAQUE_ACCESSIBILITY_TOKEN,
            confidence = CountConfidence.CONFIRMED,
            profileId = PROFILE_ID,
        )
        val store = RoomCountStore(progress, installSalt = "registry-revocation-test")
        val detector = ReelDetector(listOf(profile), store).apply {
            setSelectedApps(setOf("youtube"))
        }
        assertEquals(
            DetectionOutcome.CandidateStarted,
            detector.observe(observation(profile, elapsedMillis = 1_000L)),
        )

        val serviceController = Robolectric.buildService(SelectedAppAccessibilityService::class.java)
        val service = serviceController.create().get()
        try {
            service.getSharedPreferences(
                SelectedAppAccessibilityService.TRACKING_PREFERENCES,
                Context.MODE_PRIVATE,
            ).edit()
                .putBoolean(SelectedAppAccessibilityService.CONSENT_ACKNOWLEDGED_KEY, true)
                .putStringSet(SelectedAppAccessibilityService.SELECTED_APP_IDS_KEY, setOf("youtube"))
                .commit()

            setField(service, "countStore", store)
            setField(service, "detector", detector)
            setField(service, "verifiedDetectorRegistry", registry(sequence = 1L, disabled = false))
            setField(service, "selectedAppIds", setOf("youtube"))
            @Suppress("UNCHECKED_CAST")
            val activeItems = service.javaClass.getDeclaredField("activeItems").run {
                isAccessible = true
                get(service) as MutableMap<String, Any>
            }
            activeItems["youtube"] = Any()

            service.javaClass.getDeclaredMethod(
                "replaceDetectorRegistry",
                VerifiedDetectorRegistry::class.java,
            ).apply {
                isAccessible = true
                invoke(service, registry(sequence = 2L, disabled = true))
            }

            assertEquals(
                DetectionOutcome.CandidateStarted,
                detector.observe(observation(profile, elapsedMillis = 2_500L)),
            )
            assertEquals(
                0,
                progress.countsFor(DATE, setOf("youtube")).values.sumOf(DailyAppCount::countedCount),
            )
        } finally {
            serviceController.destroy()
        }
    }

    private fun observation(profile: AppDetectorProfile, elapsedMillis: Long) = ReelObservation(
        packageName = profile.packageName,
        versionName = profile.versionName,
        isFeedVisible = true,
        itemIdentity = ItemIdentity("opaque-item-hash", profile.identityStrategy),
        feedEntryObserved = elapsedMillis == 1_000L,
        identityRevalidatedAtCurrentRoot = true,
        elapsedRealtimeMillis = elapsedMillis,
        wallClockMillis = 1_800_000_000_000L + elapsedMillis,
        localDateKey = DATE,
    )

    private fun registry(sequence: Long, disabled: Boolean) = VerifiedDetectorRegistry(
        sequence = sequence,
        issuedAtEpochSeconds = 1_800_000_000L,
        expiresAtEpochSeconds = 1_800_000_000L + 86_400L,
        entries = listOf(
            DetectorRegistryEntry(
                packageName = YOUTUBE,
                versionName = VERSION,
                status = if (disabled) DetectorRegistryEntryStatus.DISABLED
                else DetectorRegistryEntryStatus.SUPPORTED,
                profileId = PROFILE_ID,
                sourceUrl = "https://archive.example/youtube/$VERSION",
            ),
        ),
        payloadDigest = "registry-sequence-$sequence",
    )

    private fun setField(target: Any, name: String, value: Any) {
        target.javaClass.getDeclaredField(name).apply {
            isAccessible = true
            set(target, value)
        }
    }

    private companion object {
        const val YOUTUBE = "com.google.android.youtube"
        const val VERSION = "21.45.82"
        const val PROFILE_ID = "youtube.shorts.v1"
        const val DATE = "2026-11-12"
    }
}
