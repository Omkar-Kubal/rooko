import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/design_system/app_icons.dart';
import '../../core/design_system/app_colors.dart';
import '../../core/design_system/app_typography.dart';
import '../../core/models/supported_app.dart';
import '../../core/platform/tracking_consent_dialog.dart';
import '../../core/platform/tracking_platform.dart';

Future<void> showHelpDiagnosticsSheet(
  BuildContext context, {
  required TrackingPlatform trackingPlatform,
  required Set<String> selectedAppIds,
  required Future<void> Function() onChangeApps,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  builder: (sheetContext) => SizedBox(
    height: MediaQuery.sizeOf(sheetContext).height * 0.88,
    child: HelpDiagnosticsSheet(
      trackingPlatform: trackingPlatform,
      selectedAppIds: selectedAppIds,
      onChangeApps: onChangeApps,
    ),
  ),
);

class HelpDiagnosticsSheet extends StatefulWidget {
  const HelpDiagnosticsSheet({
    super.key,
    required this.trackingPlatform,
    required this.selectedAppIds,
    required this.onChangeApps,
  });

  final TrackingPlatform trackingPlatform;
  final Set<String> selectedAppIds;
  final Future<void> Function() onChangeApps;

  @override
  State<HelpDiagnosticsSheet> createState() => _HelpDiagnosticsSheetState();
}

class _HelpDiagnosticsSheetState extends State<HelpDiagnosticsSheet>
    with WidgetsBindingObserver {
  TrackingSnapshot? _snapshot;
  bool _loading = true;
  bool _loadFailed = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_refresh());
  }

  @override
  void didUpdateWidget(covariant HelpDiagnosticsSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!setEquals(oldWidget.selectedAppIds, widget.selectedAppIds)) {
      unawaited(_refresh());
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
    unawaited(_refresh());
  }

  Future<void> _refresh() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _loadFailed = false;
      });
    }
    try {
      await widget.trackingPlatform.setSelectedApps(widget.selectedAppIds);
      final snapshot = await widget.trackingPlatform.getSnapshot(
        widget.selectedAppIds,
      );
      if (!mounted) return;
      setState(() {
        _snapshot = snapshot;
        _loading = false;
        _loadFailed = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadFailed = true;
      });
    }
  }

  Future<void> _openAccessibilitySettings() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      var snapshot = _snapshot;
      if (snapshot == null) {
        await _refresh();
        if (!mounted) return;
        snapshot = _snapshot;
      }
      if (snapshot == null) {
        _showMessage('Couldn’t check tracking access. Try again first.');
        return;
      }

      if (!snapshot.consentAcknowledged) {
        final acknowledged = await showTrackingConsentDisclosure(context);
        if (!acknowledged || !mounted) return;
        await widget.trackingPlatform.setConsentAcknowledged(true);
      }
      await widget.trackingPlatform.setSelectedApps(widget.selectedAppIds);
      final opened = await widget.trackingPlatform.openAccessibilitySettings();
      if (!opened) {
        await _refresh();
        _showMessage('Couldn’t open Accessibility settings.');
      }
    } catch (_) {
      _showMessage('Accessibility settings are unavailable on this device.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openOverlaySettings() async {
    final snapshot = _snapshot;
    if (_busy || snapshot == null) return;
    if (!snapshot.bubbleEnabled) {
      _showMessage(
        'Turn on Floating counter in Settings to set up its access.',
      );
      return;
    }

    setState(() => _busy = true);
    try {
      final opened = await widget.trackingPlatform.openOverlaySettings();
      if (!opened) {
        await _refresh();
        _showMessage('Couldn’t open overlay settings.');
      }
    } catch (_) {
      _showMessage('Overlay settings are unavailable on this device.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openAppSettings(SupportedApp app) async {
    final state = _snapshot?.apps[app.id];
    if (_busy || state == null || !state.selected || !state.installed) return;
    setState(() => _busy = true);
    try {
      final opened = await widget.trackingPlatform.openSupportedAppSettings(
        app.id,
      );
      if (!opened) {
        _showMessage('Couldn’t open ${app.name} app settings.');
      }
    } catch (_) {
      _showMessage('App settings are unavailable on this device.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _returnToAppSelection() async {
    final openAppPicker = widget.onChangeApps;
    Navigator.of(context).pop();
    await Future<void>.delayed(const Duration(milliseconds: 280));
    await openAppPicker();
  }

  Future<void> _previewAndCopyReport() async {
    final snapshot = _snapshot;
    if (snapshot == null || _loadFailed) {
      _showMessage('Refresh status before creating a summary.');
      return;
    }
    final report = _diagnosticSummary(snapshot);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Review diagnostic summary'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              SelectableText(report, style: AppTypography.body),
              const SizedBox(height: AppSpacing.x4),
              Text(
                'Not included: counts, time spent, timestamps, device identifiers, feed content, screenshots, Accessibility trees, or item identifiers. Nothing is sent automatically.',
                style: AppTypography.supporting.copyWith(
                  color: Theme.of(dialogContext).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            icon: const AppIcon(icon: AppIcons.check),
            label: const Text('Copy summary'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await Clipboard.setData(ClipboardData(text: report));
      _showMessage('Diagnostic summary copied.');
    } catch (_) {
      _showMessage('Couldn’t copy the diagnostic summary.');
    }
  }

  String _diagnosticSummary(TrackingSnapshot snapshot) {
    final android = snapshot.androidVersion.isNotEmpty
        ? 'Android ${snapshot.androidVersion}'
        : 'Android version unavailable';
    final apiLevel = snapshot.androidApiLevel;
    final appVersion = snapshot.appVersion.isNotEmpty
        ? snapshot.appVersion
        : 'Unavailable';
    final lines = <String>[
      'Rooko: $appVersion',
      'Platform: $android${apiLevel == null ? '' : ' (API $apiLevel)'}',
      'Tracking consent: ${snapshot.consentAcknowledged ? 'Acknowledged' : 'Needs review'}',
      'Accessibility permission: ${snapshot.serviceEnabled ? 'Granted' : 'Not granted'}',
      'Accessibility service: ${snapshot.serviceOperational ? 'Running' : 'Not running'}',
      'Selected apps:',
    ];

    final selectedApps = SupportedApp.all
        .where((app) => snapshot.apps[app.id]?.selected == true)
        .toList();
    if (selectedApps.isEmpty) {
      lines.add('- None');
    }
    for (final app in selectedApps) {
      final state = snapshot.apps[app.id]!;
      final installation = !state.installed
          ? 'Not installed'
          : 'Installed ${state.versionName?.trim().isNotEmpty == true ? state.versionName : '(version unavailable)'}';
      final path = !state.installed
          ? 'No counting path available'
          : state.profileAvailable
          ? 'Profile available'
          : snapshot.consentAcknowledged && state.debugProfileAvailable
          ? 'Estimated path available'
          : 'No counting path available';
      lines.add('- ${app.name}: $installation; $path');
    }
    lines.add('Floating counter: ${snapshot.bubbleEnabled ? 'On' : 'Off'}');
    lines.add(
      'Overlay permission: ${snapshot.overlayPermissionGranted ? 'Granted' : 'Not granted'}',
    );
    lines.add(
      'Availability does not confirm current feed recognition or counting accuracy.',
    );
    return lines.join('\n');
  }

  String _appPathLabel(AppTrackingSnapshot? app, TrackingSnapshot snapshot) {
    if (app == null) return 'Status unavailable';
    if (!app.selected) return 'Not selected';
    if (!app.installed) return 'App is not installed';
    if (app.profileAvailable) return 'Profile available for this version';
    if (snapshot.consentAcknowledged && app.debugProfileAvailable) {
      return 'Estimated path available for this version';
    }
    return 'No counting path available for this version';
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final snapshot = _snapshot;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.x4,
            AppSpacing.x1,
            AppSpacing.x2,
            AppSpacing.x1,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Troubleshoot counting',
                  style: AppTypography.sectionTitle,
                ),
              ),
              IconButton(
                tooltip: 'Close troubleshooting',
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const AppIcon(icon: AppIcons.close),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.x4,
              AppSpacing.x2,
              AppSpacing.x4,
              AppSpacing.x8,
            ),
            children: [
              Text(
                'Check setup for the apps you selected. An available status does not guarantee that a feed is recognized or that every item is counted.',
                style: AppTypography.body.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
              if (_loading) ...[
                const SizedBox(height: AppSpacing.x4),
                const LinearProgressIndicator(),
              ],
              if (_loadFailed) ...[
                const SizedBox(height: AppSpacing.x4),
                _NoticeCard(
                  icon: AppIcons.warning,
                  title: 'Status unavailable',
                  message: 'Rooko couldn’t read the current setup status.',
                  actionLabel: 'Retry',
                  onAction: _refresh,
                ),
              ],
              if (snapshot != null && !_loadFailed) ...[
                const SizedBox(height: AppSpacing.x6),
                _SectionTitle(title: 'Tracking access'),
                _StatusCard(
                  children: [
                    _StatusRow(
                      icon: snapshot.consentAcknowledged
                          ? AppIcons.success
                          : AppIcons.warning,
                      title: 'Tracking disclosure',
                      detail: snapshot.consentAcknowledged
                          ? 'Reviewed and acknowledged'
                          : 'Review and acknowledge before enabling access',
                      status: snapshot.consentAcknowledged ? 'Ready' : 'Needed',
                    ),
                    const _StatusDivider(),
                    _StatusRow(
                      icon: snapshot.serviceEnabled
                          ? AppIcons.success
                          : AppIcons.permission,
                      title: 'Accessibility permission',
                      detail: snapshot.serviceEnabled
                          ? 'Granted in Android Settings'
                          : 'Not granted in Android Settings',
                      status: snapshot.serviceEnabled ? 'On' : 'Off',
                    ),
                    const _StatusDivider(),
                    _StatusRow(
                      icon: snapshot.serviceOperational
                          ? AppIcons.success
                          : AppIcons.warning,
                      title: 'Accessibility service',
                      detail: snapshot.serviceOperational
                          ? 'The service reports as running'
                          : 'The service is not currently running',
                      status: snapshot.serviceOperational
                          ? 'Running'
                          : 'Stopped',
                    ),
                    Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: TextButton.icon(
                        onPressed: _busy ? null : _openAccessibilitySettings,
                        icon: const AppIcon(icon: AppIcons.accessSettings),
                        label: Text(
                          snapshot.consentAcknowledged
                              ? 'Review Accessibility'
                              : 'Review disclosure',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.x6),
                _SectionTitle(title: 'Selected apps'),
                _StatusCard(
                  children: [
                    for (
                      var index = 0;
                      index < SupportedApp.all.length;
                      index++
                    ) ...[
                      if (index > 0) const _StatusDivider(),
                      _AppStatusRow(
                        app: SupportedApp.all[index],
                        snapshot: snapshot,
                        pathLabel: _appPathLabel(
                          snapshot.apps[SupportedApp.all[index].id],
                          snapshot,
                        ),
                        onOpenSettings: _busy
                            ? null
                            : () => _openAppSettings(SupportedApp.all[index]),
                      ),
                    ],
                    Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: TextButton.icon(
                        onPressed: _returnToAppSelection,
                        icon: const AppIcon(icon: AppIcons.sourceApp),
                        label: const Text('Change selected apps'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.x2),
                Text(
                  'Counting still depends on recognizing the selected Reels or Shorts feed and its item signals. This status does not confirm what is currently on screen.',
                  style: AppTypography.supporting.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.x6),
                _SectionTitle(title: 'Floating counter'),
                _StatusCard(
                  children: [
                    _StatusRow(
                      icon: snapshot.bubbleEnabled
                          ? AppIcons.success
                          : AppIcons.phone,
                      title: 'Counter preference',
                      detail: snapshot.bubbleEnabled ? 'Enabled' : 'Turned off',
                      status: snapshot.bubbleEnabled ? 'On' : 'Off',
                    ),
                    const _StatusDivider(),
                    _StatusRow(
                      icon: snapshot.overlayPermissionGranted
                          ? AppIcons.success
                          : AppIcons.warning,
                      title: 'Display over other apps',
                      detail: snapshot.overlayPermissionGranted
                          ? 'Permission is granted'
                          : 'Permission is not granted',
                      status: snapshot.overlayPermissionGranted ? 'On' : 'Off',
                    ),
                    if (snapshot.bubbleEnabled &&
                        !snapshot.overlayPermissionGranted)
                      Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: TextButton.icon(
                          onPressed: _busy ? null : _openOverlaySettings,
                          icon: const AppIcon(icon: AppIcons.accessSettings),
                          label: const Text('Open overlay settings'),
                        ),
                      ),
                    if (!snapshot.bubbleEnabled)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.x2),
                        child: Text(
                          'Turn on Floating counter in Settings if you want to use it.',
                          style: AppTypography.supporting.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.x6),
                _SectionTitle(title: 'Share a diagnostic summary'),
                Text(
                  'Review the setup details first. The summary stays on this device unless you choose to copy it.',
                  style: AppTypography.body.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.x2),
                FilledButton.icon(
                  onPressed: _loading || _loadFailed
                      ? null
                      : _previewAndCopyReport,
                  icon: const AppIcon(icon: AppIcons.export),
                  label: const Text('Review summary'),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.x2),
    child: Text(title, style: AppTypography.cardTitle),
  );
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Card(
    color: Theme.of(context).colorScheme.surfaceContainer,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadii.card),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.x4,
        vertical: AppSpacing.x2,
      ),
      child: Column(children: children),
    ),
  );
}

class _StatusDivider extends StatelessWidget {
  const _StatusDivider();

  @override
  Widget build(BuildContext context) => Divider(
    height: AppSpacing.x2,
    color: Theme.of(context).colorScheme.outlineVariant,
  );
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({
    required this.icon,
    required this.title,
    required this.detail,
    required this.status,
  });

  final AppIconData icon;
  final String title;
  final String detail;
  final String status;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.x2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 32,
            height: 32,
            child: Center(
              child: AppIcon(icon: icon, size: AppIconSizes.standard),
            ),
          ),
          const SizedBox(width: AppSpacing.x3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: AppSpacing.x2,
                  runSpacing: AppSpacing.x1,
                  children: [
                    Text(title, style: AppTypography.cardTitle),
                    Text(
                      status,
                      style: AppTypography.supporting.copyWith(
                        color: colors.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.x1),
                Text(
                  detail,
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

class _AppStatusRow extends StatelessWidget {
  const _AppStatusRow({
    required this.app,
    required this.snapshot,
    required this.pathLabel,
    required this.onOpenSettings,
  });

  final SupportedApp app;
  final TrackingSnapshot snapshot;
  final String pathLabel;
  final VoidCallback? onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final state = snapshot.apps[app.id];
    final selected = state?.selected == true;
    final version = state?.installed == true
        ? 'Version ${state?.versionName?.trim().isNotEmpty == true ? state!.versionName : 'unavailable'}'
        : 'Not installed';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.x2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Image.asset(
            app.iconAsset,
            width: 32,
            height: 32,
            fit: BoxFit.contain,
            excludeFromSemantics: true,
          ),
          const SizedBox(width: AppSpacing.x3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: AppSpacing.x2,
                  runSpacing: AppSpacing.x1,
                  children: [
                    Text(app.name, style: AppTypography.cardTitle),
                    Text(
                      selected ? 'Selected' : 'Not selected',
                      style: AppTypography.supporting.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.x1),
                Text(
                  version,
                  style: AppTypography.supporting.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                Text(
                  pathLabel,
                  style: AppTypography.supporting.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                if (selected && state?.installed == true)
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: TextButton.icon(
                      onPressed: onOpenSettings,
                      icon: const AppIcon(icon: AppIcons.externalLink),
                      label: const Text('App settings'),
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

class _NoticeCard extends StatelessWidget {
  const _NoticeCard({
    required this.icon,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final AppIconData icon;
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      color: colors.surfaceContainer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.card),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.x4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                AppIcon(icon: icon),
                const SizedBox(width: AppSpacing.x2),
                Expanded(child: Text(title, style: AppTypography.cardTitle)),
              ],
            ),
            const SizedBox(height: AppSpacing.x2),
            Text(message, style: AppTypography.body),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton(onPressed: onAction, child: Text(actionLabel)),
            ),
          ],
        ),
      ),
    );
  }
}
