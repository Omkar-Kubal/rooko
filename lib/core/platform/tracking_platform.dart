import 'package:flutter/services.dart';

import '../models/progress.dart';
import '../models/supported_app.dart';

enum TrackingConfidence { confirmed, estimated }

enum SupportEmailKind { featureRequest, support }

class AppTrackingSnapshot {
  const AppTrackingSnapshot({
    required this.appId,
    required this.selected,
    required this.installed,
    required this.versionName,
    required this.profileAvailable,
    this.debugProfileAvailable = false,
    required this.confidence,
    required this.confirmedCount,
    int? adjustedConfirmedCount,
    required this.estimatedCount,
  }) : adjustedConfirmedCount = adjustedConfirmedCount ?? confirmedCount;

  final String appId;
  final bool selected;
  final bool installed;
  final String? versionName;
  final bool profileAvailable;
  final bool debugProfileAvailable;
  final TrackingConfidence? confidence;
  final int confirmedCount;
  final int adjustedConfirmedCount;
  final int estimatedCount;

  /// Counts every event stored for this app and local date.
  int get countedCount => confirmedCount + estimatedCount;

  String get supportLabel {
    if (!installed) return 'Not installed';
    if (!profileAvailable && debugProfileAvailable) {
      return 'Estimated counting available';
    }
    if (!profileAvailable) return 'Unsupported app version';
    return 'Available';
  }

  factory AppTrackingSnapshot.fromMap(Map<String, Object?> map) {
    final confidenceName = map['confidence'] as String?;
    return AppTrackingSnapshot(
      appId: map['appId'] as String? ?? '',
      selected: map['selected'] as bool? ?? false,
      installed: map['installed'] as bool? ?? false,
      versionName: map['versionName'] as String?,
      profileAvailable: map['profileAvailable'] as bool? ?? false,
      debugProfileAvailable: map['debugProfileAvailable'] as bool? ?? false,
      confidence: switch (confidenceName) {
        'confirmed' => TrackingConfidence.confirmed,
        'estimated' => TrackingConfidence.estimated,
        _ => null,
      },
      confirmedCount: _intValue(map['confirmedCount']),
      adjustedConfirmedCount: map.containsKey('adjustedConfirmedCount')
          ? _intValue(map['adjustedConfirmedCount'])
          : _intValue(map['confirmedCount']),
      estimatedCount: _intValue(map['estimatedCount']),
    );
  }
}

class TrackingSnapshot {
  const TrackingSnapshot({
    required this.serviceEnabled,
    required this.serviceOperational,
    this.serviceInterruptedToday = false,
    this.consentAcknowledged = false,
    this.bubbleEnabled = false,
    this.debugCountingEnabled = false,
    this.overlayPermissionGranted = false,
    this.appVersion = '',
    this.androidVersion = '',
    this.androidApiLevel,
    required this.checkedAtMillis,
    this.lastDetectionAtMillis = 0,
    this.lastValidatedFeedExitAtMillis = 0,
    required this.localDate,
    required this.apps,
  });

  final bool serviceEnabled;
  final bool serviceOperational;
  final bool serviceInterruptedToday;
  final bool consentAcknowledged;
  final bool bubbleEnabled;
  final bool debugCountingEnabled;
  final bool overlayPermissionGranted;
  final String appVersion;
  final String androidVersion;
  final int? androidApiLevel;
  final int checkedAtMillis;
  final int lastDetectionAtMillis;
  final int lastValidatedFeedExitAtMillis;
  final String localDate;
  final Map<String, AppTrackingSnapshot> apps;

  int get selectedConfirmedCount => apps.values
      .where((app) => app.selected)
      .fold(0, (total, app) => total + app.adjustedConfirmedCount);

  int get selectedEstimatedCount => apps.values
      .where((app) => app.selected)
      .fold(0, (total, app) => total + app.estimatedCount);

  int get selectedCountedCount => apps.values
      .where((app) => app.selected)
      .fold(0, (total, app) => total + app.countedCount);

