package com.heykakaa.rooko

import android.content.ComponentName
import android.content.Context
import android.content.pm.ApplicationInfo
import android.content.pm.PackageInfo
import android.provider.Settings
import androidx.room.Room
import androidx.test.core.app.ApplicationProvider
import java.time.Instant
import java.time.LocalDate
import org.junit.After
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.Robolectric
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config
import org.robolectric.shadows.ShadowSettings

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35])
class FloatingCounterMidnightEligibilityTest {
    private val context = ApplicationProvider.getApplicationContext<Context>()
    private lateinit var database: RookoDatabase
    private lateinit var progress: ProgressRepository

    @Before
    fun setUp() {
        database = Room.inMemoryDatabaseBuilder(context, RookoDatabase::class.java)
            .allowMainThreadQueries()
            .build()
        progress = ProgressRepository(database)
        ShadowSettings.setCanDrawOverlays(true)
        Settings.Secure.putInt(context.contentResolver, Settings.Secure.ACCESSIBILITY_ENABLED, 1)
        Settings.Secure.putString(
            context.contentResolver,
            Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES,
            ComponentName(context, SelectedAppAccessibilityService::class.java).flattenToString(),
        )
    }

    @After
    fun tearDown() {
        database.close()
    }

    @Test
    fun sameDayCheckpointKeepsVisibleCounterWhenAccessibilityRootIsTemporarilyMissing() {
        val serviceController = Robolectric.buildService(SelectedAppAccessibilityService::class.java)
        val service = serviceController.create().get()
        val counter = FloatingCounterOverlay(service) {}
        try {
            prepareService(service, counter)
            counter.show(53)

            // A normal five-minute Progress checkpoint is not a feed-exit event.
            // Robolectric has no active root, as can also happen during a Reel swipe.
            invokePrivate(service, "refreshFloatingCounterForLocalDay", emptyArray(), emptyArray())

            assertTrue("same-day checkpoint must not hide a visible counter", isCounterShowing(counter))
        } finally {
            counter.hide()
            serviceController.destroy()
        }
    }

    @Test
    fun hiddenCounterDoesNotReturnAtMidnightAfterTheActiveRootBecomesUnavailable() {
        val serviceController = Robolectric.buildService(SelectedAppAccessibilityService::class.java)
        val service = serviceController.create().get()
        val counter = FloatingCounterOverlay(service) {}
        try {
            prepareService(service, counter)
            counter.show(0)
            assertTrue(isCounterShowing(counter))

            invokePrivate(
                service,
                "observeOutsideFeed",
                arrayOf(AppDetectorProfile::class.java, Boolean::class.javaPrimitiveType!!),
                arrayOf(youtubeProfile(), false),
            )
            assertFalse(isCounterShowing(counter))
            assertTrue(recognizedFeedAppIds(service).contains("youtube"))

            advanceCounterRolloverToYesterday(service)
            invokePrivate(service, "refreshFloatingCounterForLocalDay", emptyArray(), emptyArray())

            assertFalse("a missing root must not make midnight show the counter again", isCounterShowing(counter))
        } finally {
            counter.hide()
            serviceController.destroy()
        }
    }

    @Test
    fun revokedProfileDoesNotReturnAtMidnightAfterRegistryReplacementHidesTheCounter() {
        val serviceController = Robolectric.buildService(SelectedAppAccessibilityService::class.java)
        val service = serviceController.create().get()
        val counter = FloatingCounterOverlay(service) {}
        try {
            prepareService(service, counter)
            counter.show(0)

            invokePrivate(
                service,
                "replaceDetectorRegistry",
                arrayOf(VerifiedDetectorRegistry::class.java),
                arrayOf(unavailableRegistry()),
            )
            assertFalse(isCounterShowing(counter))
            assertTrue(recognizedFeedAppIds(service).contains("youtube"))

            invokePrivate(
                service,
                "updateFloatingCounter",
                arrayOf(AppDetectorProfile::class.java, Boolean::class.javaPrimitiveType!!),
                arrayOf(youtubeProfile(), true),
            )
            assertFalse("a profile removed from the current registry must not show the counter", isCounterShowing(counter))

            advanceCounterRolloverToYesterday(service)
            invokePrivate(service, "refreshFloatingCounterForLocalDay", emptyArray(), emptyArray())

            assertFalse("an unavailable profile must not make midnight show the counter again", isCounterShowing(counter))
        } finally {
            counter.hide()
            serviceController.destroy()
        }
    }

