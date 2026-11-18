import 'dart:async';

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/design_system/app_colors.dart';
import '../../core/design_system/app_icons.dart';
import '../../core/design_system/app_theme.dart';
import '../../core/design_system/app_typography.dart';
import '../../core/models/supported_app.dart';
import '../../core/platform/tracking_consent_dialog.dart';
import '../../core/platform/tracking_platform.dart';
import '../progress/progress_screen.dart';
import '../settings/settings_screen.dart';
import 'rook_mascot.dart';
import 'rook_state.dart';

enum _HomeDestination { today, progress, settings }

class TodayHomeScreen extends StatefulWidget {
  const TodayHomeScreen({
    super.key,
    this.trackingPlatform = const MethodChannelTrackingPlatform(),
    this.appearance = AppAppearance.system,
    this.onAppearanceChanged,
  });

  final TrackingPlatform trackingPlatform;
  final AppAppearance appearance;
  final ValueChanged<AppAppearance>? onAppearanceChanged;

  @override
  State<TodayHomeScreen> createState() => _TodayHomeScreenState();
}

class _TodayHomeScreenState extends State<TodayHomeScreen>
    with WidgetsBindingObserver {
  static const _selectedAppsKey = 'rooko_selected_supported_apps';
  static const _accessWallDismissedKey = 'rooko_access_wall_dismissed';

  _HomeDestination _destination = _HomeDestination.today;
  List<String> _selectedAppIds = [];
  bool _accessWallDismissed = false;
  TrackingSnapshot? _trackingSnapshot;
  bool _trackingUnavailable = false;
  int _lastHandledFeedExitAtMillis = 0;
  RookRecoveryWindow? _recoveryWindow;
  Timer? _recoveryTimer;
  Timer? _midnightRefreshTimer;
  late final Future<void> _settingsReady;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _settingsReady = _loadSettings();
    _scheduleMidnightRefresh();
    _refreshTracking();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _recoveryTimer?.cancel();
    _midnightRefreshTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _scheduleMidnightRefresh();
      _refreshTracking();
    }
  }

  Future<void> _loadSettings() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final savedAppIds =
          preferences.getStringList(_selectedAppsKey) ?? <String>[];
      final selectedAppIds =
          savedAppIds
              .where((id) => SupportedApp.byId(id) != null)
              .toSet()
              .toList()
            ..sort();
      final normalizedSavedAppIds = savedAppIds.toSet().toList()..sort();
      if (!listEquals(selectedAppIds, normalizedSavedAppIds)) {
        await preferences.setStringList(_selectedAppsKey, selectedAppIds);
      }
      if (!mounted) return;
      setState(() {
        _selectedAppIds = selectedAppIds;
        _accessWallDismissed =
            preferences.getBool(_accessWallDismissedKey) ?? false;
      });
    } catch (_) {
      // Keep Today usable if local settings cannot be read.
    }
  }

  Future<void> _refreshTracking() async {
    await _settingsReady;
    if (!mounted) return;
    final appIds = _selectedAppIds.toSet();
    try {
      await widget.trackingPlatform.setSelectedApps(appIds);
      final snapshot = await widget.trackingPlatform.getSnapshot(appIds);
      if (!mounted) return;
      _acceptFeedExit(snapshot);
      final accessIsReady =
          snapshot.consentAcknowledged &&
          snapshot.serviceEnabled &&
          snapshot.serviceOperational &&
          (!snapshot.bubbleEnabled || snapshot.overlayPermissionGranted);
      if (accessIsReady && _accessWallDismissed) {
        final preferences = await SharedPreferences.getInstance();
        await preferences.setBool(_accessWallDismissedKey, false);
      }
      setState(() {
        _trackingSnapshot = snapshot;
        _trackingUnavailable = false;
        if (accessIsReady) _accessWallDismissed = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _trackingUnavailable = true);
    }
  }

  void _acceptFeedExit(TrackingSnapshot snapshot) {
    final signalAtMillis = snapshot.lastValidatedFeedExitAtMillis;
    if (signalAtMillis <= _lastHandledFeedExitAtMillis) return;
    _lastHandledFeedExitAtMillis = signalAtMillis;
    final nowMillis = DateTime.now().millisecondsSinceEpoch;
    final window = RookRecoveryWindow.fromSignal(
      signalAtMillis: signalAtMillis,
      observedAtMillis: nowMillis,
    );
    if (window == null) return;
    _recoveryTimer?.cancel();
    _recoveryWindow = window;
    _recoveryTimer = Timer(
      Duration(milliseconds: window.untilMillis - nowMillis),
      () {
        if (!mounted) return;
        setState(() => _recoveryWindow = null);
      },
    );
  }

  void _scheduleMidnightRefresh() {
    _midnightRefreshTimer?.cancel();
    final now = DateTime.now();
    final nextMidnight = DateTime(now.year, now.month, now.day + 1);
    _midnightRefreshTimer = Timer(nextMidnight.difference(now), () {
      _refreshTracking();
      _scheduleMidnightRefresh();
    });
  }

  RookState get _todayRookState {
    final snapshot = _trackingSnapshot;
    return RookState.forToday(
      count: snapshot?.selectedCountedCount ?? 0,
      monitoringAvailable:
          !_trackingUnavailable && snapshot?.monitoringAvailable == true,
      recovering:
          _recoveryWindow?.isActiveAt(DateTime.now().millisecondsSinceEpoch) ??
          false,
    );
  }

  Widget _buildSelectedPage() => switch (_destination) {
    _HomeDestination.today =>
      _shouldShowPermissionWall
          ? _TodayPermissionWall(
              consentNeeded: _consentNeedsAttention,
              showAccessibility: _accessibilityNeedsAttention,
              showOverlay: _overlayNeedsAttention,
              accessibilityEnabled: _trackingSnapshot?.serviceEnabled == true,
              onAllow: _handlePermissionAction,
              allowLabel: _consentNeedsAttention
                  ? 'Review details'
                  : 'Open Settings',
              onDismiss: _dismissPermissionWall,
            )
          : _TodayContent(
              selectedApps: SupportedApp.all
                  .where((app) => _selectedAppIds.contains(app.id))
                  .toList(growable: false),
              trackingSnapshot: _trackingSnapshot,
              rookState: _todayRookState,
              trackingUnavailable: _trackingUnavailable,
              showPermissionBanner: _hasMissingPermission,
              permissionBannerMessage: _permissionBannerMessage,
              permissionBannerActionLabel: _consentNeedsAttention
                  ? 'Review'
                  : 'Allow',
              onOpenSettings: _handlePermissionAction,
            ),
    _HomeDestination.progress => ProgressScreen(
      trackingPlatform: widget.trackingPlatform,
      selectedAppIds: _selectedAppIds.toSet(),
    ),
    _HomeDestination.settings => SettingsScreen(
      trackingPlatform: widget.trackingPlatform,
      selectedAppIds: _selectedAppIds.toSet(),
      onSelectedAppIdsChanged: _saveSelectedApps,
      appearance: widget.appearance,
      onAppearanceChanged: widget.onAppearanceChanged ?? (_) {},
    ),
  };

  bool get _consentNeedsAttention {
    final snapshot = _trackingSnapshot;
    return _selectedAppIds.isNotEmpty &&
        snapshot != null &&
        !snapshot.consentAcknowledged;
  }

  bool get _accessibilityNeedsAttention {
    final snapshot = _trackingSnapshot;
    return _selectedAppIds.isNotEmpty &&
        snapshot != null &&
        (!snapshot.serviceEnabled || !snapshot.serviceOperational);
  }

  bool get _overlayNeedsAttention =>
      _trackingSnapshot?.bubbleEnabled == true &&
      _trackingSnapshot?.overlayPermissionGranted != true;

  bool get _hasMissingPermission =>
      !_trackingUnavailable &&
      _trackingSnapshot != null &&
      (_consentNeedsAttention ||
          _accessibilityNeedsAttention ||
          _overlayNeedsAttention);

  String get _permissionBannerMessage {
    if (_consentNeedsAttention) {
      return 'Review updated tracking details before counting resumes.';
    }
    if (_accessibilityNeedsAttention) {
      return 'Allow access to count Reels and Shorts.';
    }
    return 'Allow display access to show the floating counter.';
  }

  Future<void> _handlePermissionAction() async {
    if (_consentNeedsAttention) {
      final accepted = await showTrackingConsentDisclosure(context);
      if (!accepted || !mounted) return;
      try {
        await widget.trackingPlatform.setConsentAcknowledged(true);
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Tracking details could not be saved. Try again.'),
            ),
          );
        }
        return;
      }
      await _refreshTracking();
      return;
    }

    if (!mounted) return;
    setState(() => _destination = _HomeDestination.settings);
  }

  bool get _shouldShowPermissionWall =>
      _hasMissingPermission && !_accessWallDismissed;

  Future<void> _dismissPermissionWall() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_accessWallDismissedKey, true);
    if (!mounted) return;
    setState(() => _accessWallDismissed = true);
  }

  Future<void> _saveSelectedApps(Set<String> appIds) async {
    final validIds = appIds
        .where((id) => SupportedApp.byId(id) != null)
        .toSet();
    final preferences = await SharedPreferences.getInstance();
    await preferences.setStringList(
      _selectedAppsKey,
      validIds.toList()..sort(),
    );
    if (!mounted) return;
    setState(() => _selectedAppIds = validIds.toList()..sort());
    _refreshTracking();
  }

  void _returnToToday() {
    if (_destination == _HomeDestination.today) return;
    setState(() => _destination = _HomeDestination.today);
    _refreshTracking();
  }

  @override
  Widget build(BuildContext context) {
    final showPermissionWall =
        _destination == _HomeDestination.today && _shouldShowPermissionWall;

    return PopScope<Object?>(
      canPop: _destination == _HomeDestination.today,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _returnToToday();
      },
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              if (!showPermissionWall)
                _TopNavigation(
                  destination: _destination,
                  onBack: _returnToToday,
                  onProgress: () =>
                      setState(() => _destination = _HomeDestination.progress),
                  onSettings: () =>
                      setState(() => _destination = _HomeDestination.settings),
                ),
              Expanded(child: _buildSelectedPage()),
            ],
          ),
        ),
      ),
    );
  }
}

