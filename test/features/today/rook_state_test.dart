import 'package:flutter_test/flutter_test.dart';
import 'package:rooko/core/platform/tracking_platform.dart';
import 'package:rooko/features/today/rook_state.dart';

void main() {
  group('RookState.fromCount', () {
    test('uses the five approved count bands at their boundaries', () {
      expect(RookState.fromCount(0), RookState.ready);
      expect(RookState.fromCount(49), RookState.ready);
      expect(RookState.fromCount(50), RookState.strained);
      expect(RookState.fromCount(99), RookState.strained);
      expect(RookState.fromCount(100), RookState.injured);
      expect(RookState.fromCount(149), RookState.injured);
      expect(RookState.fromCount(150), RookState.queasy);
      expect(RookState.fromCount(199), RookState.queasy);
      expect(RookState.fromCount(200), RookState.vomiting);
      expect(RookState.fromCount(1000), RookState.vomiting);
    });

    test('rejects a negative combined count', () {
      expect(() => RookState.fromCount(-1), throwsArgumentError);
    });
  });

  test('shared Rive inputs select only their matching count pose', () {
    for (final state in RookState.values) {
      expect(state.isStrainedInput, state == RookState.strained);
      expect(state.isInjuredInput, state == RookState.injured);
      expect(state.isQueasyInput, state == RookState.queasy);
    }
  });

  test('shared Rive inputs select only their matching count pose', () {
    for (final state in RookState.values) {
      expect(state.isStrainedInput, state == RookState.strained);
      expect(state.isInjuredInput, state == RookState.injured);
      expect(state.isQueasyInput, state == RookState.queasy);
    }
  });

  group('RookState.forToday', () {
    test('Sleeping takes precedence when monitoring is unavailable', () {
      expect(
        RookState.forToday(
          count: 200,
          monitoringAvailable: false,
          recovering: true,
        ),
        RookState.sleeping,
      );
    });

    test('Recovering briefly takes precedence over the count pose', () {
      expect(
        RookState.forToday(
          count: 150,
          monitoringAvailable: true,
          recovering: true,
        ),
        RookState.recovering,
      );
      expect(
        RookState.forToday(
          count: 150,
          monitoringAvailable: true,
          recovering: false,
        ),
        RookState.queasy,
      );
    });
  });

  test('feed exit opens a 600 ms recovery window only for a recent signal', () {
    final window = RookRecoveryWindow.fromSignal(
      signalAtMillis: 1000,
      observedAtMillis: 1200,
    );

    expect(window, isNotNull);
    expect(window!.isActiveAt(1799), isTrue);
    expect(window.isActiveAt(1800), isFalse);
    expect(
      RookRecoveryWindow.fromSignal(
        signalAtMillis: 1000,
        observedAtMillis: 4001,
      ),
      isNull,
    );
    expect(
      RookRecoveryWindow.fromSignal(
        signalAtMillis: 1300,
        observedAtMillis: 1200,
      ),
      isNull,
    );
  });

  test('monitoring is available only with a selected validated profile', () {
    const available = TrackingSnapshot(
      serviceEnabled: true,
      serviceOperational: true,
      consentAcknowledged: true,
      overlayPermissionGranted: false,
      checkedAtMillis: 0,
      localDate: '2026-11-14',
      apps: {
        'youtube': AppTrackingSnapshot(
          appId: 'youtube',
          selected: true,
          installed: true,
          versionName: '21.43.523',
          profileAvailable: true,
          confidence: TrackingConfidence.confirmed,
          confirmedCount: 0,
          estimatedCount: 0,
        ),
      },
    );
    const unsupported = TrackingSnapshot(
      serviceEnabled: true,
      serviceOperational: true,
      consentAcknowledged: true,
      checkedAtMillis: 0,
      localDate: '2026-11-14',
      apps: {
        'youtube': AppTrackingSnapshot(
          appId: 'youtube',
          selected: true,
          installed: true,
          versionName: 'unknown',
          profileAvailable: false,
          confidence: null,
          confirmedCount: 0,
          estimatedCount: 0,
        ),
      },
    );

    expect(available.monitoringAvailable, isTrue);
    expect(unsupported.monitoringAvailable, isFalse);
    expect(
      const TrackingSnapshot(
        serviceEnabled: true,
        serviceOperational: true,
        consentAcknowledged: true,
        checkedAtMillis: 0,
        localDate: '2026-11-14',
        apps: {},
      ).monitoringAvailable,
      isFalse,
    );
  });
}