    private fun prepareService(service: SelectedAppAccessibilityService, counter: FloatingCounterOverlay) {
        shadowOf(context.packageManager).installPackage(
            PackageInfo().apply {
                packageName = YOUTUBE
                versionName = VERSION
                applicationInfo = ApplicationInfo().apply { packageName = YOUTUBE }
            },
        )
        service.getSharedPreferences(
            SelectedAppAccessibilityService.TRACKING_PREFERENCES,
            Context.MODE_PRIVATE,
        ).edit()
            .putBoolean(SelectedAppAccessibilityService.CONSENT_ACKNOWLEDGED_KEY, true)
            .putBoolean(SelectedAppAccessibilityService.BUBBLE_ENABLED_KEY, true)
            .putStringSet(SelectedAppAccessibilityService.SELECTED_APP_IDS_KEY, setOf("youtube"))
            .commit()
        val store = RoomCountStore(progress, installSalt = "midnight-counter-test")
        setField(service, "countStore", store)
        setField(service, "floatingCounter", counter)
        setField(service, "selectedAppIds", setOf("youtube"))
        setField(service, "recognizedFeedAppIds", mutableSetOf("youtube"))
        setField(service, "verifiedDetectorRegistry", validatedRegistry())
        setField(service, "instance", service)
        (getField(service, "serviceHealth") as AccessibilityServiceHealth).onServiceConnected()
    }

    private fun advanceCounterRolloverToYesterday(service: SelectedAppAccessibilityService) {
        val yesterday = LocalDate.now().minusDays(1)
        (getField(service, "counterDayRollover") as FloatingCounterDayRollover)
            .recordCountUpdate(yesterday)
    }

    private fun youtubeProfile() = AppDetectorProfile(
        appId = "youtube",
        packageName = "com.google.android.youtube",
        versionName = "21.45.82",
        feedMarkerViewIds = setOf("feed"),
        transitionViewIds = setOf("pager"),
        identityStrategy = ItemIdentityStrategy.STABLE_OPAQUE_ACCESSIBILITY_TOKEN,
        confidence = CountConfidence.CONFIRMED,
        profileId = "youtube.shorts.v1",
    )

    private fun unavailableRegistry() = VerifiedDetectorRegistry(
        sequence = 2L,
        issuedAtEpochSeconds = Instant.now().epochSecond,
        expiresAtEpochSeconds = Instant.now().plusSeconds(86_400L).epochSecond,
        entries = emptyList(),
        payloadDigest = "unavailable-profile-registry",
    )

    private fun validatedRegistry() = VerifiedDetectorRegistry(
        sequence = 1L,
        schemaVersion = 2,
        issuedAtEpochSeconds = Instant.now().epochSecond,
        expiresAtEpochSeconds = Instant.now().plusSeconds(86_400L).epochSecond,
        entries = listOf(
            DetectorRegistryEntry(
                packageName = YOUTUBE,
                versionName = VERSION,
                status = DetectorRegistryEntryStatus.SUPPORTED,
                profileId = PROFILE_ID,
                sourceUrl = "https://archive.example/youtube/$VERSION",
                validation = DetectorVersionValidation(
                    reportId = "midnight-test",
                    transitionCases = 200,
                    stationaryCases = 100,
                    deviceFamilies = 3,
                    precisionPercent = 98.0,
                    recallPercent = 90.0,
                    stationaryRepeats = 0,
                ),
            ),
        ),
        profiles = mapOf(
            PROFILE_ID to DetectorRegistryProfile(
                profileId = PROFILE_ID,
                packageName = YOUTUBE,
                strategyId = "opaque-id-v1",
                feedMarkerViewIds = setOf("feed"),
                transitionViewIds = setOf("pager"),
                identityStrategy = ItemIdentityStrategy.STABLE_OPAQUE_ACCESSIBILITY_TOKEN,
                identityNodeViewId = null,
            ),
        ),
        payloadDigest = "validated-midnight-profile",
    )

    private fun isCounterShowing(counter: FloatingCounterOverlay): Boolean =
        getField(counter, "bubble") != null

    private fun recognizedFeedAppIds(service: SelectedAppAccessibilityService): Set<String> =
        @Suppress("UNCHECKED_CAST")
        (getField(service, "recognizedFeedAppIds") as Set<String>)

    private fun getField(target: Any, name: String): Any? =
        target.javaClass.getDeclaredField(name).run {
            isAccessible = true
            get(target)
        }

    private fun setField(target: Any, name: String, value: Any) {
        target.javaClass.getDeclaredField(name).apply {
            isAccessible = true
            set(target, value)
        }
    }

    private fun invokePrivate(
        target: Any,
        name: String,
        parameterTypes: Array<Class<*>>,
        arguments: Array<Any>,
    ) {
        target.javaClass.getDeclaredMethod(name, *parameterTypes).apply {
            isAccessible = true
            invoke(target, *arguments)
        }
    }

    private companion object {
        const val YOUTUBE = "com.google.android.youtube"
        const val VERSION = "21.45.82"
        const val PROFILE_ID = "youtube.shorts.v1"
    }
}
