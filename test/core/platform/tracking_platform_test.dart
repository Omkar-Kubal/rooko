import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rooko/core/models/progress.dart';
import 'package:rooko/core/platform/tracking_platform.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.heykakaa.rooko/tracking_v1');
  late MethodChannelTrackingPlatform platform;

  setUp(() {
    platform = MethodChannelTrackingPlatform(channel: channel);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('one shared product total includes persisted event categories', () {
    const youtube = AppTrackingSnapshot(
      appId: 'youtube',
      selected: true,
      installed: true,
      versionName: '21.45.82',
      profileAvailable: false,
      confidence: TrackingConfidence.estimated,
      confirmedCount: 2,
      estimatedCount: 5,
    );
    const instagram = AppTrackingSnapshot(
      appId: 'instagram',
      selected: true,
      installed: true,
      versionName: '455.0.0.51.72',
      profileAvailable: false,
      confidence: TrackingConfidence.estimated,
      confirmedCount: 1,
      estimatedCount: 4,
    );
    const unselected = AppTrackingSnapshot(
      appId: 'unselected_app',
      selected: false,
      installed: true,
      versionName: '40.0.0',
      profileAvailable: true,
      confidence: TrackingConfidence.confirmed,
      confirmedCount: 20,
      estimatedCount: 0,
    );
    const snapshot = TrackingSnapshot(
      serviceEnabled: true,
      serviceOperational: true,
      checkedAtMillis: 0,
      localDate: '2026-11-13',
      apps: {
        'youtube': youtube,
        'instagram': instagram,
        'unselected_app': unselected,
      },
    );
    final progressDay = ProgressDay(
      localDate: DateTime(2026, 11, 13),
      timeZoneId: null,
      offsetSeconds: null,
      coverage: ProgressCoverage.unknown,
      coverageReason: null,
      lastDetectionAtMillis: 0,
      apps: [
        ProgressAppTotal(
          appId: 'youtube',
          confirmedCount: 2,
          estimatedCount: 5,
          correctionDelta: 0,
          adjustedConfirmedCount: 2,
          correctionCount: 0,
          pendingUndoCorrectionId: null,
        ),
        ProgressAppTotal(
          appId: 'instagram',
          confirmedCount: 1,
          estimatedCount: 4,
          correctionDelta: 0,
          adjustedConfirmedCount: 1,
          correctionCount: 0,
          pendingUndoCorrectionId: null,
        ),
      ],
    );

    expect(snapshot.selectedCountedCount, 12);
    expect(progressDay.countedCount, 12);
  });

  test('progress total includes all persisted event categories', () {
    const youtube = ProgressAppTotal(
      appId: 'youtube',
      confirmedCount: 2,
      estimatedCount: 5,
      correctionDelta: 0,
      adjustedConfirmedCount: 2,
      correctionCount: 0,
      pendingUndoCorrectionId: null,
    );

    expect(youtube.countedCount, 7);
  });

  test('sends only supported app ids in stable order', () async {
    MethodCall? received;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          received = call;
          return null;
        });

    await platform.setSelectedApps({'youtube', 'instagram', 'not-an-app'});

    expect(received?.method, 'setSelectedApps');
    expect((received?.arguments as Map<Object?, Object?>)['appIds'], [
      'instagram',
      'youtube',
    ]);
  });

  test(
    'persists affirmative consent before requesting Android access',
    () async {
      MethodCall? received;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            received = call;
            return null;
          });

      await platform.setConsentAcknowledged(true);

      expect(received?.method, 'setTrackingConsentAcknowledged');
      expect(
        (received?.arguments as Map<Object?, Object?>)['acknowledged'],
        isTrue,
      );
    },
  );

  test(
    'returns the native result instead of assuming Settings granted access',
    () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            expect(call.method, 'openAccessibilitySettings');
            return false;
          });

      expect(await platform.openAccessibilitySettings(), isFalse);
    },
  );

  test(
    'sends optional counter setting and reads actual overlay access',
    () async {
      MethodCall? received;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            received = call;
            if (call.method == 'openOverlaySettings') {
              return true;
            }
            if (call.method == 'getTrackingSnapshot') {
              return <String, Object?>{
                'bubbleEnabled': true,
                'overlayPermissionGranted': false,
              };
            }
            return null;
          });

      await platform.setBubbleEnabled(true);
      expect(received?.method, 'setBubbleEnabled');
      expect((received?.arguments as Map<Object?, Object?>)['enabled'], isTrue);
      expect(await platform.openOverlaySettings(), isTrue);
      final snapshot = await platform.getSnapshot({});
      expect(snapshot.bubbleEnabled, isTrue);
      expect(snapshot.overlayPermissionGranted, isFalse);
    },
  );

  test('parses real access state and stored daily counts', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          expect(call.method, 'getTrackingSnapshot');
          return <String, Object?>{
            'serviceEnabled': true,
            'serviceOperational': true,
            'consentAcknowledged': true,
            'checkedAtMillis': 1_800_000_000_000,
            'lastDetectionAtMillis': 1_799_999_999_000,
            'lastValidatedFeedExitAtMillis': 1_799_999_998_000,
            'localDate': '2026-11-06',
            'apps': [
              <String, Object?>{
                'appId': 'youtube',
                'selected': true,
                'installed': true,
                'versionName': '21.43.523',
                'profileAvailable': true,
                'confidence': 'estimated',
                'confirmedCount': 0,
                'estimatedCount': 3,
              },
            ],
          };
        });

    final snapshot = await platform.getSnapshot({'youtube'});

    expect(snapshot.serviceEnabled, isTrue);
    expect(snapshot.consentAcknowledged, isTrue);
    expect(snapshot.localDate, '2026-11-06');
    expect(snapshot.lastDetectionAtMillis, 1_799_999_999_000);
    expect(snapshot.lastValidatedFeedExitAtMillis, 1_799_999_998_000);
    expect(snapshot.selectedConfirmedCount, 0);
    expect(snapshot.selectedEstimatedCount, 3);
    expect(snapshot.apps['youtube']?.confidence, TrackingConfidence.estimated);
    expect(snapshot.coverageLabel, 'Available');
  });

  test('uses adjusted confirmed totals in the Today snapshot', () {
    final snapshot = TrackingSnapshot.fromMap({
      'serviceEnabled': true,
      'serviceOperational': true,
      'consentAcknowledged': true,
      'localDate': '2026-11-06',
      'apps': [
        {
          'appId': 'instagram',
          'selected': true,
          'installed': true,
          'versionName': '454.0.0.54.77',
          'profileAvailable': true,
          'confidence': 'confirmed',
          'confirmedCount': 2,
          'adjustedConfirmedCount': 1,
          'estimatedCount': 0,
        },
      ],
    });

    expect(snapshot.selectedConfirmedCount, 1);
    expect(snapshot.apps['instagram']?.confirmedCount, 2);
  });

  test(
    'queries Room progress with actual per-app confidence and unknown metadata',
    () async {
      MethodCall? received;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            received = call;
            return <String, Object?>{
              'schemaVersion': 1,
              'checkedAtMillis': 1_800_000_000_000,
              'days': [
                <String, Object?>{
                  'localDate': '2026-11-06',
                  'timeZoneId': null,
                  'offsetSeconds': null,
                  'coverage': 'unknown',
                  'coverageReason': null,
                  'lastDetectionAtMillis': 0,
                  'countedTimes': [
                    <String, Object?>{
                      'appId': 'instagram',
                      'wallClockMillis':
                          DateTime.utc(
                            2026,
                            11,
                            6,
                            17,
                            12,
                            34,
                          ).millisecondsSinceEpoch -
                          19_800_000,
                      'offsetSeconds': 19_800,
                    },
                  ],
                  'apps': [
                    <String, Object?>{
                      'appId': 'instagram',
                      'confirmedCount': 2,
                      'estimatedCount': 3,
                      'correctionDelta': -1,
                      'adjustedConfirmedCount': 1,
                      'correctionCount': 1,
                      'pendingUndoCorrectionId': 'correction-1',
                    },
                  ],
                },
              ],
            };
          });

      final progress = await platform.queryProgress(
        DateTime(2026, 11, 3),
        DateTime(2026, 11, 9),
      );

      expect(received?.method, 'queryProgress');
      expect(
        (received?.arguments as Map<Object?, Object?>)['startDate'],
        '2026-11-03',
      );
      expect(progress.days.single.timeZoneId, isNull);
      expect(progress.days.single.coverage, ProgressCoverage.unknown);
      final observed = progress.days.single.countedTimes.single;
      expect(observed.appId, 'instagram');
      expect(observed.recordedLocalTime.hour, 17);
      expect(observed.recordedLocalTime.minute, 12);
      expect(observed.recordedLocalTime.second, 34);
      expect(progress.days.single.app('instagram')?.adjustedConfirmedCount, 1);
      expect(progress.days.single.app('instagram')?.estimatedCount, 3);
      expect(
        progress.days.single.app('instagram')?.pendingUndoCorrectionId,
        'correction-1',
      );
    },
  );

  test('adds and reverses an app-scoped append-only correction', () async {
    final methods = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          methods.add(call.method);
          if (call.method == 'addCorrection') {
            expect(call.arguments, {
              'localDate': '2026-11-06',
              'appId': 'instagram',
              'delta': 1,
              'reason': null,
            });
          }
          return <String, Object?>{
            'schemaVersion': 1,
            'correction': <String, Object?>{
              'id': call.method == 'addCorrection' ? 'added' : 'reversal',
              'localDate': '2026-11-06',
              'appId': 'instagram',
              'delta': call.method == 'addCorrection' ? 1 : -1,
              'createdAtMillis': 1_800_000_000_000,
              'reversesCorrectionId': call.method == 'undoCorrection'
                  ? 'added'
                  : null,
            },
          };
        });

    final added = await platform.addCorrection(
      localDate: '2026-11-06',
      appId: 'instagram',
      delta: 1,
    );
    final reversed = await platform.undoCorrection('added');

    expect(methods, ['addCorrection', 'undoCorrection']);
    expect(added.delta, 1);
    expect(reversed.delta, -1);
    expect(reversed.reversesCorrectionId, 'added');
  });

  test('reports access needs attention when service is not operational', () {
    final snapshot = TrackingSnapshot.fromMap({
      'serviceEnabled': true,
      'serviceOperational': false,
      'serviceInterruptedToday': false,
      'consentAcknowledged': true,
      'checkedAtMillis': 1_800_000_000_000,
      'localDate': '2026-11-07',
      'apps': [
        <String, Object?>{
          'appId': 'youtube',
          'selected': true,
          'installed': true,
          'versionName': '21.43.523',
          'profileAvailable': true,
          'confidence': 'confirmed',
          'confirmedCount': 0,
          'estimatedCount': 0,
        },
      ],
    });

    expect(snapshot.serviceEnabled, isTrue);
    expect(snapshot.coverageLabel, 'Access needs attention');
  });

  test('reports access needs attention after a service interruption', () {
    final snapshot = TrackingSnapshot.fromMap({
      'serviceEnabled': true,
      'serviceOperational': true,
      'serviceInterruptedToday': true,
      'consentAcknowledged': true,
      'localDate': '2026-11-07',
      'apps': [
        <String, Object?>{
          'appId': 'youtube',
          'selected': true,
          'installed': true,
          'versionName': '21.43.523',
          'profileAvailable': true,
          'confidence': 'confirmed',
          'confirmedCount': 0,
          'estimatedCount': 0,
        },
      ],
    });

    expect(snapshot.coverageLabel, 'Access needs attention');
  });
}
