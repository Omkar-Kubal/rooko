import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/design_system/app_colors.dart';
import '../../core/design_system/app_icons.dart';
import '../../core/design_system/app_theme.dart';
import '../../core/design_system/app_typography.dart';
import '../../core/models/supported_app.dart';
import '../../core/platform/privacy_policy_link.dart';
import '../../core/platform/tracking_consent_dialog.dart';
import '../../core/platform/tracking_platform.dart';
import 'help_diagnostics_screen.dart';
import 'help_feedback_sheets.dart';
import 'focus_tools_screen.dart';
import 'local_release_notes.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.trackingPlatform,
    required this.selectedAppIds,
    required this.onSelectedAppIdsChanged,
    required this.appearance,
    required this.onAppearanceChanged,
    this.launchPrivacyPolicy,
  });

  final TrackingPlatform trackingPlatform;
  final Set<String> selectedAppIds;
  final Future<void> Function(Set<String> appIds) onSelectedAppIdsChanged;
  final AppAppearance appearance;
  final ValueChanged<AppAppearance> onAppearanceChanged;
  final PrivacyPolicyLauncher? launchPrivacyPolicy;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with WidgetsBindingObserver {
  TrackingSnapshot? _snapshot;
  bool _statusUnavailable = false;
  bool _busy = false;
  bool _awaitingAccessibilityReturn = false;
  bool _awaitingOverlayReturn = false;
  bool _settingsReturnRefreshPending = false;
  int _trackingRefreshGeneration = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_refreshTracking());
  }

  @override
  void didUpdateWidget(covariant SettingsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!setEquals(oldWidget.selectedAppIds, widget.selectedAppIds)) {
      unawaited(_refreshTracking());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    final returnedFromRequestedSettings =
        _awaitingAccessibilityReturn || _awaitingOverlayReturn;
    if (returnedFromRequestedSettings) _settingsReturnRefreshPending = true;
    unawaited(
      _refreshTracking(afterSettingsReturn: returnedFromRequestedSettings),
    );
  }

  Future<void> _refreshTracking({
    Set<String>? selectedAppIds,
    bool afterSettingsReturn = false,
  }) async {
    final generation = ++_trackingRefreshGeneration;
    final appIds = selectedAppIds ?? widget.selectedAppIds;
    final finalizeSettingsReturn =
        afterSettingsReturn || _settingsReturnRefreshPending;
    try {
      await widget.trackingPlatform.setSelectedApps(appIds);
      if (!mounted || generation != _trackingRefreshGeneration) return;
      var snapshot = await widget.trackingPlatform.getSnapshot(appIds);
      if (!mounted || generation != _trackingRefreshGeneration) return;
      if (finalizeSettingsReturn &&
          _awaitingOverlayReturn &&
          !snapshot.overlayPermissionGranted &&
          snapshot.bubbleEnabled) {
        await widget.trackingPlatform.setBubbleEnabled(false);
        if (!mounted || generation != _trackingRefreshGeneration) return;
        snapshot = await widget.trackingPlatform.getSnapshot(appIds);
        if (!mounted || generation != _trackingRefreshGeneration) return;
      }
      setState(() {
        _snapshot = snapshot;
        _statusUnavailable = false;
        if (finalizeSettingsReturn) {
          _awaitingAccessibilityReturn = false;
          _awaitingOverlayReturn = false;
          _settingsReturnRefreshPending = false;
        }
      });
    } catch (_) {
      if (!mounted || generation != _trackingRefreshGeneration) return;
      setState(() {
        _statusUnavailable = true;
        if (finalizeSettingsReturn) {
          _awaitingAccessibilityReturn = false;
          _awaitingOverlayReturn = false;
          _settingsReturnRefreshPending = false;
        }
      });
    }
  }

  Future<void> _openAccessibilitySettings() async {
    if (_snapshot?.consentAcknowledged != true) {
      final consented = await _showTrackingDisclosure();
      if (!consented || !mounted) return;
      try {
        await widget.trackingPlatform.setConsentAcknowledged(true);
      } catch (_) {
        _showMessage('Tracking consent could not be saved. Try again.');
        return;
      }
    }

    try {
      await widget.trackingPlatform.setSelectedApps(widget.selectedAppIds);
      _awaitingAccessibilityReturn = true;
      final opened = await widget.trackingPlatform.openAccessibilitySettings();
      if (!opened) {
        _awaitingAccessibilityReturn = false;
        await _refreshTracking();
        _showMessage('Couldn’t open Accessibility settings.');
      }
    } catch (_) {
      _awaitingAccessibilityReturn = false;
      _showMessage('Accessibility settings are unavailable on this device.');
    }
  }

  Future<bool> _showTrackingDisclosure() async {
    return showTrackingConsentDisclosure(context);
  }

  Future<void> _openOverlaySettings() async {
    if (_snapshot?.bubbleEnabled != true) return;
    try {
      _awaitingOverlayReturn = true;
      final opened = await widget.trackingPlatform.openOverlaySettings();
      if (!opened) {
        _awaitingOverlayReturn = false;
        await widget.trackingPlatform.setBubbleEnabled(false);
        await _refreshTracking();
        _showMessage('Couldn’t open overlay settings.');
      }
    } catch (_) {
      _awaitingOverlayReturn = false;
      _showMessage('Overlay settings are unavailable on this device.');
    }
  }

  Future<void> _setFloatingCounter(bool enabled) async {
    if (_busy) return;
    if (enabled) {
      if (_snapshot?.consentAcknowledged != true) {
        _showMessage('Set up tracking access before the floating counter.');
        return;
      }
      final accepted = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Show the floating counter?'),
          content: const Text(
            'A small counter can appear over selected Reels and Shorts feeds. '
            'It shows the shared daily count across selected apps. It '
            'does not capture the screen or save feed content. Android will '
            'ask separately for Display over other apps access. You can move '
            'or close the counter at any time.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Not now'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Continue'),
            ),
          ],
        ),
      );
      if (accepted != true || !mounted) return;
    }

    final generation = ++_trackingRefreshGeneration;
    final appIds = Set<String>.of(widget.selectedAppIds);
    setState(() => _busy = true);
    try {
      await widget.trackingPlatform.setBubbleEnabled(enabled);
      if (!mounted || generation != _trackingRefreshGeneration) return;
      final snapshot = await widget.trackingPlatform.getSnapshot(appIds);
      if (!mounted || generation != _trackingRefreshGeneration) return;
      setState(() => _snapshot = snapshot);
      if (enabled && !snapshot.overlayPermissionGranted) {
        await _openOverlaySettings();
      }
    } catch (_) {
      _showMessage('Couldn’t change the floating counter setting.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openAppPicker() async {
    final selected = Set<String>.of(widget.selectedAppIds);
    var applying = false;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: false,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.x4,
            AppSpacing.x2,
            AppSpacing.x4,
            AppSpacing.x4,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  IconButton(
                    key: const ValueKey('settings-apps-apply'),
                    tooltip: 'Apply app selection',
                    onPressed: applying
                        ? null
                        : () async {
                            setSheetState(() => applying = true);
                            try {
                              await widget.onSelectedAppIdsChanged(
                                Set<String>.of(selected),
                              );
                              if (!sheetContext.mounted) return;
                              Navigator.of(sheetContext).pop();
                            } catch (_) {
                              _showMessage(
                                'App selection could not be saved. Try again.',
                              );
                            } finally {
                              if (sheetContext.mounted) {
                                setSheetState(() => applying = false);
                              }
                            }
                          },
                    icon: const AppIcon(
                      icon: AppIcons.check,
                      semanticLabel: 'Apply app selection',
                      size: AppIconSizes.large,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      'Select apps to track',
                      textAlign: TextAlign.center,
                      style: AppTypography.sectionTitle,
                    ),
                  ),
                  IconButton(
                    key: const ValueKey('settings-apps-cancel'),
                    tooltip: 'Cancel app selection',
                    onPressed: applying
                        ? null
                        : () => Navigator.of(sheetContext).pop(),
                    icon: const AppIcon(
                      icon: AppIcons.closeCircle,
                      semanticLabel: 'Cancel app selection',
                      size: AppIconSizes.large,
                    ),
                  ),
                ],
              ),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.5,
                ),
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final app in SupportedApp.all)
                      CheckboxListTile(
                        key: ValueKey('settings-app-${app.id}'),
                        contentPadding: EdgeInsets.zero,
                        value: selected.contains(app.id),
                        onChanged: applying
                            ? null
                            : (value) {
                                setSheetState(() {
                                  if (value == true) {
                                    selected.add(app.id);
                                  } else {
                                    selected.remove(app.id);
                                  }
                                });
                              },
                        secondary: Image.asset(
                          app.iconAsset,
                          width: 32,
                          height: 32,
                          fit: BoxFit.contain,
                          excludeFromSemantics: true,
                        ),
                        title: Text(app.name, style: AppTypography.cardTitle),
                        subtitle: Text(
                          _appVersionLabel(app.id),
                          style: AppTypography.supporting,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showWhatsNew() async {
    final version = _snapshot?.appVersion.trim().isNotEmpty == true
        ? _snapshot!.appVersion
        : LocalReleaseNotes.version;
    await showWhatsNewSheet(context, appVersion: version);
  }

  void _openFocusTools() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => FocusToolsScreen(
          openInstagramProfile: widget.trackingPlatform.openInstagramProfile,
        ),
      ),
    );
  }

  Future<void> _showHelpAndFeedback() async {
    final action = await showHelpFeedbackSheet(context);
    if (!mounted || action == null) return;

    switch (action) {
      case HelpFeedbackAction.troubleshoot:
        await showHelpDiagnosticsSheet(
          context,
          trackingPlatform: widget.trackingPlatform,
          selectedAppIds: widget.selectedAppIds,
          onChangeApps: _openAppPicker,
        );
      case HelpFeedbackAction.featureRequest:
        await _openSupportEmail(SupportEmailKind.featureRequest);
      case HelpFeedbackAction.supportEmail:
        await _openSupportEmail(SupportEmailKind.support);
    }
  }

  Future<void> _openSupportEmail(SupportEmailKind kind) async {
    try {
      final opened = await widget.trackingPlatform.openSupportEmail(kind);
      if (!opened) _showMessage('No email app is available on this device.');
    } catch (_) {
      _showMessage('Couldn’t open an email app.');
    }
  }

  String _appVersionLabel(String appId) {
    final status = _snapshot?.apps[appId];
    if (status == null) return 'Checking device version…';
    if (!status.installed) return 'Not installed';
    final version = status.versionName;
    if (version == null) return 'Installed version unavailable';
    return 'Version $version';
  }

  Future<void> _openPrivacyPolicy() async {
    bool opened = false;
    try {
      opened = await (widget.launchPrivacyPolicy ?? launchPublicPrivacyPolicy)(
        publicPrivacyPolicyUri,
      );
    } catch (_) {
      // The browser may be unavailable; Settings remains usable.
    }
    if (!opened) {
      _showMessage('Could not open Privacy Policy. Try again.');
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  String get _accessStatus {
    if (_statusUnavailable) return 'Status unavailable';
    final snapshot = _snapshot;
    if (snapshot == null) return 'Checking';
    if (!snapshot.consentAcknowledged) return 'Review disclosure';
    if (!snapshot.serviceEnabled) {
      return 'Off';
    }
    if (!snapshot.serviceOperational) {
      return 'Check needed';
    }
    return 'On';
  }

  String _accessActionLabel(TrackingSnapshot? snapshot) {
    if (snapshot == null) return 'Checking';
    if (!snapshot.consentAcknowledged) return 'Review details';
    if (!snapshot.serviceEnabled || !snapshot.serviceOperational) {
      return 'Open Settings';
    }
    return 'Review access';
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final selectedCount = widget.selectedAppIds.length;
    final bubbleEnabled = _snapshot?.bubbleEnabled == true;
    final overlayGranted = _snapshot?.overlayPermissionGranted == true;
    final accessActionLabel = _accessActionLabel(_snapshot);
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.x4,
        AppSpacing.x6,
        AppSpacing.x4,
        AppSpacing.x8,
      ),
      children: [
        _SettingsGroup(
          title: 'Tracking',
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              onTap: _openAppPicker,
              leading: const _SettingsGlyph(icon: AppIcons.sourceApp),
              title: Text('Apps', style: AppTypography.cardTitle),
              subtitle: Text(
                '$selectedCount selected',
                style: AppTypography.supporting.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
              trailing: IconButton(
                key: const ValueKey('settings-apps-open'),
                tooltip: 'Select apps',
                onPressed: _openAppPicker,
                icon: const AppIcon(
                  icon: AppIcons.next,
                  size: AppIconSizes.standard,
                ),
              ),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const _SettingsGlyph(icon: AppIcons.permission),
              title: Text(
                'Accessibility access',
                style: AppTypography.cardTitle,
              ),
              subtitle: Text(
                _accessStatus,
                style: AppTypography.supporting.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
              trailing: MediaQuery.textScalerOf(context).scale(1) > 1.5
                  ? IconButton(
                      tooltip: accessActionLabel,
                      onPressed: _busy ? null : _openAccessibilitySettings,
                      icon: const AppIcon(icon: AppIcons.accessSettings),
                    )
                  : TextButton(
                      onPressed: _busy ? null : _openAccessibilitySettings,
                      child: Text(accessActionLabel),
                    ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.x4),
        _SettingsGroup(
          title: 'Focus tools',
          children: [
            ListTile(
              key: const ValueKey('settings-focus-tools'),
              contentPadding: EdgeInsets.zero,
              onTap: _openFocusTools,
              leading: const _SettingsGlyph(icon: AppIcons.creatorGroup),
              title: Text('Focus tools', style: AppTypography.cardTitle),
              subtitle: Text(
                'Creator shelf',
                style: AppTypography.supporting.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
              trailing: const AppIcon(icon: AppIcons.next),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.x4),
        _SettingsGroup(
          title: 'Preferences',
          children: [
            SwitchListTile.adaptive(
              key: const ValueKey('floating-counter-toggle'),
              contentPadding: EdgeInsets.zero,
              title: Text('Floating counter', style: AppTypography.cardTitle),
              subtitle: Text(
                !bubbleEnabled
                    ? 'Off'
                    : overlayGranted
                    ? 'Overlay access on'
                    : 'Overlay access needed',
                style: AppTypography.supporting.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
              value: bubbleEnabled,
              onChanged: _snapshot == null || _busy
                  ? null
                  : _setFloatingCounter,
            ),
            if (bubbleEnabled && !overlayGranted)
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: TextButton(
                  onPressed: _busy ? null : _openOverlaySettings,
                  child: const Text('Review overlay access'),
                ),
              ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const _SettingsGlyph(icon: AppIcons.appearance),
              title: Text('Appearance', style: AppTypography.cardTitle),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _appearanceLabel(widget.appearance),
                    style: AppTypography.cardTitle,
                  ),
                  const SizedBox(width: AppSpacing.x1),
                  PopupMenuButton<AppAppearance>(
                    key: const ValueKey('appearance-selector'),
                    tooltip: 'Select appearance',
                    color: colors.surface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadii.sheet),
                      side: BorderSide(color: colors.outline),
                    ),
                    clipBehavior: Clip.antiAlias,
                    onSelected: widget.onAppearanceChanged,
                    itemBuilder: (context) => [
                      for (final value in AppAppearance.values)
                        PopupMenuItem<AppAppearance>(
                          value: value,
                          height: 60,
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.x3,
                          ),
                          child: Row(
                            children: [
                              Expanded(child: Text(_appearanceLabel(value))),
                              if (value == widget.appearance) ...[
                                const SizedBox(width: AppSpacing.x3),
                                AppIcon(
                                  icon: AppIcons.check,
                                  size: AppIconSizes.small,
                                  color: colors.onSurface,
                                ),
                              ],
                            ],
                          ),
                        ),
                    ],
                    child: SizedBox(
                      key: const ValueKey('appearance-open-button'),
                      width: 48,
                      height: 48,
                      child: Center(
                        child: RotatedBox(
                          quarterTurns: 1,
                          child: AppIcon(
                            icon: AppIcons.next,
                            size: AppIconSizes.standard,
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.x4),
        _SettingsGroup(
          title: 'Support',
          children: [
            _SettingsActionTile(
              icon: AppIcons.notification,
              title: "What's New",
              onTap: _showWhatsNew,
            ),
            _SettingsActionTile(
              icon: AppIcons.help,
              title: 'Help & Feedback',
              onTap: _showHelpAndFeedback,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.x4),
        Card(
          color: colors.surfaceContainer,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(AppRadii.card)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.x4),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadii.card),
                  child: Image.asset(
                    'assets/rook/rook-app-logo-transparent.png',
                    width: 64,
                    height: 64,
                    fit: BoxFit.contain,
                    excludeFromSemantics: true,
                  ),
                ),
                const SizedBox(width: AppSpacing.x4),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Rooko', style: AppTypography.sectionTitle),
                      Text(
                        'Short-form feed awareness',
                        style: AppTypography.supporting.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                      Text(
                        'Version ${_snapshot?.appVersion.isNotEmpty == true ? _snapshot!.appVersion : 'Unavailable'}',
                        style: AppTypography.supporting.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.x4),
        _SettingsGroup(
          title: 'About',
          children: [
            Semantics(
              link: true,
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const _SettingsGlyph(icon: AppIcons.privacy),
                title: Text('Privacy Policy', style: AppTypography.cardTitle),
                trailing: const AppIcon(icon: AppIcons.next),
                onTap: _openPrivacyPolicy,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(
            left: AppSpacing.x2,
            bottom: AppSpacing.x2,
          ),
          child: Text(
            title.toUpperCase(),
            style: AppTypography.supporting.copyWith(
              color: colors.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Card(
          color: colors.surfaceContainer,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(AppRadii.card)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.x4,
              vertical: AppSpacing.x2,
            ),
            child: Column(children: children),
          ),
        ),
      ],
    );
  }
}

class _SettingsGlyph extends StatelessWidget {
  const _SettingsGlyph({required this.icon});

  final AppIconData icon;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(AppRadii.card),
    ),
    child: SizedBox(
      width: 40,
      height: 40,
      child: Center(
        child: AppIcon(icon: icon, size: AppIconSizes.standard),
      ),
    ),
  );
}

class _SettingsActionTile extends StatelessWidget {
  const _SettingsActionTile({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  final AppIconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.x1),
      child: Row(
        children: [
          _SettingsGlyph(icon: icon),
          const SizedBox(width: AppSpacing.x4),
          Expanded(child: Text(title, style: AppTypography.cardTitle)),
          IconButton(
            tooltip: 'Open $title',
            onPressed: onTap,
            icon: const AppIcon(icon: AppIcons.next),
          ),
        ],
      ),
    ),
  );
}

String _appearanceLabel(AppAppearance appearance) => switch (appearance) {
  AppAppearance.system => 'System',
  AppAppearance.light => 'Light',
  AppAppearance.dark => 'Dark',
  AppAppearance.amoled => 'AMOLED',
};