class _TodayContent extends StatelessWidget {
  const _TodayContent({
    required this.selectedApps,
    required this.trackingSnapshot,
    required this.rookState,
    required this.trackingUnavailable,
    required this.showPermissionBanner,
    required this.permissionBannerMessage,
    required this.permissionBannerActionLabel,
    required this.onOpenSettings,
  });

  final List<SupportedApp> selectedApps;
  final TrackingSnapshot? trackingSnapshot;
  final RookState rookState;
  final bool trackingUnavailable;
  final bool showPermissionBanner;
  final String permissionBannerMessage;
  final String permissionBannerActionLabel;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final date = MaterialLocalizations.of(context)
        .formatFullDate(DateTime.now());
    final countedCount = trackingSnapshot?.selectedCountedCount ?? 0;
    final appCounts = <_TodayAppCount>[];
    final snapshot = trackingSnapshot;
    if (snapshot != null) {
      for (final app in selectedApps) {
        final appSnapshot = snapshot.apps[app.id];
        if (appSnapshot != null) {
          appCounts.add(_TodayAppCount(app, appSnapshot.countedCount));
        }
      }
    }
    final countSubtitle = trackingSnapshot == null
        ? trackingUnavailable
              ? 'Today’s count is unavailable.'
              : 'Checking today’s count.'
        : countedCount == 0
        ? 'No Reels or Shorts counted yet.'
        : null;

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.x4,
            AppSpacing.x4,
            AppSpacing.x4,
            0,
          ),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (showPermissionBanner) ...[
                  _TodayPermissionBanner(
                    message: permissionBannerMessage,
                    actionLabel: permissionBannerActionLabel,
                    onAllow: onOpenSettings,
                  ),
                  const SizedBox(height: AppSpacing.x3),
                ],
                Text(
                  date,
                  style: AppTypography.body.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
        SliverFillRemaining(
          hasScrollBody: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x4),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  RookMascot(state: rookState),
                  const SizedBox(height: AppSpacing.x2),
                  Text(
                    trackingSnapshot == null ? '—' : '$countedCount',
                    textAlign: TextAlign.center,
                    style: AppTypography.metric,
                  ),
                  const SizedBox(height: AppSpacing.x1),
                  Text(
                    'Reels and Shorts counted today',
                    textAlign: TextAlign.center,
                    style: AppTypography.body.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  if (appCounts.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.x4),
                    _TodayAppCountPill(appCounts: appCounts),
                  ],
                  if (countSubtitle != null) ...[
                    const SizedBox(height: AppSpacing.x1),
                    Text(
                      countSubtitle,
                      textAlign: TextAlign.center,
                      style: AppTypography.supporting.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                  if (selectedApps.isEmpty) ...[
                    const SizedBox(height: AppSpacing.x4),
                    Text(
                      'Choose apps in Settings to start counting.',
                      textAlign: TextAlign.center,
                      style: AppTypography.supporting.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _TodayAppCount {
  const _TodayAppCount(this.app, this.count);

  final SupportedApp app;
  final int count;
}

class _TodayAppCountPill extends StatelessWidget {
  const _TodayAppCountPill({required this.appCounts});

  final List<_TodayAppCount> appCounts;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Center(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DecoratedBox(
          key: const ValueKey('today-app-counts'),
          decoration: BoxDecoration(
            color: colors.primary,
            borderRadius: BorderRadius.circular(AppRadii.pill),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.x6,
              vertical: AppSpacing.x3,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var index = 0; index < appCounts.length; index++) ...[
                  if (index > 0) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.x2,
                      ),
                      child: SizedBox(
                        width: 1,
                        height: AppSpacing.x6,
                        child: ColoredBox(
                          color: colors.onPrimary.withValues(alpha: 0.5),
                        ),
                      ),
                    ),
                  ],
                  Semantics(
                    label:
                        '${appCounts[index].app.name}, ${appCounts[index].count}',
                    child: ExcludeSemantics(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Image.asset(
                            appCounts[index].app.iconAsset,
                            width: AppIconSizes.large,
                            height: AppIconSizes.large,
                            fit: BoxFit.contain,
                          ),
                          const SizedBox(width: AppSpacing.x2),
                          Text(
                            '${appCounts[index].count}',
                            style: AppTypography.sectionTitle.copyWith(
                              color: colors.onPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TodayPermissionWall extends StatelessWidget {
  const _TodayPermissionWall({
    required this.consentNeeded,
    required this.showAccessibility,
    required this.showOverlay,
    required this.accessibilityEnabled,
    required this.onAllow,
    required this.allowLabel,
    required this.onDismiss,
  });

  final bool consentNeeded;
  final bool showAccessibility;
  final bool showOverlay;
  final bool accessibilityEnabled;
  final VoidCallback onAllow;
  final String allowLabel;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ListView(
      key: const ValueKey('today-permission-wall'),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.x4,
        AppSpacing.x2,
        AppSpacing.x4,
        AppSpacing.x8,
      ),
      children: [
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: IconButton(
            key: const ValueKey('permission-wall-dismiss'),
            tooltip: 'Dismiss permission message',
            onPressed: onDismiss,
            icon: AppIcon(
              icon: AppIcons.close,
              semanticLabel: 'Dismiss permission message',
              size: AppIconSizes.large,
              color: colors.onSurface,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.x8),
        Text(
          consentNeeded ? 'Review tracking details' : 'Rooko needs access',
          style: AppTypography.pageTitle,
        ),
        const SizedBox(height: AppSpacing.x2),
        Text(
          consentNeeded
              ? 'Please review the updated tracking disclosure before counting can continue.'
              : 'Allow access in Settings to count Reels and Shorts in your selected apps.',
          style: AppTypography.body.copyWith(color: colors.onSurfaceVariant),
        ),
        const SizedBox(height: AppSpacing.x6),
        if (consentNeeded)
          _PermissionRequirementRow(
            title: 'Tracking details',
            subtitle: 'Your review is needed before counting can continue',
            icon: AppIcons.privacy,
          ),
        if (showAccessibility)
          _PermissionRequirementRow(
            title: 'Accessibility access',
            subtitle: accessibilityEnabled
                ? 'The service needs attention in Android Settings'
                : 'Turn on Rooko in Android Accessibility settings',
          ),
        if (showOverlay)
          _PermissionRequirementRow(
            title: 'Display over other apps',
            subtitle: 'To show the floating counter',
          ),
        const SizedBox(height: AppSpacing.x4),
        FilledButton(
          key: const ValueKey('permission-wall-allow'),
          onPressed: onAllow,
          child: Text(allowLabel),
        ),
      ],
    );
  }
}

class _PermissionRequirementRow extends StatelessWidget {
  const _PermissionRequirementRow({
    required this.title,
    required this.subtitle,
    this.icon = AppIcons.permission,
  });

  final String title;
  final String subtitle;
  final AppIconData icon;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.x2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppIcon(
            icon: icon,
            size: AppIconSizes.large,
            color: colors.onSurface,
          ),
          const SizedBox(width: AppSpacing.x2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTypography.cardTitle),
                const SizedBox(height: AppSpacing.x1),
                Text(
                  subtitle,
                  style: AppTypography.supporting.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TodayPermissionBanner extends StatelessWidget {
  const _TodayPermissionBanner({
    required this.message,
    required this.actionLabel,
    required this.onAllow,
  });

  final String message;
  final String actionLabel;
  final VoidCallback onAllow;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      key: const ValueKey('today-permission-banner'),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.x3,
        AppSpacing.x2,
        AppSpacing.x2,
        AppSpacing.x2,
      ),
      decoration: BoxDecoration(
        color: colors.surfaceContainer,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: colors.outline),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              message,
              style: AppTypography.supporting.copyWith(
                color: colors.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.x2),
          FilledButton.tonal(
            key: const ValueKey('permission-banner-allow'),
            onPressed: onAllow,
            child: Text(actionLabel),
          ),
        ],
      ),
    );
  }
}

class _TopNavigation extends StatelessWidget {
  const _TopNavigation({
    required this.destination,
    required this.onBack,
    required this.onProgress,
    required this.onSettings,
  });

  final _HomeDestination destination;
  final VoidCallback onBack;
  final VoidCallback onProgress;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(
      AppSpacing.x4,
      AppSpacing.x2,
      AppSpacing.x4,
      0,
    ),
    child: Row(
      children: [
        if (destination != _HomeDestination.today)
          IconButton(
            key: const ValueKey('top-nav-back'),
            tooltip: 'Back to Today',
            onPressed: onBack,
            icon: const AppIcon(icon: AppIcons.back, size: AppIconSizes.large),
          ),
        if (destination != _HomeDestination.today)
          const SizedBox(width: AppSpacing.x2),
        Expanded(
          child: Semantics(
            header: true,
            child: Text(
              switch (destination) {
                _HomeDestination.today => 'Today',
                _HomeDestination.progress => 'Progress',
                _HomeDestination.settings => 'Settings',
              },
              key: const ValueKey('top-nav-title'),
              style: AppTypography.pageTitle,
            ),
          ),
        ),
        _TopNavigationItem(
          key: const ValueKey('top-nav-progress'),
          label: 'Progress',
          icon: AppIcons.progress,
          selected: destination == _HomeDestination.progress,
          onTap: onProgress,
        ),
        const SizedBox(width: AppSpacing.x2),
        _TopNavigationItem(
          key: const ValueKey('top-nav-settings'),
          label: 'Settings',
          icon: AppIcons.settings,
          selected: destination == _HomeDestination.settings,
          onTap: onSettings,
        ),
      ],
    ),
  );
}

class _TopNavigationItem extends StatelessWidget {
  const _TopNavigationItem({
    super.key,
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final AppIconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Material(
        color: selected ? colors.primary : Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadii.pill),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadii.pill),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            child: Center(
              child: ExcludeSemantics(
                child: AppIcon(
                  icon: icon,
                  size: AppIconSizes.large,
                  color: selected ? colors.onPrimary : colors.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
