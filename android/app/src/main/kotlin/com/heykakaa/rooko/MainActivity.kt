package com.heykakaa.rooko

import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.SystemClock
import android.provider.Settings
import androidx.core.splashscreen.SplashScreen.Companion.installSplashScreen
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.time.LocalDate
import java.util.UUID

class MainActivity : FlutterActivity() {
    private lateinit var trackingChannel: MethodChannel
    private val detectorVersionRegistry by lazy { DetectorVersionRegistry(applicationContext) }

    override fun onCreate(savedInstanceState: Bundle?) {
        val splashScreen = installSplashScreen()
        val splashStartedAtMillis = SystemClock.elapsedRealtime()
        splashScreen.setKeepOnScreenCondition {
            SystemClock.elapsedRealtime() - splashStartedAtMillis <
                SPLASH_SCREEN_MIN_DURATION_MILLIS
        }
        super.onCreate(savedInstanceState)
        detectorVersionRegistry.refreshAsync { registry ->
            SelectedAppAccessibilityService.updateRunningDetectorRegistry(registry)
        }
    }

    override fun onResume() {
        super.onResume()
        SelectedAppAccessibilityService.onHostActivityResumed()
        SelectedAppAccessibilityService.hideFloatingCounter()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        trackingChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            TRACKING_CHANNEL,
        )
        trackingChannel.setMethodCallHandler(::handleTrackingMethod)
    }

    private fun handleTrackingMethod(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "setSelectedApps" -> {
                val appIds = call.argument<List<String>>("appIds")
                    .orEmpty()
                    .filter { SupportedAppsNative.byId(it) != null }
                    .toSet()
                trackingPreferences().edit()
                    .putStringSet(
                        SelectedAppAccessibilityService.SELECTED_APP_IDS_KEY,
                        appIds,
                    )
                    .apply()
                SelectedAppAccessibilityService.updateRunningInstance(appIds)
                result.success(null)
            }

            "setTrackingConsentAcknowledged" -> {
                val acknowledged = call.argument<Boolean>("acknowledged") ?: false
                trackingPreferences().edit().apply {
                    putBoolean(
                        SelectedAppAccessibilityService.CONSENT_ACKNOWLEDGED_KEY,
                        acknowledged,
                    )
                    if (!acknowledged) putBoolean(
                        SelectedAppAccessibilityService.BUBBLE_ENABLED_KEY,
                        false,
                    )
                }.apply()
                val selectedAppIds = trackingPreferences().getStringSet(
                    SelectedAppAccessibilityService.SELECTED_APP_IDS_KEY,
                    emptySet(),
                ).orEmpty()
                SelectedAppAccessibilityService.updateRunningInstance(selectedAppIds)
                result.success(null)
            }

            "getTrackingSnapshot" -> {
                val appIds = call.argument<List<String>>("appIds")
                    ?.toSet()
                    ?: trackingPreferences().getStringSet(
                        SelectedAppAccessibilityService.SELECTED_APP_IDS_KEY,
                        emptySet(),
                    ).orEmpty()
                val cachedRegistry = detectorVersionRegistry.readVerified()
                val installedVersions = SupportedAppsNative.all.mapNotNull { app ->
                    installedVersion(app.packageName)?.let { app.packageName to it }
                }
                val cacheNeedsVersionLookup = installedVersions.any { (packageName, versionName) ->
                    cachedRegistry?.entryFor(packageName, versionName) == null
                }
                if (cacheNeedsVersionLookup) {
                    detectorVersionRegistry.refreshAsync { registry ->
                        SelectedAppAccessibilityService.updateRunningDetectorRegistry(registry)
                        runOnUiThread {
                            result.success(buildTrackingSnapshot(appIds, registry))
                        }
                    }
                } else {
                    result.success(buildTrackingSnapshot(appIds, cachedRegistry))
                    detectorVersionRegistry.refreshAsync { registry ->
                        SelectedAppAccessibilityService.updateRunningDetectorRegistry(registry)
                    }
                }
            }

            "queryProgress" -> queryProgress(call, result)
            "addCorrection" -> addCorrection(call, result)
            "undoCorrection" -> undoCorrection(call, result)

            "setBubbleEnabled" -> {
                val enabled = call.argument<Boolean>("enabled") ?: false
                if (enabled && !trackingPreferences().getBoolean(
                        SelectedAppAccessibilityService.CONSENT_ACKNOWLEDGED_KEY, false,
                    )
                ) {
                    result.error("CONSENT_REQUIRED", "Set up tracking before the counter.", null)
                    return
                }
                trackingPreferences().edit()
                    .putBoolean(SelectedAppAccessibilityService.BUBBLE_ENABLED_KEY, enabled)
                    .apply()
                val selected = trackingPreferences().getStringSet(
                    SelectedAppAccessibilityService.SELECTED_APP_IDS_KEY, emptySet(),
                ).orEmpty()
                SelectedAppAccessibilityService.updateRunningInstance(selected)
                result.success(null)
            }

            "openOverlaySettings" -> {
                result.success(openOverlaySettings())
            }

            "openAccessibilitySettings" -> {
                result.success(openAccessibilitySettings())
            }

            "openSupportedApp" -> {
                result.success(openSupportedApp(call.argument<String>("appId")))
            }

            "openSupportedAppSettings" -> {
                result.success(openSupportedAppSettings(call.argument<String>("appId")))
            }

            "openSupportEmail" -> {
                result.success(openSupportEmail(call.argument<String>("kind")))
            }

            else -> result.notImplemented()
        }
    }

    private fun queryProgress(call: MethodCall, result: MethodChannel.Result) {
        val startDate = call.argument<String>("startDate")
        val endDate = call.argument<String>("endDate")
        if (startDate == null || endDate == null) {
            result.error("INVALID_ARGUMENT", "A start and end date are required.", null)
            return
        }
        runCatching {
            ProgressRepositoryProvider.get(this).queryProgress(startDate, endDate)
        }.onSuccess { days ->
            result.success(
                mapOf(
                    "schemaVersion" to PROGRESS_SCHEMA_VERSION,
                    "checkedAtMillis" to System.currentTimeMillis(),
                    "days" to days.map(::progressDayMap),
                ),
            )
        }.onFailure { error ->
            val code = if (error is IllegalArgumentException) "INVALID_ARGUMENT"
                else "PROGRESS_UNAVAILABLE"
            result.error(code, error.message ?: "Progress is unavailable.", null)
        }
    }

    private fun addCorrection(call: MethodCall, result: MethodChannel.Result) {
        val localDate = call.argument<String>("localDate")
        val appId = call.argument<String>("appId")
        val delta = (call.argument<Any>("delta") as? Number)?.toInt()
        if (localDate == null || appId == null || delta == null) {
            result.error("INVALID_ARGUMENT", "Date, app, and change are required.", null)
            return
        }
        runCatching {
            ProgressRepositoryProvider.get(this).addCorrection(
                localDate = localDate,
                appId = appId,
                delta = delta,
                reason = call.argument("reason"),
                createdAtMillis = System.currentTimeMillis(),
            )
        }.onSuccess { correction ->
            result.success(
                mapOf(
                    "schemaVersion" to PROGRESS_SCHEMA_VERSION,
                    "correction" to correctionMap(correction),
                ),
            )
        }.onFailure { error ->
            val code = if (error is InvalidCorrectionException) "INVALID_CORRECTION"
                else "INVALID_ARGUMENT"
            result.error(code, error.message ?: "Correction could not be saved.", null)
        }
    }

    private fun undoCorrection(call: MethodCall, result: MethodChannel.Result) {
        val correctionId = call.argument<String>("correctionId")
        if (correctionId.isNullOrBlank()) {
            result.error("INVALID_ARGUMENT", "A correction id is required.", null)
            return
        }
        runCatching {
            ProgressRepositoryProvider.get(this).undoCorrection(
                id = correctionId,
                createdAtMillis = System.currentTimeMillis(),
            )
        }.onSuccess { correction ->
            result.success(
                mapOf(
                    "schemaVersion" to PROGRESS_SCHEMA_VERSION,
                    "correction" to correctionMap(correction),
                ),
            )
        }.onFailure { error ->
            val code = if (error is InvalidCorrectionException) "INVALID_CORRECTION"
                else "PROGRESS_UNAVAILABLE"
            result.error(code, error.message ?: "Correction could not be undone.", null)
        }
    }

    private fun openAccessibilitySettings(): Boolean {
        val consentAcknowledged = trackingPreferences().getBoolean(
            SelectedAppAccessibilityService.CONSENT_ACKNOWLEDGED_KEY,
            false,
        )
        if (!TrackingConsentGate.canOpenAccessibilitySettings(consentAcknowledged)) {
            return false
        }
        return try {
            startActivity(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS))
            true
        } catch (_: Exception) {
            false
        }
    }

    private fun openOverlaySettings(): Boolean {
        val optedIn = trackingPreferences().getBoolean(
            SelectedAppAccessibilityService.BUBBLE_ENABLED_KEY, false,
        )
        if (!optedIn) return false
        return try {
            startActivity(Intent(
                Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                Uri.parse("package:$packageName"),
            ))
            true
        } catch (_: Exception) {
            false
        }
    }

    private fun openSupportedApp(appId: String?): Boolean {
        val targetPackage = when (appId) {
            "instagram" -> "com.instagram.android"
            "youtube" -> "com.google.android.youtube"
            else -> return false
        }
        return try {
            val intent = packageManager.getLaunchIntentForPackage(targetPackage) ?: return false
            startActivity(intent)
            true
        } catch (_: Exception) {
            false
        }
    }

    private fun openSupportedAppSettings(appId: String?): Boolean {
        val targetPackage = when (appId) {
            "instagram" -> "com.instagram.android"
            "youtube" -> "com.google.android.youtube"
            else -> return false
        }
        if (installedVersion(targetPackage) == null) return false
        return try {
            startActivity(
                Intent(
                    Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                    Uri.parse("package:$targetPackage"),
                ),
            )
            true
        } catch (_: Exception) {
            false
        }
    }

    private fun openSupportEmail(kind: String?): Boolean {
        val subject = when (kind) {
            "feature_request" -> "Rooko Feature Request"
            "support" -> "Rooko Support"
            else -> return false
        }
        return try {
            val intent = Intent(Intent.ACTION_SENDTO).apply {
                data = Uri.fromParts("mailto", SUPPORT_EMAIL, null)
                putExtra(Intent.EXTRA_SUBJECT, subject)
            }
            startActivity(intent)
            true
        } catch (_: Exception) {
            false
        }
    }

    private fun buildTrackingSnapshot(
        selectedAppIds: Set<String>,
        registry: VerifiedDetectorRegistry? = detectorVersionRegistry.readVerified(),
    ): Map<String, Any?> {
        val checkedAt = System.currentTimeMillis()
        val localDate = LocalDate.now().toString()
        val serviceEnabled = SelectedAppAccessibilityService.isEnabled(this)
        val serviceOperational = SelectedAppAccessibilityService.isOperational(this)
        if (selectedAppIds.isNotEmpty() && serviceEnabled && !serviceOperational) {
            SelectedAppAccessibilityService.recordCoverageGap(this, localDate)
        }
        val serviceInterruptedToday = selectedAppIds.isNotEmpty() &&
            SelectedAppAccessibilityService.hasCoverageGapOn(this, localDate)
        val appIds = SupportedAppsNative.all.map { it.appId }.toSet()
        val progressRepository = ProgressRepositoryProvider.get(this)
        val countStore = roomCountStore()
        val counts = countStore.countsFor(localDate, appIds)
        val adjustedCounts = progressRepository.adjustedCountsFor(localDate, appIds)
        val lastDetectionAtMillis = countStore.lastDetectionAtMillis(localDate)
        val apps = SupportedAppsNative.all.map { app ->
            val versionName = installedVersion(app.packageName)
            val profile = versionName?.let {
                DetectorProfiles.forVersion(app.packageName, it, registry)
            }
            val dailyCount = counts[app.appId] ?: DailyAppCount(0, 0)
            val adjustedDailyCount = adjustedCounts[app.appId] ?: DailyAppCount(0, 0)
            mapOf(
                "appId" to app.appId,
                "packageName" to app.packageName,
                "selected" to (app.appId in selectedAppIds),
                "installed" to (versionName != null),
                "versionName" to versionName,
                "profileAvailable" to (profile != null),
                "debugProfileAvailable" to (versionName != null &&
                    DebugTextProfiles.forVersion(app.packageName, versionName) != null),
                "confidence" to profile?.confidence?.name?.lowercase(),
                "confirmedCount" to dailyCount.confirmed,
                "adjustedConfirmedCount" to adjustedDailyCount.confirmed,
                "estimatedCount" to dailyCount.estimated,
            )
        }
        return mapOf(
            "serviceEnabled" to serviceEnabled,
            "serviceOperational" to serviceOperational,
            "serviceInterruptedToday" to serviceInterruptedToday,
            "consentAcknowledged" to trackingPreferences().getBoolean(
                SelectedAppAccessibilityService.CONSENT_ACKNOWLEDGED_KEY,
                false,
            ),
            "bubbleEnabled" to trackingPreferences().getBoolean(
                SelectedAppAccessibilityService.BUBBLE_ENABLED_KEY, false,
            ),
            "debugCountingEnabled" to trackingPreferences().getBoolean(
                SelectedAppAccessibilityService.CONSENT_ACKNOWLEDGED_KEY, false,
            ),
            "overlayPermissionGranted" to Settings.canDrawOverlays(this),
            "checkedAtMillis" to checkedAt,
            "appVersion" to BuildConfig.VERSION_NAME,
            "androidVersion" to Build.VERSION.RELEASE,
            "androidApiLevel" to Build.VERSION.SDK_INT,
            "lastDetectionAtMillis" to (
                lastDetectionAtMillis.takeIf { it >= 0L } ?: 0L
            ),
            "lastValidatedFeedExitAtMillis" to trackingPreferences().getLong(
                SelectedAppAccessibilityService.LAST_VALIDATED_FEED_EXIT_AT_MILLIS_KEY,
                0L,
            ),
            "localDate" to localDate,
            "apps" to apps,
        )
    }

    private fun installedVersion(packageName: String): String? = try {
        @Suppress("DEPRECATION")
        packageManager.getPackageInfo(packageName, 0).versionName
    } catch (_: Exception) {
        null
    }

    private fun roomCountStore(): RoomCountStore {
        val preferences = trackingPreferences()
        val salt = preferences.getString(ITEM_IDENTITY_SALT_KEY, null)
            ?: UUID.randomUUID().toString().also {
                preferences.edit().putString(ITEM_IDENTITY_SALT_KEY, it).apply()
            }
        return RoomCountStore(ProgressRepositoryProvider.get(this), salt)
    }

    private fun progressDayMap(day: ProgressDay): Map<String, Any?> = mapOf(
        "localDate" to day.localDate,
        "timeZoneId" to day.timeZoneId,
        "offsetSeconds" to day.offsetSeconds,
        "coverage" to day.coverage.name.lowercase(),
        "coverageReason" to day.coverageReason,
        "lastDetectionAtMillis" to day.lastDetectionAtMillis,
        "observedFeedDurationMillis" to day.observedFeedDurationMillis,
        "hourlyCounts" to day.hourlyCounts,
        "countedTimes" to day.countedTimes.map { time ->
            mapOf(
                "appId" to time.appId,
                "wallClockMillis" to time.wallClockMillis,
                "offsetSeconds" to time.offsetSeconds,
            )
        },
        "hasHourlyBreakdown" to day.hasHourlyBreakdown,
            "isPersonalBest" to day.isPersonalBest,
        "apps" to day.apps.map { app ->
            mapOf(
                "appId" to app.appId,
                "confirmedCount" to app.confirmedCount,
                "estimatedCount" to app.estimatedCount,
                "correctionDelta" to app.correctionDelta,
                "adjustedConfirmedCount" to app.adjustedConfirmedCount,
                "correctionCount" to app.correctionCount,
                "pendingUndoCorrectionId" to app.pendingUndoCorrectionId,
            )
        },
    )

    private fun correctionMap(correction: StoredCorrection): Map<String, Any?> = mapOf(
        "id" to correction.id,
        "localDate" to correction.localDate,
        "appId" to correction.appId,
        "delta" to correction.delta,
        "reason" to correction.reason,
        "createdAtMillis" to correction.createdAtMillis,
        "reversesCorrectionId" to correction.reversesCorrectionId,
    )

    private fun trackingPreferences(): SharedPreferences =
        getSharedPreferences(
            SelectedAppAccessibilityService.TRACKING_PREFERENCES,
            Context.MODE_PRIVATE,
        )

    private companion object {
        private const val SPLASH_SCREEN_MIN_DURATION_MILLIS = 1_500L
        const val TRACKING_CHANNEL = "com.heykakaa.rooko/tracking_v1"
        const val ITEM_IDENTITY_SALT_KEY = "item_identity_salt"
        const val PROGRESS_SCHEMA_VERSION = 1
        private const val SUPPORT_EMAIL = "omkarkubal@protonmail.com"
    }
}
