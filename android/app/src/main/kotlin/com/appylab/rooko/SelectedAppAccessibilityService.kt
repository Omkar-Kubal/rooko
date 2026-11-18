package com.appylab.rooko

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.AccessibilityServiceInfo
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.SharedPreferences
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import android.os.SystemClock
import android.provider.Settings
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import java.security.MessageDigest
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.util.ArrayDeque
import java.util.UUID

/** Confirms selected-app exposures only when the current root revalidates item identity. */
class SelectedAppAccessibilityService : AccessibilityService() {
    private data class ActiveItem(
        val profile: AppDetectorProfile,
        val index: Int,
        val identityHash: String,
    )

    private data class ProbeSnapshot(
        val viewIds: Set<String>,
        val nodeFeatures: List<StructuralNodeFeature>,
    )

    private data class CurrentRootSnapshot(
        val viewIds: Set<String>,
        val itemIdentityHash: String?,
    )

    private data class FeedTimeTarget(
        val appId: String,
        val packageName: String,
        val versionName: String,
        val feedMarkerIds: Set<String>,
        val estimated: Boolean,
    )

    private val handler = Handler(Looper.getMainLooper())
    private val serviceHealth = AccessibilityServiceHealth()
    private val activeItems = mutableMapOf<String, ActiveItem>()
    private val recognizedFeedAppIds = mutableSetOf<String>()
    private val counterDayRollover = FloatingCounterDayRollover(LocalDate.now())
    private val feedFingerprinters = mutableMapOf<String, FeedItemFingerprinter>()
    private val observedFeedTimeTracker = ObservedFeedTimeTracker()
    private val confirmationChecks = mutableMapOf<String, Runnable>()
    private val debugChecks = mutableMapOf<String, Runnable>()
    private val debugRetryStartedAt = mutableMapOf<String, Long>()
    private var uniqueIdRelationTracker: UniqueIdRelationTracker? = null
    private var alternativeIdentityRelationProbe: AlternativeIdentityRelationProbe? = null
    private var selectedAppIds: Set<String> = emptySet()
    private var observedSelectedProfileFingerprint: String? = null
    private var profileCoverageInvalidatedDate: LocalDate? = null
    private var consentAcknowledged = false
    private var detector: ReelDetector? = null
    private var debugCounter: DebugEventEstimateCounter? = null
    private var debugHasher: DebugTextKeyHasher? = null
    private lateinit var detectorVersionRegistry: DetectorVersionRegistry
    private var verifiedDetectorRegistry: VerifiedDetectorRegistry? = null
    private var countStore: RoomCountStore? = null
    private var floatingCounter: FloatingCounterOverlay? = null
    private var itemIdentityHasher: AppScopedIdentityHasher? = null
    private var lastContentChangeProcessedAt = 0L
    private var identityRelationCaptureWasActive = false
    private var selectedAppsInitialized = false
    private var identityRelationPurgeRunnable: Runnable? = null
    private var observedFeedTimeTarget: FeedTimeTarget? = null
    private var screenOffResumeTarget: FeedTimeTarget? = null
    private var observedFeedHeartbeatScheduled = false
    private var screenStateReceiverRegistered = false
    private val screenStateReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            when (intent?.action) {
                Intent.ACTION_SCREEN_OFF -> {
                    val target = observedFeedTimeTarget ?: return
                    stopObservedFeedTime()
                    screenOffResumeTarget = target
                }
                Intent.ACTION_SCREEN_ON -> {
                    val target = screenOffResumeTarget ?: return
                    screenOffResumeTarget = null
                    handler.postDelayed(
                        { resumeObservedFeedTime(target) },
                        SCREEN_ON_RECHECK_DELAY_MILLIS,
                    )
                }
            }
        }
    }
    private val detectorRegistryRefreshRunnable = object : Runnable {
        override fun run() {
            if (instance !== this@SelectedAppAccessibilityService) return
            detectorVersionRegistry.refreshAsync { registry ->
                handler.post {
                    if (instance === this@SelectedAppAccessibilityService) {
                        replaceDetectorRegistry(registry)
                    }
                }
            }
            handler.postDelayed(this, REGISTRY_REFRESH_INTERVAL_MILLIS)
        }
    }
    private val dayVerificationRunnable = object : Runnable {
        override fun run() {
            checkpointDayVerification()
            refreshFloatingCounterForLocalDay()
            scheduleDayVerificationCheckpoint()
        }
    }
    private val observedFeedHeartbeatRunnable = object : Runnable {
        override fun run() {
            observedFeedHeartbeatScheduled = false
            if (instance !== this@SelectedAppAccessibilityService) return
            checkpointObservedFeedTime()
            scheduleObservedFeedHeartbeat()
        }
    }

    override fun onServiceConnected() {
        super.onServiceConnected()
        instance = this
        serviceHealth.onServiceConnected()
        registerScreenStateReceiver()
        val preferences = trackingPreferences()
        val installSalt = preferences.getString(ITEM_IDENTITY_SALT_KEY, null)
            ?: UUID.randomUUID().toString().also {
                preferences.edit().putString(ITEM_IDENTITY_SALT_KEY, it).apply()
            }
        val backend = SharedPreferencesBackend(preferences)
        countStore = RoomCountStore(
            ProgressRepositoryProvider.get(this),
            installSalt = installSalt,
        )
        floatingCounter = FloatingCounterOverlay(this) {
            trackingPreferences().edit().putBoolean(BUBBLE_ENABLED_KEY, false).apply()
        }
        itemIdentityHasher = AppScopedIdentityHasher(backend)
        detectorVersionRegistry = DetectorVersionRegistry(this)
        verifiedDetectorRegistry = detectorVersionRegistry.readVerified()
        detector = ReelDetector(DetectorProfiles.all(verifiedDetectorRegistry), countStore!!)
        debugCounter = DebugEventEstimateCounter(countStore!!)
        debugHasher = DebugTextKeyHasher()
        consentAcknowledged = preferences.getBoolean(CONSENT_ACKNOWLEDGED_KEY, false)
        updateSelectedAppIds(
            preferences.getStringSet(SELECTED_APP_IDS_KEY, emptySet()) ?: emptySet(),
        )
        seedVisibleEstimateOnConnect()
        observedSelectedProfileFingerprint = profileFingerprint(
            selectedProfiles(selectedAppIds, verifiedDetectorRegistry),
        )
        counterDayRollover.recordCountUpdate(LocalDate.now())
        detectorVersionRegistry.refreshAsync { registry ->
            handler.post {
                if (instance === this) replaceDetectorRegistry(registry)
            }
        }
        handler.removeCallbacks(detectorRegistryRefreshRunnable)
        handler.postDelayed(detectorRegistryRefreshRunnable, REGISTRY_REFRESH_INTERVAL_MILLIS)
        scheduleDayVerificationCheckpoint()
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null) return
        serviceHealth.onAccessibilityEventReceived()
        val packageName = event.packageName?.toString()
        // The application overlay emits events under our own package. The
        // Activity hides it in onResume; its own view events must not close it.
        if (packageName == this.packageName) return
        if (event.eventType == AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) {
            if (observedFeedTimeTarget?.packageName != packageName) {
                stopObservedFeedTime()
            }
            if (
                recognizedFeedAppIds.any { appId ->
                    SupportedAppsNative.byId(appId)?.packageName != packageName
                }
            ) {
                recognizedFeedAppIds.toList()
                    .filter { appId -> SupportedAppsNative.byId(appId)?.packageName != packageName }
                    .forEach(::reportValidatedFeedExit)
            }
            if (packageName !in SupportedAppsNative.all.map { it.packageName }) {
                floatingCounter?.hide()
            }
            activeItems.values.toList()
                .filter {
                    CandidateDeadlineGuard.foreignWindowReplacedCandidate(
                        it.profile.packageName, packageName,
                    )
                }
                .forEach {
                    clearActiveItem(it.profile.appId)
                    detector?.clearCandidate(it.profile.appId)
                }
        }
        if (packageName == null) return
        val definition = SupportedAppsNative.all.firstOrNull {
            it.packageName == packageName && it.appId in selectedAppIds
        } ?: run {
            floatingCounter?.hide()
            if (event.eventType == AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) {
                stopObservedFeedTime()
            }
            return
        }
        val versionName = installedVersion(packageName)
        val profile = versionName?.let {
            DetectorProfiles.forVersion(packageName, it, verifiedDetectorRegistry)
        }
        val debugProfile = if (profile == null && estimatedCountingEnabled()) {
            versionName?.let { DebugTextProfiles.forVersion(packageName, it) }
        } else null
        observeSelectedProfileCoverage()

        val probeConsentAcknowledged = trackingPreferences().getBoolean(
            CONSENT_ACKNOWLEDGED_KEY,
            false,
        )
        val structuralProbeActive = versionName != null &&
            probeConsentAcknowledged && DetectorStructuralProbe.isEnabled(this)
        val identityRelationCaptureActive = structuralProbeActive &&
            DetectorStructuralProbe.isIdentityRelationCaptureEnabled(this)
        if (identityRelationCaptureWasActive && !identityRelationCaptureActive) {
            clearUniqueIdRelationState()
        }
        if (identityRelationCaptureActive) {
            identityRelationCaptureWasActive = true
            scheduleUniqueIdRelationPurge()
        }

        if (structuralProbeActive) {
            val source = event.source
            val sourceId = StructuralProbeFormatter.resourceNameFor(
                source?.viewIdResourceName,
                packageName,
            )
            source?.recycle()
            val probeElapsedRealtimeMillis = SystemClock.elapsedRealtime()
            val probeRoot = rootInActiveWindow
            val probeSnapshot = if (probeRoot?.packageName?.toString() == packageName) {
                collectProbeSnapshot(
                    root = probeRoot,
                    resourcePackage = packageName,
                    appId = definition.appId,
                    versionName = versionName!!,
                    captureIdentityRelations = identityRelationCaptureActive,
                    elapsedRealtimeMillis = probeElapsedRealtimeMillis,
                )
            } else {
                probeRoot?.recycle()
                ProbeSnapshot(emptySet(), emptyList())
            }
            DetectorStructuralProbe.record(
                this,
                StructuralProbeFormatter.format(
                    appId = definition.appId,
                    versionName = versionName,
                    eventType = event.eventType,
                    fromIndex = event.fromIndex,
                    toIndex = event.toIndex,
                    sourceId = sourceId,
                    viewIds = probeSnapshot.viewIds,
                    nodeFeatures = probeSnapshot.nodeFeatures,
                    elapsedRealtimeMillis = probeElapsedRealtimeMillis,
                ),
            )
        }

        if (profile == null) {
            if (debugProfile != null) {
                scanDebugEstimate(debugProfile)
                return
            }
            stopObservedFeedTime(definition.appId)
            floatingCounter?.hide()
            recognizedFeedAppIds.remove(definition.appId)
            clearActiveItem(definition.appId)
            detector?.clearCandidate(definition.appId)
            return
        }

        if (
            event.eventType == AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED &&
            !allowContentChangeAt(SystemClock.elapsedRealtime())
        ) {
            return
        }

        val source = event.source
        val sourceId = source?.viewIdResourceName?.substringAfter('/')
        source?.recycle()

        val root = rootInActiveWindow
        if (root == null) {
            observeOutsideFeed(profile, validatedFeedExit = false)
            return
        }
        if (root.packageName?.toString() != packageName) {
            root.recycle()
            observeOutsideFeed(profile, validatedFeedExit = false)
            return
        }

        val now = SystemClock.elapsedRealtime()
        val rootSnapshot = collectCurrentRootSnapshot(root, profile, now)
        val feedVisible = profile.isRecognizedFeed(rootSnapshot.viewIds)
        if (!feedVisible) {
            observeOutsideFeed(profile, validatedFeedExit = true)
            return
        }
        startObservedFeedTime(
            FeedTimeTarget(
                appId = profile.appId,
                packageName = profile.packageName,
                versionName = profile.versionName,
                feedMarkerIds = profile.feedMarkerViewIds,
                estimated = false,
            ),
        )
        recognizedFeedAppIds.add(profile.appId)
        updateFloatingCounter(profile, recognizedFeed = true)

        val hasPagerIndex = profile.isTransitionSource(sourceId) && event.toIndex >= 0
        val isPagerScroll = event.eventType == AccessibilityEvent.TYPE_VIEW_SCROLLED
        if (hasPagerIndex && (isPagerScroll || activeItems[profile.appId] == null)) {
            val previousIndex = activeItems[profile.appId]?.index
            val transitionObserved = isPagerScroll && hasObservedIndexTransition(
                previousIndex = previousIndex,
                fromIndex = event.fromIndex,
                toIndex = event.toIndex,
            )
            observeItem(
                profile = profile,
                index = event.toIndex,
                now = now,
                transitionObserved = transitionObserved,
                feedEntryObserved = isInitialFeedItem(
                    previousIndex = previousIndex,
                    fromIndex = event.fromIndex,
                    toIndex = event.toIndex,
                ),
                currentRootIdentityHash = rootSnapshot.itemIdentityHash,
            )
            return
        }

        val activeItem = activeItems[profile.appId]
        if (
            CandidateDeadlineGuard.shouldSeedFirstRootIdentityFeedEntry(
                feedVisible = feedVisible,
                activeItemExists = activeItem != null,
                identityStrategy = profile.identityStrategy,
                identityHash = rootSnapshot.itemIdentityHash,
                fromIndex = event.fromIndex,
                toIndex = event.toIndex,
            )
        ) {
            observeItem(
                profile = profile,
                index = event.toIndex.takeIf { it >= 0 } ?: NO_PAGER_INDEX,
                now = now,
                transitionObserved = false,
                feedEntryObserved = true,
                currentRootIdentityHash = rootSnapshot.itemIdentityHash,
            )
            return
        }

        activeItem?.let { currentItem ->
            observeItem(
                profile = profile,
                index = currentItem.index,
                now = now,
                transitionObserved = false,
                feedEntryObserved = false,
                currentRootIdentityHash = rootSnapshot.itemIdentityHash,
            )
        }
    }

    override fun onInterrupt() {
        screenOffResumeTarget = null
        stopObservedFeedTime()
        floatingCounter?.hide()
        clearDebugState()
        serviceHealth.onInterrupt()
        recordCoverageGap()
        clearUniqueIdRelationState()
        (activeItems.keys + confirmationChecks.keys + selectedAppIds).toList().forEach { appId ->
            clearActiveItem(appId)
            detector?.clearCandidate(appId)
        }
        recognizedFeedAppIds.clear()
    }

    override fun onDestroy() {
        stopObservedFeedTime()
        unregisterScreenStateReceiver()
        floatingCounter?.hide()
        clearDebugState()
        floatingCounter = null
        if (serviceHealth.isOperational) recordCoverageGap()
        serviceHealth.onServiceDisconnected()
        clearUniqueIdRelationState()
        handler.removeCallbacks(detectorRegistryRefreshRunnable)
        handler.removeCallbacks(dayVerificationRunnable)
        handler.removeCallbacks(observedFeedHeartbeatRunnable)
        observedFeedHeartbeatScheduled = false
        (activeItems.keys + confirmationChecks.keys + selectedAppIds).toList().forEach { appId ->
            clearActiveItem(appId)
            detector?.clearCandidate(appId)
        }
        recognizedFeedAppIds.clear()
        if (instance === this) instance = null
        super.onDestroy()
    }

    private fun recordCoverageGap() {
        recordCoverageGap(this, LocalDate.now().toString())
    }

    private fun scheduleDayVerificationCheckpoint() {
        handler.removeCallbacks(dayVerificationRunnable)
        val nowMillis = System.currentTimeMillis()
        val zone = ZoneId.systemDefault()
        val nextDayStart = LocalDate.now(zone).plusDays(1)
            .atStartOfDay(zone).toInstant().toEpochMilli()
        val untilMidnight = (nextDayStart - nowMillis).coerceAtLeast(1_000L)
        handler.postDelayed(
            dayVerificationRunnable,
            minOf(DAY_VERIFICATION_CHECK_INTERVAL_MILLIS, untilMidnight),
        )
    }

    private fun checkpointDayVerification() {
        val nowMillis = System.currentTimeMillis()
        val zone = ZoneId.systemDefault()
        val localDate = LocalDate.now(zone)
        val preferences = trackingPreferences()
        val consent = preferences.getBoolean(CONSENT_ACKNOWLEDGED_KEY, false)
        val selected = TrackingConsentGate.allowedApps(
            preferences.getStringSet(SELECTED_APP_IDS_KEY, emptySet()).orEmpty(),
            consent,
        ).intersect(SupportedAppsNative.all.map { it.appId }.toSet())
        val profiles = selectedProfiles(selected, verifiedDetectorRegistry)
        val trackingAvailable = consent &&
            isOperational(this) &&
            selected.isNotEmpty() &&
            profiles.size == selected.size
        val selectedFingerprint = fingerprint(selected.sorted().joinToString(","))
        val profileFingerprint = profileFingerprint(profiles)
        observedSelectedProfileFingerprint = profileFingerprint
        val environment = DailyVerificationEnvironment(
            nowMillis = nowMillis,
            timeZoneId = zone.id,
            offsetSeconds = zone.rules.getOffset(Instant.ofEpochMilli(nowMillis)).totalSeconds,
            selectedAppFingerprint = selectedFingerprint,
            profileFingerprint = profileFingerprint,
            processInstanceId = PROCESS_INSTANCE_ID,
            trackingAvailable = trackingAvailable,
        )
        val dayStartMillis = localDate.atStartOfDay(zone).toInstant().toEpochMilli()
        runCatching {
            ProgressRepositoryProvider.get(this).checkpointDayVerification(
                localDate = localDate.toString(),
                dayStartMillis = dayStartMillis,
                environment = environment,
            )
        }
    }

    private fun fingerprint(value: String): String = MessageDigest.getInstance("SHA-256")
        .digest(value.toByteArray(Charsets.UTF_8))
        .joinToString("") { byte -> "%02x".format(byte.toInt() and 0xff) }

    private fun selectedProfiles(
        selectedAppIds: Set<String>,
        registry: VerifiedDetectorRegistry?,
    ): List<AppDetectorProfile> = selectedAppIds.mapNotNull { appId ->
        val app = SupportedAppsNative.byId(appId) ?: return@mapNotNull null
        val version = installedVersion(app.packageName) ?: return@mapNotNull null
        DetectorProfiles.forVersion(app.packageName, version, registry)
    }

    private fun profileFingerprint(profiles: List<AppDetectorProfile>): String = fingerprint(
        profiles.sortedBy { it.appId }.joinToString("\n") { profile ->
            listOf(
                profile.appId,
                profile.packageName,
                profile.versionName,
                profile.profileId,
                profile.confidence.name,
                profile.identityStrategy.name,
                profile.fixtureRevision,
                profile.identityNodeViewId.orEmpty(),
                profile.feedMarkerViewIds.sorted().joinToString(","),
                profile.transitionViewIds.sorted().joinToString(","),
            ).joinToString("|")
        },
    )

    private fun invalidateDayVerification(localDate: LocalDate, reason: String): Boolean =
        runCatching {
            ProgressRepositoryProvider.get(this).invalidateDayVerification(
                localDate = localDate.toString(),
                reason = reason,
            )
            true
        }.getOrDefault(false)

    private fun invalidateProfileCoverageOnce(localDate: LocalDate, reason: String) {
        if (profileCoverageInvalidatedDate == localDate) return
        if (invalidateDayVerification(localDate, reason)) {
            profileCoverageInvalidatedDate = localDate
        }
    }

    private fun observeSelectedProfileCoverage() {
        val profiles = selectedProfiles(selectedAppIds, verifiedDetectorRegistry)
        val currentFingerprint = profileFingerprint(profiles)
        val reason = DayVerificationInvalidationPolicy.reasonForProfileObservation(
            profileAvailable = selectedAppIds.isNotEmpty() &&
                profiles.size == selectedAppIds.size,
            previousFingerprint = observedSelectedProfileFingerprint,
            currentFingerprint = currentFingerprint,
        )
        if (reason != null) invalidateProfileCoverageOnce(LocalDate.now(), reason)
        observedSelectedProfileFingerprint = currentFingerprint
    }

    private fun refreshFloatingCounterForLocalDay() {
        val counter = floatingCounter ?: return
        val localDate = LocalDate.now()
        if (!counterDayRollover.hasLocalDateChanged(localDate)) return
        val appsToRefresh = counterDayRollover.appsToRefresh(
            localDate = localDate,
            recognizedFeedAppIds = recognizedFeedAppIds,
            counterVisible = counter.isShowing,
        )
        if (appsToRefresh.isEmpty()) {
            if (!counter.isShowing || !estimatedCountingEnabled()) return
            val root = rootInActiveWindow ?: run { counter.hide(); return }
            val packageName = root.packageName?.toString()
            val app = SupportedAppsNative.all.firstOrNull {
                it.packageName == packageName && it.appId in selectedAppIds
            }
            val version = packageName?.let(::installedVersion)
            val profile = if (app != null && packageName != null && version != null &&
                DetectorProfiles.forVersion(packageName, version, verifiedDetectorRegistry) == null
            ) DebugTextProfiles.forVersion(packageName, version) else null
            if (profile == null) {
                root.recycle()
                counter.hide()
                return
            }
            val (feedVisible, _) = collectDebugFeedAndKey(root, profile)
            updateDebugFloatingCounter(profile, feedVisible)
            return
        }

        val profiles = appsToRefresh.mapNotNull(::currentSelectedProfile)
        if (profiles.size != appsToRefresh.size) {
            val availableAppIds = profiles.mapTo(mutableSetOf()) { it.appId }
            (appsToRefresh - availableAppIds).forEach(recognizedFeedAppIds::remove)
            counter.hide()
            return
        }
        profiles.forEach { profile -> updateFloatingCounter(profile, recognizedFeed = true) }
    }

    private fun observeItem(
        profile: AppDetectorProfile,
        index: Int,
        now: Long,
        transitionObserved: Boolean,
        feedEntryObserved: Boolean,
        currentRootIdentityHash: String?,
    ) {
        val previous = activeItems[profile.appId]
        val fingerprint = feedFingerprinters.getOrPut(profile.appId) {
            FeedItemFingerprinter(UUID.randomUUID().toString())
        }.observe(index, transitionObserved, feedEntryObserved)
        val identityHash = when (profile.identityStrategy) {
            ItemIdentityStrategy.STABLE_OPAQUE_ACCESSIBILITY_TOKEN,
            ItemIdentityStrategy.STRUCTURAL_NODE_PAIR,
            ->
                currentRootIdentityHash
            ItemIdentityStrategy.BOUNDED_TRANSITION_FINGERPRINT ->
                fingerprint?.let { itemIdentityHash(profile, it, now) }
            ItemIdentityStrategy.NONE -> null
        }
        if (identityHash == null) {
            cancelDwellCheck(profile.appId)
            activeItems.remove(profile.appId)
            detector?.observe(
                ReelObservation(
                    packageName = profile.packageName,
                    versionName = profile.versionName,
                    isFeedVisible = true,
                    itemIdentity = null,
                    transitionObserved = transitionObserved,
                    feedEntryObserved = feedEntryObserved,
                    identityRevalidatedAtCurrentRoot = false,
                    elapsedRealtimeMillis = now,
                    wallClockMillis = System.currentTimeMillis(),
                    localDateKey = LocalDate.now().toString(),
                ),
            )
            return
        }
        activeItems[profile.appId] = ActiveItem(profile, index, identityHash)
        val outcome = detector?.observe(
            ReelObservation(
                packageName = profile.packageName,
                versionName = profile.versionName,
                isFeedVisible = true,
                itemIdentity = ItemIdentity(identityHash, profile.identityStrategy),
                transitionObserved = transitionObserved,
                feedEntryObserved = feedEntryObserved,
                identityRevalidatedAtCurrentRoot =
                    profile.identityStrategy in setOf(
                        ItemIdentityStrategy.STABLE_OPAQUE_ACCESSIBILITY_TOKEN,
                        ItemIdentityStrategy.STRUCTURAL_NODE_PAIR,
                    ),
                elapsedRealtimeMillis = now,
                wallClockMillis = System.currentTimeMillis(),
                localDateKey = LocalDate.now().toString(),
            ),
        )
        if (previous?.index != index || outcome == DetectionOutcome.CandidateStarted) {
            scheduleDwellCheck(profile, index, identityHash)
        }
    }

    private fun startObservedFeedTime(target: FeedTimeTarget) {
        if (!canObserveFeedTime(target)) {
            stopObservedFeedTime()
            return
        }
        if (observedFeedTimeTarget != target) {
            stopObservedFeedTime()
            if (!isCurrentTimeFeedVisible(target)) return
            observedFeedTimeTarget = target
            observeFeedTimeAt(SystemClock.elapsedRealtime(), target)
        }
        scheduleObservedFeedHeartbeat()
    }

    private fun scheduleObservedFeedHeartbeat() {
        if (observedFeedTimeTarget == null || observedFeedHeartbeatScheduled) return
        observedFeedHeartbeatScheduled = true
        handler.postDelayed(
            observedFeedHeartbeatRunnable,
            ObservedFeedTimeTracker.HEARTBEAT_INTERVAL_MILLIS,
        )
    }

    private fun checkpointObservedFeedTime() {
        val target = observedFeedTimeTarget ?: return
        if (!canObserveFeedTime(target) || !isCurrentTimeFeedVisible(target)) {
            stopObservedFeedTime()
            return
        }
        observeFeedTimeAt(SystemClock.elapsedRealtime(), target)
    }

    private fun canObserveFeedTime(target: FeedTimeTarget): Boolean {
        if (!estimatedCountingEnabled() || !isOperational(this) || !isScreenInteractive() ||
            target.appId !in selectedAppIds || target.feedMarkerIds.isEmpty() ||
            installedVersion(target.packageName) != target.versionName
        ) return false

        return if (target.estimated) {
            DebugTextProfiles.forVersion(target.packageName, target.versionName)
                ?.feedMarkerIds == target.feedMarkerIds
        } else {
            DetectorProfiles.forVersion(
                target.packageName,
                target.versionName,
                verifiedDetectorRegistry,
            )?.feedMarkerViewIds == target.feedMarkerIds
        }
    }

    private fun isScreenInteractive(): Boolean =
        getSystemService(PowerManager::class.java)?.isInteractive == true

    private fun resumeObservedFeedTime(target: FeedTimeTarget) {
        if (instance !== this) return
        startObservedFeedTime(target)
    }

    private fun isCurrentTimeFeedVisible(target: FeedTimeTarget): Boolean {
        val root = rootInActiveWindow ?: return false
        if (root.packageName?.toString() != target.packageName) {
            root.recycle()
            return false
        }
        val viewIds = collectFeedMarkerIds(root, target.packageName)
        return if (target.estimated) {
            DebugTextProfiles.forVersion(target.packageName, target.versionName)
                ?.isRecognizedFeed(viewIds) == true
        } else {
            target.feedMarkerIds.isNotEmpty() && viewIds.containsAll(target.feedMarkerIds)
        }
    }

    private fun registerScreenStateReceiver() {
        if (screenStateReceiverRegistered) return
        val filter = IntentFilter().apply {
            addAction(Intent.ACTION_SCREEN_OFF)
            addAction(Intent.ACTION_SCREEN_ON)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(screenStateReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            @Suppress("DEPRECATION")
            registerReceiver(screenStateReceiver, filter)
        }
        screenStateReceiverRegistered = true
    }

    private fun unregisterScreenStateReceiver() {
        if (!screenStateReceiverRegistered) return
        runCatching { unregisterReceiver(screenStateReceiver) }
        screenStateReceiverRegistered = false
        screenOffResumeTarget = null
    }

    private fun observeFeedTimeAt(elapsedRealtimeMillis: Long, target: FeedTimeTarget) {
        val wallClockMillis = System.currentTimeMillis()
        val zone = ZoneId.systemDefault()
        val instant = Instant.ofEpochMilli(wallClockMillis)
        val scope = ObservedFeedTimeScope(
            appId = target.appId,
            localDate = LocalDate.now(zone).toString(),
            timeZoneId = zone.id,
            offsetSeconds = zone.rules.getOffset(instant).totalSeconds,
        )
        observedFeedTimeTracker.observe(scope, elapsedRealtimeMillis)
            .forEach(::persistObservedFeedDuration)
    }

    private fun stopObservedFeedTime(appId: String? = null) {
        val target = observedFeedTimeTarget
        if (target == null || (appId != null && target.appId != appId)) return
        handler.removeCallbacks(observedFeedHeartbeatRunnable)
        observedFeedHeartbeatScheduled = false
        observedFeedTimeTarget = null
        observedFeedTimeTracker.stop()?.let(::persistObservedFeedDuration)
    }

    private fun persistObservedFeedDuration(batch: ObservedFeedDurationBatch) {
        runCatching {
            ProgressRepositoryProvider.get(this).recordObservedFeedDuration(
                localDate = batch.scope.localDate,
                durationMillis = batch.durationMillis,
                timeZoneId = batch.scope.timeZoneId,
                offsetSeconds = batch.scope.offsetSeconds,
            )
        }
    }

    /** Reads only resource IDs; time sampling never inspects labels or item identity. */
    private fun collectFeedMarkerIds(
        root: AccessibilityNodeInfo,
        resourcePackage: String,
    ): Set<String> {
        val viewIds = mutableSetOf<String>()
        val queue = ArrayDeque<AccessibilityNodeInfo>()
        queue.add(root)
        var visited = 0
        while (queue.isNotEmpty() && visited < MAX_NODES_TO_INSPECT) {
            val node = queue.removeFirst()
            if (node.isVisibleToUser) {
                StructuralProbeFormatter.resourceNameFor(
                    node.viewIdResourceName,
                    resourcePackage,
                )?.let(viewIds::add)
            }
            for (index in 0 until node.childCount) {
                node.getChild(index)?.let(queue::addLast)
            }
            node.recycle()
            visited++
        }
        val complete = queue.isEmpty()
        while (queue.isNotEmpty()) queue.removeFirst().recycle()
        return if (complete) viewIds else emptySet()
    }

    private fun observeOutsideFeed(
        profile: AppDetectorProfile,
        validatedFeedExit: Boolean,
    ) {
        stopObservedFeedTime(profile.appId)
        floatingCounter?.hide()
        if (validatedFeedExit) reportValidatedFeedExit(profile.appId)
        cancelDwellCheck(profile.appId)
        val now = SystemClock.elapsedRealtime()
        detector?.observe(
            ReelObservation(
                packageName = profile.packageName,
                versionName = profile.versionName,
                isFeedVisible = false,
                itemIdentity = null,
                elapsedRealtimeMillis = now,
                wallClockMillis = System.currentTimeMillis(),
                localDateKey = LocalDate.now().toString(),
            ),
        )
        feedFingerprinters.remove(profile.appId)
        activeItems.remove(profile.appId)
    }

    private fun reportValidatedFeedExit(appId: String) {
        val wasRecognized = recognizedFeedAppIds.remove(appId)
        reportValidatedFeedExit(appId, wasRecognized)
    }

    private fun reportValidatedFeedExit(appId: String, wasRecognized: Boolean) {
        val app = SupportedAppsNative.byId(appId) ?: return
        val profileAvailable = installedVersion(app.packageName)?.let { version ->
            DetectorProfiles.forVersion(app.packageName, version, verifiedDetectorRegistry) != null
        } == true
        val preferences = trackingPreferences()
        val consent = preferences.getBoolean(CONSENT_ACKNOWLEDGED_KEY, false)
        if (
            ValidatedFeedExitPolicy.shouldReport(
                previouslyRecognized = wasRecognized,
                profileAvailable = profileAvailable,
                selected = appId in selectedAppIds,
                consentAcknowledged = consent,
                serviceOperational = isOperational(this),
                feedVisibleNow = false,
            )
        ) {
            preferences.edit()
                .putLong(LAST_VALIDATED_FEED_EXIT_AT_MILLIS_KEY, System.currentTimeMillis())
                .apply()
        }
    }

    private fun scheduleDwellCheck(
        profile: AppDetectorProfile,
        index: Int,
        identityHash: String,
    ) {
        cancelDwellCheck(profile.appId)
        val check = Runnable {
            confirmationChecks.remove(profile.appId)
            if (!CandidateDeadlineGuard.canRecheck(
                    profile = profile,
                    selectedAppIds = selectedAppIds,
                    consentAcknowledged = trackingPreferences().getBoolean(
                        CONSENT_ACKNOWLEDGED_KEY, false,
                    ),
                    serviceEnabled = isOperational(this),
                    installedVersion = installedVersion(profile.packageName),
                )
            ) {
                clearActiveItem(profile.appId)
                detector?.clearCandidate(profile.appId)
                return@Runnable
            }
            val currentProfile = DetectorProfiles.forVersion(
                profile.packageName,
                profile.versionName,
                verifiedDetectorRegistry,
            )
            if (currentProfile?.profileId != profile.profileId) {
                clearActiveItem(profile.appId)
                detector?.clearCandidate(profile.appId)
                return@Runnable
            }
            val active = activeItems[profile.appId]
            if (active?.index != index || active.identityHash != identityHash) return@Runnable

            val root = rootInActiveWindow
            if (root == null) {
                observeOutsideFeed(profile, validatedFeedExit = false)
                return@Runnable
            }
            if (root.packageName?.toString() != profile.packageName) {
                root.recycle()
                observeOutsideFeed(profile, validatedFeedExit = false)
                return@Runnable
            }
            val now = SystemClock.elapsedRealtime()
            val rootSnapshot = collectCurrentRootSnapshot(root, profile, now)
            val isFeedVisible = profile.isRecognizedFeed(rootSnapshot.viewIds)
            if (!isFeedVisible) {
                observeOutsideFeed(profile, validatedFeedExit = true)
                return@Runnable
            }
            if (!CandidateDeadlineGuard.hasCurrentCandidateAtDeadline(
                    identityStrategy = profile.identityStrategy,
                    candidateIdentityHash = identityHash,
                    activeIdentityHash = active.identityHash,
                    candidateIndex = index,
                    activeIndex = active.index,
                    feedVisible = isFeedVisible,
                    currentRootIdentityHash = rootSnapshot.itemIdentityHash,
                )
            ) {
                clearActiveItem(profile.appId)
                detector?.clearCandidate(profile.appId)
                return@Runnable
            }

            detector?.observe(
                ReelObservation(
                    packageName = profile.packageName,
                    versionName = profile.versionName,
                    isFeedVisible = true,
                    itemIdentity = ItemIdentity(identityHash, profile.identityStrategy),
                    identityRevalidatedAtCurrentRoot = true,
                    elapsedRealtimeMillis = now,
                    wallClockMillis = System.currentTimeMillis(),
                    localDateKey = LocalDate.now().toString(),
                ),
            )
            updateFloatingCounter(profile, recognizedFeed = true)
        }
        confirmationChecks[profile.appId] = check
        handler.postDelayed(check, ReelDetector.MINIMUM_DWELL_MILLIS)
    }

    private fun cancelDwellCheck(appId: String) {
        confirmationChecks.remove(appId)?.let(handler::removeCallbacks)
    }

    private fun clearActiveItem(appId: String) {
        cancelDwellCheck(appId)
        activeItems.remove(appId)
        feedFingerprinters.remove(appId)
    }

    private fun updateFloatingCounter(
        profile: AppDetectorProfile,
        recognizedFeed: Boolean,
    ) {
        val localDate = LocalDate.now()
        counterDayRollover.recordCountUpdate(localDate)
        val preferences = trackingPreferences()
        val currentProfile = currentSelectedProfile(profile.appId)
        val profileAvailable = currentProfile == profile
        if (!FloatingCounterPolicy.canShow(
                enabled = preferences.getBoolean(BUBBLE_ENABLED_KEY, false),
                overlayGranted = Settings.canDrawOverlays(this),
                trackingConsent = preferences.getBoolean(CONSENT_ACKNOWLEDGED_KEY, false),
                serviceOperational = isOperational(this),
                selected = profile.appId in selectedAppIds,
                profileAvailable = profileAvailable,
                recognizedFeed = recognizedFeed,
            )
        ) {
            floatingCounter?.hide()
            if (!profileAvailable) recognizedFeedAppIds.remove(profile.appId)
            return
        }
        val dailyTotal = countStore
            ?.countsFor(localDate.toString(), selectedAppIds)
            ?.values
            ?.sumOf { it.countedCount }
            ?: return
        floatingCounter?.show(dailyTotal)
    }

    private fun estimatedCountingEnabled(): Boolean =
        trackingPreferences().getBoolean(CONSENT_ACKNOWLEDGED_KEY, false)

    private fun clearDebugState() {
        debugChecks.values.forEach(handler::removeCallbacks)
        debugChecks.clear()
        debugRetryStartedAt.clear()
        debugCounter?.clear()
        floatingCounter?.hide()
    }

    private fun seedVisibleEstimateOnConnect() {
        if (!estimatedCountingEnabled()) return
        val root = rootInActiveWindow ?: return
        val packageName = root.packageName?.toString() ?: run {
            root.recycle()
            return
        }
        val app = SupportedAppsNative.all.firstOrNull {
            it.packageName == packageName && it.appId in selectedAppIds
        }
        val version = installedVersion(packageName)
        if (app == null || version == null) {
            root.recycle()
            return
        }
        val validatedProfile = DetectorProfiles.forVersion(
            packageName,
            version,
            verifiedDetectorRegistry,
        )
        if (validatedProfile != null) {
            val viewIds = collectFeedMarkerIds(root, packageName)
            if (validatedProfile.isRecognizedFeed(viewIds)) {
                startObservedFeedTime(
                    FeedTimeTarget(
                        appId = validatedProfile.appId,
                        packageName = validatedProfile.packageName,
                        versionName = validatedProfile.versionName,
                        feedMarkerIds = validatedProfile.feedMarkerViewIds,
                        estimated = false,
                    ),
                )
            }
            return
        }
        val profile = DebugTextProfiles.forVersion(packageName, version) ?: run {
            root.recycle()
            return
        }
        val (feedVisible, key) = collectDebugFeedAndKey(root, profile)
        if (!feedVisible) return
        startObservedFeedTime(
            FeedTimeTarget(
                appId = profile.appId,
                packageName = profile.packageName,
                versionName = profile.versionName,
                feedMarkerIds = profile.feedMarkerIds,
                estimated = true,
            ),
        )
        debugCounter?.suppressInitialItem(profile.appId)
        debugCounter?.observe(
            profile.appId, key, true, SystemClock.elapsedRealtime(),
            LocalDate.now().toString(), System.currentTimeMillis(),
        )
        updateDebugFloatingCounter(profile, true)
    }

    private fun scanDebugEstimate(profile: DebugTextProfile) {
        debugChecks.remove(profile.appId)?.let(handler::removeCallbacks)
        if (!estimatedCountingEnabled() || profile.appId !in selectedAppIds ||
            installedVersion(profile.packageName) != profile.versionName || !isOperational(this)
        ) {
            stopObservedFeedTime(profile.appId)
            clearDebugState()
            return
        }

        val root = rootInActiveWindow
        val feedAndKey = if (root?.packageName?.toString() == profile.packageName) {
            collectDebugFeedAndKey(root, profile)
        } else {
            root?.recycle()
            false to null
        }
        val (feedVisible, key) = feedAndKey
        val now = SystemClock.elapsedRealtime()
        if (feedVisible) {
            startObservedFeedTime(
                FeedTimeTarget(
                    appId = profile.appId,
                    packageName = profile.packageName,
                    versionName = profile.versionName,
                    feedMarkerIds = profile.feedMarkerIds,
                    estimated = true,
                ),
            )
        } else {
            stopObservedFeedTime(profile.appId)
        }
        val outcome = debugCounter?.observe(
            profile.appId, key, feedVisible, now,
            LocalDate.now().toString(), System.currentTimeMillis(),
        )
        updateDebugFloatingCounter(profile, feedVisible)

        val delay = when (outcome) {
            DebugEstimateOutcome.Candidate, DebugEstimateOutcome.Waiting -> 150L
            DebugEstimateOutcome.MissingKey -> {
                val started = debugRetryStartedAt.getOrPut(profile.appId) { now }
                if (feedVisible && now - started < 3_000L) 250L else null
            }
            else -> null
        }
        if (outcome != DebugEstimateOutcome.MissingKey) {
            debugRetryStartedAt.remove(profile.appId)
        }
        if (delay != null) {
            val check = Runnable { scanDebugEstimate(profile) }
            debugChecks[profile.appId] = check
            handler.postDelayed(check, delay)
        }
    }

    private fun updateDebugFloatingCounter(profile: DebugTextProfile, feedVisible: Boolean) {
        val preferences = trackingPreferences()
        if (!FloatingCounterPolicy.canShow(
                enabled = preferences.getBoolean(BUBBLE_ENABLED_KEY, false),
                overlayGranted = Settings.canDrawOverlays(this),
                trackingConsent = estimatedCountingEnabled(),
                serviceOperational = isOperational(this),
                selected = profile.appId in selectedAppIds,
                profileAvailable = DebugTextProfiles.forVersion(
                    profile.packageName, profile.versionName,
                ) != null,
                recognizedFeed = feedVisible,
            )
        ) {
            floatingCounter?.hide()
            return
        }
        val total = countStore?.countsFor(LocalDate.now().toString(), selectedAppIds)
            ?.values?.sumOf { it.countedCount } ?: return
        floatingCounter?.show(total)
    }

    private fun collectDebugFeedAndKey(
        root: AccessibilityNodeInfo,
        profile: DebugTextProfile,
    ): Pair<Boolean, String?> {
        val viewIds = mutableSetOf<String>()
        val keys = mutableListOf<String>()
        var visibleItems = 0
        var sponsored = false
        val queue = ArrayDeque<AccessibilityNodeInfo>()
        queue.add(root)
        var visited = 0
        while (queue.isNotEmpty() && visited < MAX_NODES_TO_INSPECT) {
            val node = queue.removeFirst()
            val id = StructuralProbeFormatter.resourceNameFor(
                node.viewIdResourceName, profile.packageName,
            )
            if (id != null) viewIds.add(id)
            if (id == profile.itemNodeId && node.isVisibleToUser) {
                visibleItems++
                val (labels, isSponsored) = collectDebugLabels(node)
                sponsored = sponsored || isSponsored
                if (!isSponsored) debugHasher?.digest(labels)?.let(keys::add)
            }
            for (index in 0 until node.childCount) {
                node.getChild(index)?.let(queue::addLast)
            }
            node.recycle()
            visited++
        }
        val complete = queue.isEmpty()
        while (queue.isNotEmpty()) queue.removeFirst().recycle()
        val feedVisible = complete && profile.isRecognizedFeed(viewIds)
        val key = keys.singleOrNull().takeIf {
            feedVisible && visibleItems == 1 && !sponsored
        }
        return feedVisible to key
    }

    private fun collectDebugLabels(itemRoot: AccessibilityNodeInfo): Pair<List<String>, Boolean> {
        val labels = mutableListOf<String>()
        var sponsored = false
        fun inspect(value: CharSequence?) {
            val label = value?.toString()?.takeIf { it.isNotBlank() && it.length <= 160 }
                ?: return
            if (label.equals("sponsored", ignoreCase = true) ||
                label.equals("paid promotion", ignoreCase = true) ||
                label.startsWith("sponsored ·", ignoreCase = true) ||
                label.startsWith("sponsored,", ignoreCase = true)
            ) sponsored = true
            if (labels.size < 4) labels.add(label)
        }
        if (itemRoot.isVisibleToUser) {
            inspect(itemRoot.text)
            inspect(itemRoot.contentDescription)
        }
        val queue = ArrayDeque<AccessibilityNodeInfo>()
        for (index in 0 until itemRoot.childCount) {
            itemRoot.getChild(index)?.let(queue::addLast)
        }
        var visited = 0
        while (queue.isNotEmpty() && visited < 80 && !sponsored) {
            val node = queue.removeFirst()
            if (node.isVisibleToUser) {
                inspect(node.text)
                inspect(node.contentDescription)
            }
            for (index in 0 until node.childCount) {
                node.getChild(index)?.let(queue::addLast)
            }
            node.recycle()
            visited++
        }
        while (queue.isNotEmpty()) queue.removeFirst().recycle()
        return labels to sponsored
    }

    private fun currentSelectedProfile(appId: String): AppDetectorProfile? {
        if (appId !in selectedAppIds) return null
        val app = SupportedAppsNative.byId(appId) ?: return null
        val version = installedVersion(app.packageName) ?: return null
        return DetectorProfiles.forVersion(app.packageName, version, verifiedDetectorRegistry)
            ?.takeIf { it.appId == appId && it.versionName == version }
    }

    private fun itemIdentityHash(
        profile: AppDetectorProfile,
        fingerprint: String,
        nowElapsedMillis: Long,
    ): String? {
        val fingerprint = when (profile.identityStrategy) {
            ItemIdentityStrategy.BOUNDED_TRANSITION_FINGERPRINT -> fingerprint
            ItemIdentityStrategy.NONE,
            ItemIdentityStrategy.STABLE_OPAQUE_ACCESSIBILITY_TOKEN,
            ItemIdentityStrategy.STRUCTURAL_NODE_PAIR,
            -> return null
        }
        return itemIdentityHasher?.hash(
            appId = profile.appId,
            profileKey = "${profile.packageName}|${profile.versionName}",
            opaqueToken = fingerprint,
            elapsedRealtimeMillis = nowElapsedMillis,
        )
    }

    private fun collectCurrentRootSnapshot(
        root: AccessibilityNodeInfo,
        profile: AppDetectorProfile,
        elapsedRealtimeMillis: Long,
    ): CurrentRootSnapshot {
        val viewIds = mutableSetOf<String>()
        val identityNodeViewId = profile.identityNodeViewId
        val canReadRootIdentity = identityNodeViewId != null && profile.identityStrategy in setOf(
            ItemIdentityStrategy.STABLE_OPAQUE_ACCESSIBILITY_TOKEN,
            ItemIdentityStrategy.STRUCTURAL_NODE_PAIR,
        )
        var identityNodeCount = 0
        var itemIdentityHash: String? = null
        val queue = ArrayDeque<AccessibilityNodeInfo>()
        queue.add(root)
        var visited = 0
        while (queue.isNotEmpty() && visited < MAX_NODES_TO_INSPECT) {
            val node = queue.removeFirst()
            val resourceName = StructuralProbeFormatter.resourceNameFor(
                node.viewIdResourceName,
                profile.packageName,
            )
            resourceName?.let(viewIds::add)
            if (
                canReadRootIdentity &&
                resourceName == identityNodeViewId &&
                node.isVisibleToUser
            ) {
                identityNodeCount += 1
                if (identityNodeCount == 1) {
                    val opaqueToken = when (profile.identityStrategy) {
                        ItemIdentityStrategy.STABLE_OPAQUE_ACCESSIBILITY_TOKEN -> {
                            if (Build.VERSION.SDK_INT < 33) null else node.uniqueId
                                ?.takeIf { it.isNotBlank() && it.length <= MAX_OPAQUE_ID_LENGTH }
                        }
                        ItemIdentityStrategy.STRUCTURAL_NODE_PAIR ->
                            StructuralIdentitySignature.nodeHandleAndTopology(
                                nodeHandle = node.hashCode(),
                                topology = currentNodeTopology(node, profile.packageName),
                            )
                        ItemIdentityStrategy.NONE,
                        ItemIdentityStrategy.BOUNDED_TRANSITION_FINGERPRINT,
                        -> null
                    }
                    itemIdentityHash = opaqueToken?.let {
                        itemIdentityHasher?.hash(
                            appId = profile.appId,
                            profileKey = "${profile.packageName}|${profile.versionName}",
                            opaqueToken = it,
                            elapsedRealtimeMillis = elapsedRealtimeMillis,
                        )
                    }
                } else {
                    itemIdentityHash = null
                }
            }
            for (index in 0 until node.childCount) {
                node.getChild(index)?.let(queue::addLast)
            }
            node.recycle()
            visited += 1
        }
        val scanComplete = queue.isEmpty()
        while (queue.isNotEmpty()) queue.removeFirst().recycle()
        if (!CandidateDeadlineGuard.hasUnambiguousIdentityScan(identityNodeCount, scanComplete)) {
            itemIdentityHash = null
        }
        return CurrentRootSnapshot(viewIds, itemIdentityHash)
    }

    /** Builds a bounded, content-free topology from immediate child structure only. */
    private fun currentNodeTopology(
        node: AccessibilityNodeInfo,
        packageName: String,
    ): String? {
        val childCount = node.childCount
        if (childCount !in 0..StructuralIdentitySignature.MAX_CHILDREN) return null
        val children = ArrayList<StructuralChildSignal>(childCount)
        for (index in 0 until childCount) {
            val child = node.getChild(index) ?: return null
            val signal = try {
                StructuralChildSignal(
                    resourceName = StructuralProbeFormatter.resourceNameFor(
                        child.viewIdResourceName,
                        packageName,
                    ),
                    className = child.className?.toString(),
                    childCount = child.childCount,
                    visible = child.isVisibleToUser,
                )
            } finally {
                child.recycle()
            }
            children += signal
        }
        return StructuralIdentitySignature.topology(
            className = node.className?.toString(),
            childCount = childCount,
            children = children,
        )
    }

    private fun collectProbeSnapshot(
        root: AccessibilityNodeInfo,
        resourcePackage: String,
        appId: String,
        versionName: String,
        captureIdentityRelations: Boolean,
        elapsedRealtimeMillis: Long,
    ): ProbeSnapshot {
        val viewIds = mutableSetOf<String>()
        val features = mutableListOf<StructuralNodeFeature>()
        val occurrencesByResource = mutableMapOf<String, Int>()
        val queue = ArrayDeque<AccessibilityNodeInfo>()
        queue.add(root)
        var visited = 0
        while (queue.isNotEmpty() && visited < MAX_NODES_TO_INSPECT) {
            val node = queue.removeFirst()
            val resourceName = StructuralProbeFormatter.resourceNameFor(
                node.viewIdResourceName,
                resourcePackage,
            )
            val occurrence = if (resourceName != null) {
                occurrencesByResource.getOrDefault(resourceName, 0).also { previousOccurrence ->
                    occurrencesByResource[resourceName] = previousOccurrence + 1
                }
            } else {
                0
            }
            if (resourceName != null) {
                viewIds += resourceName
            }
            val isIdentityCandidate = captureIdentityRelations &&
                resourceName != null && UniqueIdProbeNodeIds.isCandidate(appId, resourceName)
            val childNodes = mutableListOf<AccessibilityNodeInfo>()
            for (index in 0 until node.childCount) {
                node.getChild(index)?.let(childNodes::add)
            }
            val childSignals = if (isIdentityCandidate) {
                childNodes.map { child ->
                    StructuralChildSignal(
                        resourceName = StructuralProbeFormatter.resourceNameFor(
                            child.viewIdResourceName,
                            resourcePackage,
                        ),
                        className = child.className?.toString(),
                        childCount = child.childCount,
                        visible = child.isVisibleToUser,
                    )
                }
            } else {
                emptyList()
            }
            val bounds = android.graphics.Rect()
            node.getBoundsInScreen(bounds)
            fun coarse(value: Int) = value / 32 * 32
            val structuralBounds = StructuralBounds(
                coarse(bounds.left),
                coarse(bounds.top),
                coarse(bounds.right),
                coarse(bounds.bottom),
            )
            val uniqueIdRelation = if (isIdentityCandidate) {
                val apiAvailable = UniqueIdRelationTracker.apiLevelSupportsUniqueId(Build.VERSION.SDK_INT)
                val opaqueUniqueId = if (apiAvailable) node.uniqueId else null
                val tracker = uniqueIdRelationTracker ?: UniqueIdRelationTracker().also {
                    uniqueIdRelationTracker = it
                }
                tracker.observe(
                    appId = appId,
                    versionName = versionName,
                    resourceName = resourceName!!,
                    occurrence = occurrence,
                    opaqueUniqueId = opaqueUniqueId,
                    elapsedRealtimeMillis = elapsedRealtimeMillis,
                    apiAvailable = apiAvailable,
                )
            } else {
                null
            }
            val alternativeIdentityRelations = if (isIdentityCandidate) {
                val probe = alternativeIdentityRelationProbe
                    ?: AlternativeIdentityRelationProbe().also {
                        alternativeIdentityRelationProbe = it
                    }
                probe.observe(
                    appId = appId,
                    versionName = versionName,
                    resourceName = resourceName!!,
                    occurrence = occurrence,
                    nodeHandle = node.hashCode().toString(),
                    topologySignature = StructuralIdentitySignature.topology(
                        className = node.className?.toString(),
                        childCount = node.childCount,
                        children = childSignals,
                    ),
                    stateSignature = StructuralIdentitySignature.state(
                        visible = node.isVisibleToUser,
                        selected = node.isSelected,
                        scrollable = node.isScrollable,
                        bounds = structuralBounds,
                    ),
                    elapsedRealtimeMillis = elapsedRealtimeMillis,
                )
            } else {
                null
            }
            if (resourceName != null) {
                val identityEvidenceObserved = uniqueIdRelation != null ||
                    alternativeIdentityRelations != null
                features += StructuralNodeFeature(
                    resourceName = resourceName,
                    className = node.className?.toString(),
                    childCount = node.childCount,
                    scrollable = node.isScrollable,
                    selected = node.isSelected,
                    visible = node.isVisibleToUser,
                    bounds = structuralBounds,
                    identityOrdinal = occurrence.takeIf { identityEvidenceObserved },
                    uniqueIdRelation = uniqueIdRelation,
                    alternativeIdentityRelations = alternativeIdentityRelations,
                )
            }
            childNodes.forEach(queue::addLast)
            node.recycle()
            visited += 1
        }
        while (queue.isNotEmpty()) queue.removeFirst().recycle()
        return ProbeSnapshot(viewIds, features)
    }

    private fun scheduleUniqueIdRelationPurge() {
        if (identityRelationPurgeRunnable != null) return
        val purge = Runnable {
            uniqueIdRelationTracker?.clear()
            alternativeIdentityRelationProbe?.clear()
            identityRelationPurgeRunnable = null
        }
        identityRelationPurgeRunnable = purge
        handler.postDelayed(purge, UniqueIdRelationTracker.MAX_RETENTION_MILLIS)
    }

    private fun clearUniqueIdRelationState() {
        identityRelationPurgeRunnable?.let(handler::removeCallbacks)
        identityRelationPurgeRunnable = null
        uniqueIdRelationTracker?.clear()
        uniqueIdRelationTracker = null
        alternativeIdentityRelationProbe?.clear()
        alternativeIdentityRelationProbe = null
        identityRelationCaptureWasActive = false
    }

    private fun allowContentChangeAt(now: Long): Boolean {
        if (now - lastContentChangeProcessedAt < CONTENT_CHANGE_THROTTLE_MILLIS) {
            return false
        }
        lastContentChangeProcessedAt = now
        return true
    }

    private fun updateSelectedAppIds(ids: Set<String>) {
        val preferences = trackingPreferences()
        val supportedAppIds = SupportedAppsNative.all.map { it.appId }.toSet()
        val sanitizedAppIds = ids.intersect(supportedAppIds)
        if (sanitizedAppIds != ids) {
            preferences.edit().putStringSet(SELECTED_APP_IDS_KEY, sanitizedAppIds).apply()
        }
        val previousConsent = consentAcknowledged
        consentAcknowledged = preferences.getBoolean(CONSENT_ACKNOWLEDGED_KEY, false)
        val updatedAppIds = TrackingConsentGate
            .allowedApps(sanitizedAppIds, consentAcknowledged)
        val selectionChanged = selectedAppsInitialized && updatedAppIds != selectedAppIds
        if (selectionChanged || previousConsent != consentAcknowledged) {
            stopObservedFeedTime()
            floatingCounter?.hide()
            clearDebugState()
        }
        selectedAppIds = updatedAppIds
        observedSelectedProfileFingerprint = profileFingerprint(
            selectedProfiles(updatedAppIds, verifiedDetectorRegistry),
        )
        selectedAppsInitialized = true
        recognizedFeedAppIds.retainAll(selectedAppIds)
        if (selectionChanged) {
            ProgressRepositoryProvider.get(this).invalidateDayVerification(
                LocalDate.now().toString(),
                "Selected app set changed during the day",
            )
        }
        detector?.setSelectedApps(selectedAppIds)
        activeItems.keys.filter { it !in selectedAppIds }.toList().forEach(::clearActiveItem)

        val packageNames = DetectorProfiles.packageNamesForSelection(
            selectedAppIds = selectedAppIds,
            installedVersion = ::installedVersion,
            registry = verifiedDetectorRegistry,
        )
        val debugPackages = if (estimatedCountingEnabled()) {
            SupportedAppsNative.all.mapNotNull { app ->
                if (app.appId !in selectedAppIds) return@mapNotNull null
                val version = installedVersion(app.packageName) ?: return@mapNotNull null
                DebugTextProfiles.forVersion(app.packageName, version)
                    ?.packageName
            }
        } else emptyList()
        val probePackages = if (DetectorStructuralProbe.isEnabled(this)) {
            SupportedAppsNative.all
                .filter { it.appId in selectedAppIds && installedVersion(it.packageName) != null }
                .map { it.packageName }
        } else {
            emptyList()
        }
        DetectorStructuralProbe.recordConfig(
            this,
            SupportedAppsNative.all
                .filter { it.appId in selectedAppIds }
                .map { "${it.appId}\t${installedVersion(it.packageName) ?: "unavailable"}" },
        )

        serviceInfo?.let { currentInfo ->
            // Window exits must be visible to cancel dwell. Foreign events are
            // inspected only for package name, before accessing source/root.
            currentInfo.packageNames = when {
                packageNames.isNotEmpty() || debugPackages.isNotEmpty() -> null
                probePackages.isNotEmpty() -> null
                else -> arrayOf(packageName)
            }
            currentInfo.notificationTimeout = SERVICE_NOTIFICATION_TIMEOUT_MILLIS
            setServiceInfo(currentInfo)
        }
    }

    private fun installedVersion(packageName: String): String? = try {
        @Suppress("DEPRECATION")
        packageManager.getPackageInfo(packageName, 0).versionName
    } catch (_: Exception) {
        null
    }

    private fun replaceDetectorRegistry(registry: VerifiedDetectorRegistry?) {
        val previous = verifiedDetectorRegistry
        if (
            previous?.sequence == registry?.sequence &&
            previous?.payloadDigest == registry?.payloadDigest
        ) return

        stopObservedFeedTime()

        val previousProfileFingerprint = profileFingerprint(
            selectedProfiles(selectedAppIds, previous),
        )
        val currentProfileFingerprint = profileFingerprint(
            selectedProfiles(selectedAppIds, registry),
        )
        DayVerificationInvalidationPolicy.reasonForProfileObservation(
            profileAvailable = true,
            previousFingerprint = previousProfileFingerprint,
            currentFingerprint = currentProfileFingerprint,
        )?.let { reason -> invalidateProfileCoverageOnce(LocalDate.now(), reason) }

        (activeItems.keys + confirmationChecks.keys).toList().forEach { appId ->
            clearActiveItem(appId)
            detector?.clearCandidate(appId)
        }
        verifiedDetectorRegistry = registry
        val store = countStore ?: return
        detector = ReelDetector(DetectorProfiles.all(registry), store)
        detector?.setSelectedApps(selectedAppIds)
        updateSelectedAppIds(selectedAppIds)
    }

    private fun trackingPreferences(): SharedPreferences =
        getSharedPreferences(TRACKING_PREFERENCES, Context.MODE_PRIVATE)

    companion object {
        const val TRACKING_PREFERENCES = "rooko_tracking"
        const val SELECTED_APP_IDS_KEY = "selected_app_ids"
        const val CONSENT_ACKNOWLEDGED_KEY = "tracking_consent_observed_feed_time_v3"
        const val BUBBLE_ENABLED_KEY = "bubble_enabled"
        const val SERVICE_INTERRUPTED_LOCAL_DATE_KEY = "service_interrupted_local_date"
        const val LAST_VALIDATED_FEED_EXIT_AT_MILLIS_KEY = "last_validated_feed_exit_at_millis"
        private const val ITEM_IDENTITY_SALT_KEY = "item_identity_salt"
        private const val MAX_OPAQUE_ID_LENGTH = 512
        private const val CONTENT_CHANGE_THROTTLE_MILLIS = 250L
        private const val SCREEN_ON_RECHECK_DELAY_MILLIS = 500L
        private const val SERVICE_NOTIFICATION_TIMEOUT_MILLIS = 200L
        private const val MAX_NODES_TO_INSPECT = 350
        private const val NO_PAGER_INDEX = -1
        private const val REGISTRY_REFRESH_INTERVAL_MILLIS = 6 * 60 * 60 * 1_000L
        private const val DAY_VERIFICATION_CHECK_INTERVAL_MILLIS = 5 * 60 * 1_000L
        private val PROCESS_INSTANCE_ID = UUID.randomUUID().toString()

        @Volatile
        private var instance: SelectedAppAccessibilityService? = null

        fun updateRunningInstance(selectedAppIds: Set<String>) {
            instance?.updateSelectedAppIds(selectedAppIds)
        }

        internal fun updateRunningDetectorRegistry(registry: VerifiedDetectorRegistry?) {
            instance?.handler?.post {
                instance?.replaceDetectorRegistry(registry)
            }
        }

        fun onHostActivityResumed() {
            instance?.let { service ->
                service.stopObservedFeedTime()
                HostActivityResumePolicy.consumeRecognizedFeedExits(
                    service.recognizedFeedAppIds,
                ).forEach { appId ->
                    service.reportValidatedFeedExit(appId, wasRecognized = true)
                }
            }
        }

        fun hideFloatingCounter() {
            instance?.floatingCounter?.hide()
        }

        fun isEnabled(context: Context): Boolean {
            if (
                Settings.Secure.getInt(
                    context.contentResolver,
                    Settings.Secure.ACCESSIBILITY_ENABLED,
                    0,
                ) != 1
            ) {
                return false
            }
            val enabledServices = Settings.Secure.getString(
                context.contentResolver,
                Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES,
            ).orEmpty()
            val expected = ComponentName(
                context,
                SelectedAppAccessibilityService::class.java,
            ).flattenToString()
            return enabledServices.split(':').any { component ->
                ComponentName.unflattenFromString(component)?.flattenToString() == expected
            }
        }

        fun isOperational(context: Context): Boolean =
            isEnabled(context) && instance?.serviceHealth?.isOperational == true

        fun recordCoverageGap(context: Context, localDate: String) {
            context.getSharedPreferences(TRACKING_PREFERENCES, Context.MODE_PRIVATE)
                .edit()
                .putString(SERVICE_INTERRUPTED_LOCAL_DATE_KEY, localDate)
                .apply()
            runCatching {
                ProgressRepositoryProvider.get(context)
                    .markCoveragePartial(localDate, "Tracking service was interrupted")
            }
        }

        fun hasCoverageGapOn(context: Context, localDate: String): Boolean =
            context.getSharedPreferences(TRACKING_PREFERENCES, Context.MODE_PRIVATE)
                .getString(SERVICE_INTERRUPTED_LOCAL_DATE_KEY, null) == localDate
    }
}