  bool get monitoringAvailable =>
      consentAcknowledged &&
      serviceEnabled &&
      serviceOperational &&
      apps.values.any(
        (app) =>
            app.selected &&
            (app.profileAvailable ||
                (debugCountingEnabled && app.debugProfileAvailable)),
      );

  String get coverageLabel {
    if (!consentAcknowledged || !serviceEnabled) return 'Access needed';
    final selected = apps.values.where((app) => app.selected).toList();
    if (selected.isEmpty) return 'No apps selected';
    bool available(AppTrackingSnapshot app) =>
        app.profileAvailable ||
        (debugCountingEnabled && app.debugProfileAvailable);
    if (selected.every((app) => !app.installed || !available(app))) {
      return 'Versions unavailable';
    }
    if (!serviceOperational || serviceInterruptedToday) {
      return 'Access needs attention';
    }
    if (selected.any((app) => !app.installed || !available(app))) {
      return 'Some apps unavailable';
    }
    return 'Available';
  }

  factory TrackingSnapshot.fromMap(Map<String, Object?> map) {
    final appRows = map['apps'] is List ? map['apps'] as List : const [];
    final apps = <String, AppTrackingSnapshot>{};
    for (final row in appRows) {
      if (row is! Map) continue;
      final app = AppTrackingSnapshot.fromMap(
        row.map((key, value) => MapEntry(key.toString(), value)),
      );
      if (SupportedApp.byId(app.appId) != null) apps[app.appId] = app;
    }

    return TrackingSnapshot(
      serviceEnabled: map['serviceEnabled'] as bool? ?? false,
      serviceOperational: map['serviceOperational'] as bool? ?? false,
      serviceInterruptedToday: map['serviceInterruptedToday'] as bool? ?? false,
      consentAcknowledged: map['consentAcknowledged'] as bool? ?? false,
      bubbleEnabled: map['bubbleEnabled'] as bool? ?? false,
      debugCountingEnabled: map['debugCountingEnabled'] as bool? ?? false,
      overlayPermissionGranted:
          map['overlayPermissionGranted'] as bool? ?? false,
      appVersion: map['appVersion'] as String? ?? '',
      androidVersion: map['androidVersion'] as String? ?? '',
      androidApiLevel: (map['androidApiLevel'] as num?)?.toInt(),
      checkedAtMillis: _intValue(map['checkedAtMillis']),
      lastDetectionAtMillis: _intValue(map['lastDetectionAtMillis']),
      lastValidatedFeedExitAtMillis: _intValue(
        map['lastValidatedFeedExitAtMillis'],
      ),
      localDate: map['localDate'] as String? ?? '',
      apps: apps,
    );
  }
}

abstract interface class TrackingPlatform {
  Future<void> setSelectedApps(Set<String> appIds);

  Future<void> setConsentAcknowledged(bool acknowledged);

  Future<void> setBubbleEnabled(bool enabled);

  Future<bool> openOverlaySettings();

  Future<bool> openAccessibilitySettings();

  Future<bool> openSupportedApp(String appId);

  Future<bool> openSupportedAppSettings(String appId);

  Future<bool> openSupportEmail(SupportEmailKind kind);

  Future<TrackingSnapshot> getSnapshot(Set<String> appIds);

  Future<ProgressRange> queryProgress(DateTime startDate, DateTime endDate);

  Future<ProgressCorrection> addCorrection({
    required String localDate,
    required String appId,
    required int delta,
    String? reason,
  });

  Future<ProgressCorrection> undoCorrection(String correctionId);
}

class ProgressPlatformException implements Exception {
  const ProgressPlatformException(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => message;
}

class MethodChannelTrackingPlatform implements TrackingPlatform {
  const MethodChannelTrackingPlatform({
    this.channel = const MethodChannel(channelName),
  });

  static const channelName = 'com.heykakaa.rooko/tracking_v1';

  final MethodChannel channel;

  @override
  Future<void> setSelectedApps(Set<String> appIds) async {
    final supportedIds =
        appIds.where((appId) => SupportedApp.byId(appId) != null).toList()
          ..sort();
    await channel.invokeMethod<void>('setSelectedApps', <String, Object?>{
      'appIds': supportedIds,
    });
  }

  @override
  Future<void> setConsentAcknowledged(bool acknowledged) async {
    await channel.invokeMethod<void>(
      'setTrackingConsentAcknowledged',
      <String, Object?>{'acknowledged': acknowledged},
    );
  }

  @override
  Future<void> setBubbleEnabled(bool enabled) async {
    await channel.invokeMethod<void>('setBubbleEnabled', <String, Object?>{
      'enabled': enabled,
    });
  }

  @override
  Future<bool> openOverlaySettings() async =>
      await channel.invokeMethod<bool>('openOverlaySettings') ?? false;

  @override
  Future<bool> openAccessibilitySettings() async =>
      await channel.invokeMethod<bool>('openAccessibilitySettings') ?? false;

  @override
  Future<bool> openSupportedApp(String appId) async {
    if (SupportedApp.byId(appId) == null) return false;
    return await channel.invokeMethod<bool>(
          'openSupportedApp',
          <String, Object?>{'appId': appId},
        ) ??
        false;
  }

  @override
  Future<bool> openSupportedAppSettings(String appId) async {
    if (SupportedApp.byId(appId) == null) return false;
    return await channel.invokeMethod<bool>(
          'openSupportedAppSettings',
          <String, Object?>{'appId': appId},
        ) ??
        false;
  }

  @override
  Future<bool> openSupportEmail(SupportEmailKind kind) async =>
      await channel.invokeMethod<bool>('openSupportEmail', <String, Object?>{
        'kind': switch (kind) {
          SupportEmailKind.featureRequest => 'feature_request',
          SupportEmailKind.support => 'support',
        },
      }) ??
      false;

  @override
  Future<TrackingSnapshot> getSnapshot(Set<String> appIds) async {
    final supportedIds =
        appIds.where((appId) => SupportedApp.byId(appId) != null).toList()
          ..sort();
    final map = await channel.invokeMapMethod<String, Object?>(
      'getTrackingSnapshot',
      <String, Object?>{'appIds': supportedIds},
    );
    return TrackingSnapshot.fromMap(map ?? const <String, Object?>{});
  }

  @override
  Future<ProgressRange> queryProgress(
    DateTime startDate,
    DateTime endDate,
  ) async {
    final map = await channel.invokeMapMethod<String, Object?>(
      'queryProgress',
      <String, Object?>{
        'startDate': _dateKey(startDate),
        'endDate': _dateKey(endDate),
      },
    );
    return ProgressRange.fromMap(map ?? const <String, Object?>{});
  }

  @override
  Future<ProgressCorrection> addCorrection({
    required String localDate,
    required String appId,
    required int delta,
    String? reason,
  }) async {
    try {
      final map = await channel.invokeMapMethod<String, Object?>(
        'addCorrection',
        <String, Object?>{
          'localDate': localDate,
          'appId': appId,
          'delta': delta,
          'reason': reason,
        },
      );
      return _correctionFromResponse(map);
    } on PlatformException catch (error) {
      throw ProgressPlatformException(
        error.code,
        error.message ?? 'Correction could not be saved.',
      );
    }
  }

  @override
  Future<ProgressCorrection> undoCorrection(String correctionId) async {
    try {
      final map = await channel.invokeMapMethod<String, Object?>(
        'undoCorrection',
        <String, Object?>{'correctionId': correctionId},
      );
      return _correctionFromResponse(map);
    } on PlatformException catch (error) {
      throw ProgressPlatformException(
        error.code,
        error.message ?? 'Correction could not be undone.',
      );
    }
  }

  ProgressCorrection _correctionFromResponse(Map<String, Object?>? map) {
    if (map == null || map['schemaVersion'] != 1 || map['correction'] is! Map) {
      throw const FormatException('Invalid correction response from Android.');
    }
    final row = (map['correction'] as Map).map(
      (key, value) => MapEntry(key.toString(), value),
    );
    return ProgressCorrection.fromMap(row);
  }
}

int _intValue(Object? value) => value is num ? value.toInt() : 0;

String _dateKey(DateTime date) {
  final year = date.year.toString().padLeft(4, '0');
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}
