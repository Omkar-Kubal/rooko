import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rooko/core/design_system/app_theme.dart';
import 'package:rooko/core/design_system/app_icons.dart';
import 'package:rooko/core/models/progress.dart';
import 'package:rooko/core/platform/tracking_platform.dart';
import 'package:rooko/features/today/today_home_screen.dart';
import 'package:rooko/features/today/welcome_overlay.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'dark selected Progress icon uses near-black fill and white icon',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(432, 960);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: TodayHomeScreen(trackingPlatform: FakeTodayTrackingPlatform()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('top-nav-progress')));
      await tester.pumpAndSettle();
      final selected = find.byKey(const ValueKey('top-nav-progress'));
      final material = tester.widget<Material>(
        find.descendant(of: selected, matching: find.byType(Material)),
      );
      expect(material.color, isNot(Colors.white));
      expect(material.color!.computeLuminance(), lessThan(0.05));
      expect(
        Theme.of(tester.element(selected)).colorScheme.onPrimary,
        Colors.white,
      );
      expect(
        tester
            .widget<AppIcon>(
              find.descendant(of: selected, matching: find.byType(AppIcon)),
            )
            .color,
        Colors.white,
      );
    },
  );

  testWidgets('missing access shows a wall that routes to Settings', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'rooko_selected_supported_apps': ['youtube'],
    });
    final tracking = FakeTodayTrackingPlatform()
      ..serviceEnabled = false
      ..serviceOperational = false;

    await _pumpToday(tester, tracking);

    expect(find.byKey(const ValueKey('today-permission-wall')), findsOneWidget);
    expect(find.byKey(const ValueKey('permission-wall-allow')), findsOneWidget);
    expect(find.byKey(const ValueKey('top-nav-progress')), findsNothing);
    expect(find.text('Tracking is off'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('permission-wall-allow')));
    await tester.pumpAndSettle();

    expect(find.text('Accessibility access'), findsOneWidget);
  });

  testWidgets('first-run welcome closes once and stays dismissed', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'rooko_home_welcome_pending': true,
    });
    await _pumpToday(tester, FakeTodayTrackingPlatform());

    expect(find.byKey(const ValueKey('new-user-welcome')), findsOneWidget);
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.byKey(const ValueKey('welcome-confetti')), findsNothing);
    expect(find.text('Welcome to\nRooko'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('welcome-continue')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('new-user-welcome')), findsNothing);
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getBool('rooko_home_welcome_pending'), isFalse);

    await tester.pumpWidget(const SizedBox.shrink());
    await _pumpToday(tester, FakeTodayTrackingPlatform());
    expect(find.byKey(const ValueKey('new-user-welcome')), findsNothing);
    expect(find.byType(BottomSheet), findsNothing);
  });

  testWidgets('welcome close control clears the first-run flag', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'rooko_home_welcome_pending': true,
    });
    await _pumpToday(tester, FakeTodayTrackingPlatform());
    await tester.tap(find.byKey(const ValueKey('welcome-close')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('new-user-welcome')), findsNothing);
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getBool('rooko_home_welcome_pending'), isFalse);
  });

  testWidgets('Android Back dismisses the welcome', (tester) async {
    SharedPreferences.setMockInitialValues({
      'rooko_home_welcome_pending': true,
    });
    await _pumpToday(tester, FakeTodayTrackingPlatform());
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('new-user-welcome')), findsNothing);
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getBool('rooko_home_welcome_pending'), isFalse);
  });

  testWidgets('tapping outside the welcome sheet dismisses it', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'rooko_home_welcome_pending': true,
    });
    await _pumpToday(tester, FakeTodayTrackingPlatform());
    await tester.tapAt(const Offset(216, 40));
    await tester.pumpAndSettle();

    expect(find.byType(BottomSheet), findsNothing);
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getBool('rooko_home_welcome_pending'), isFalse);
  });

  testWidgets('welcome confetti pauses in background and resumes once', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: const MediaQuery(
          data: MediaQueryData(disableAnimations: false),
          child: Scaffold(body: WelcomeBottomSheet()),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 240));
    expect(find.byKey(const ValueKey('welcome-confetti')), findsOneWidget);
    expect(tester.hasRunningAnimations, isTrue);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(tester.hasRunningAnimations, isFalse);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(tester.hasRunningAnimations, isTrue);
    await tester.pumpAndSettle();
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('reduced motion omits welcome confetti', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: const MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: Scaffold(body: WelcomeBottomSheet()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('welcome-confetti')), findsNothing);
    expect(find.byKey(const ValueKey('welcome-continue')), findsOneWidget);
  });

  testWidgets('X collapses the access wall to a banner with an Allow action', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'rooko_selected_supported_apps': ['youtube'],
    });
    final tracking = FakeTodayTrackingPlatform()
      ..serviceEnabled = false
      ..serviceOperational = false;

    await _pumpToday(tester, tracking);
    await tester.tap(find.byKey(const ValueKey('permission-wall-dismiss')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('today-permission-wall')), findsNothing);
    expect(
      find.byKey(const ValueKey('today-permission-banner')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('permission-banner-allow')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('top-nav-progress')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('permission-banner-allow')));
    await tester.pumpAndSettle();
    expect(find.text('Accessibility access'), findsOneWidget);
  });

  testWidgets(
    'a recovered service does not show an access wall for a past gap',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        'rooko_selected_supported_apps': ['youtube'],
      });
      final tracking = FakeTodayTrackingPlatform()
        ..serviceEnabled = true
        ..serviceOperational = true
        ..serviceInterruptedToday = true;

      await _pumpToday(tester, tracking);

      expect(find.byKey(const ValueKey('today-permission-wall')), findsNothing);
      expect(
        find.byKey(const ValueKey('today-permission-banner')),
        findsNothing,
      );
      expect(find.text('Allow access in Settings'), findsNothing);
      expect(find.text('5'), findsWidgets);
    },
  );

  testWidgets(
    'Today shows the combined total with app attribution and no diagnostics',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        'rooko_selected_supported_apps': ['youtube', 'instagram'],
        'rooko_daily_limit': 42,
      });
      final tracking = FakeTodayTrackingPlatform()
        ..confirmedCount = 2
        ..estimatedCount = 3
        ..instagramConfirmedCount = 4
        ..instagramEstimatedCount = 0;

      await _pumpToday(tester, tracking);

      expect(find.text('9'), findsOneWidget);
      expect(find.text('Reels and Shorts counted today'), findsOneWidget);
      expect(find.byKey(const ValueKey('today-limit-summary')), findsNothing);
      expect(find.byKey(const ValueKey('today-app-counts')), findsOneWidget);
      expect(find.bySemanticsLabel('YouTube Shorts, 5'), findsOneWidget);
      expect(find.bySemanticsLabel('Instagram, 4'), findsOneWidget);
      expect(find.textContaining('estimated'), findsNothing);
      expect(find.textContaining('partial'), findsNothing);
      expect(find.textContaining('confirmed'), findsNothing);
      expect(find.text('Last access check'), findsNothing);
      expect(find.text('Last detection'), findsNothing);
      expect(find.text('Tracking is off'), findsNothing);
    },
  );

  testWidgets('estimated counting makes Ready available without a note', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'rooko_selected_supported_apps': ['youtube'],
    });
    final tracking = FakeTodayTrackingPlatform()
      ..profileAvailable = false
      ..debugProfileAvailable = true
      ..debugCountingEnabled = true;

    await _pumpToday(tester, tracking);

    expect(find.bySemanticsLabel('Ready Rook'), findsOneWidget);
    expect(find.text('Counts may vary by app version'), findsNothing);
  });

  testWidgets('Ready Rook sits at the vertical center of the Today viewport', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'rooko_selected_supported_apps': ['youtube'],
    });
    final tracking = FakeTodayTrackingPlatform();

    await _pumpToday(tester, tracking);

    final rook = find.bySemanticsLabel('Ready Rook');
    final center = tester.getCenter(rook);
    expect(center.dx, closeTo(tester.view.physicalSize.width / 2, 2));
    expect(
      center.dy,
      inInclusiveRange(
        tester.view.physicalSize.height * 0.42,
        tester.view.physicalSize.height * 0.58,
      ),
    );
  });

  testWidgets(
    'daily limit controls stay hidden and legacy values are retained',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        'rooko_selected_supported_apps': ['youtube'],
        'rooko_daily_limit': 42,
      });
      final tracking = FakeTodayTrackingPlatform();

      await _pumpToday(tester, tracking);

      expect(find.text('Set a limit'), findsNothing);
      expect(find.text('Edit'), findsNothing);

      await tester.tap(find.byKey(const ValueKey('top-nav-settings')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('settings-limit-edit')), findsNothing);
      expect(await SharedPreferences.getInstance(), isNotNull);
      expect(
        (await SharedPreferences.getInstance()).getInt('rooko_daily_limit'),
        42,
      );
    },
  );

  testWidgets('Today selects the count pose from the combined total', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'rooko_selected_supported_apps': ['youtube', 'instagram'],
    });
    final tracking = FakeTodayTrackingPlatform()
      ..confirmedCount = 49
      ..estimatedCount = 1;

    await _pumpToday(tester, tracking);

    expect(find.bySemanticsLabel('Strained Rook'), findsOneWidget);
  });

  testWidgets('Today shows Sleeping when no selected supported profile works', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'rooko_selected_supported_apps': ['youtube'],
    });
    final tracking = FakeTodayTrackingPlatform()..profileAvailable = false;

    await _pumpToday(tester, tracking);

    expect(find.bySemanticsLabel('Sleeping Rook'), findsOneWidget);
  });

  testWidgets('Today shows Recovering briefly after a recent feed exit', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'rooko_selected_supported_apps': ['youtube'],
    });
    final now = DateTime.now().millisecondsSinceEpoch;
    final tracking = FakeTodayTrackingPlatform()
      ..lastValidatedFeedExitAtMillis = now;

    await _pumpToday(tester, tracking);

    expect(find.bySemanticsLabel('Recovering Rook'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 601));
    expect(find.bySemanticsLabel('Ready Rook'), findsOneWidget);
  });

  testWidgets('Today refreshes the count when returning from Settings', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'rooko_selected_supported_apps': ['youtube'],
    });
    final tracking = FakeTodayTrackingPlatform();
    await _pumpToday(tester, tracking);

    await tester.tap(find.byKey(const ValueKey('top-nav-settings')));
    await tester.pumpAndSettle();
    tracking.confirmedCount = 8;
    await tester.tap(find.byKey(const ValueKey('top-nav-back')));
    await tester.pumpAndSettle();

    expect(find.text('11'), findsWidgets);
    expect(tracking.snapshotCalls, greaterThanOrEqualTo(3));
  });

  testWidgets('icon-only top-right navigation returns to Today', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'rooko_selected_supported_apps': ['youtube'],
    });
    await _pumpToday(tester, FakeTodayTrackingPlatform());

    expect(find.byKey(const ValueKey('top-nav-progress')), findsOneWidget);
    expect(find.byKey(const ValueKey('top-nav-settings')), findsOneWidget);
    expect(find.byKey(const ValueKey('top-nav-back')), findsNothing);
    expect(find.text('Today'), findsOneWidget);
    expect(find.text('Progress'), findsNothing);
    final title = find.byKey(const ValueKey('top-nav-title'));
    final progressItem = find.byKey(const ValueKey('top-nav-progress'));
    expect(
      tester.getCenter(title).dy,
      closeTo(tester.getCenter(progressItem).dy, 1),
    );
    for (final label in ['Progress', 'Settings']) {
      final item = find.byKey(ValueKey('top-nav-${label.toLowerCase()}'));
      expect(
        find.descendant(of: item, matching: find.byType(Text)),
        findsNothing,
      );
      expect(find.bySemanticsLabel(label), findsOneWidget);
      expect(tester.getSize(item).width, greaterThanOrEqualTo(48));
      expect(tester.getSize(item).height, greaterThanOrEqualTo(48));
      expect(
        tester
            .widget<AppIcon>(
              find.descendant(of: item, matching: find.byType(AppIcon)),
            )
            .size,
        AppIconSizes.large,
      );
    }
    expect(
      tester.getTopRight(find.byKey(const ValueKey('top-nav-settings'))).dx,
      closeTo(tester.view.physicalSize.width - 16, 2),
    );

    await tester.tap(find.byKey(const ValueKey('top-nav-progress')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('top-nav-back')), findsOneWidget);
    expect(find.text('Today'), findsNothing);
    expect(find.text('Progress'), findsOneWidget);
    expect(
      tester.getCenter(title).dy,
      closeTo(tester.getCenter(progressItem).dy, 1),
    );
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('top-nav-back'))).dx,
      closeTo(16, 2),
    );

    await tester.tap(find.byKey(const ValueKey('top-nav-settings')));
    await tester.pumpAndSettle();
    expect(find.text('Settings'), findsOneWidget);
    expect(
      tester.getCenter(title).dy,
      closeTo(tester.getCenter(progressItem).dy, 1),
    );

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Today'), findsOneWidget);
    expect(find.byKey(const ValueKey('top-nav-back')), findsNothing);
  });

  testWidgets('top navigation fits a narrow screen with large text', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: const TextScaler.linear(2),
              disableAnimations: true,
            ),
            child: TodayHomeScreen(
              trackingPlatform: FakeTodayTrackingPlatform(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('top-nav-progress')), findsOneWidget);
    expect(find.byKey(const ValueKey('top-nav-settings')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const ValueKey('top-nav-progress')));
    await tester.pumpAndSettle();
    expect(find.text('Progress'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const ValueKey('top-nav-settings')));
    await tester.pumpAndSettle();
    expect(find.text('Settings'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpToday(
  WidgetTester tester, [
  TrackingPlatform trackingPlatform = const MethodChannelTrackingPlatform(),
]) async {
  tester.view.physicalSize = const Size(432, 960);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: TodayHomeScreen(trackingPlatform: trackingPlatform),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class FakeTodayTrackingPlatform implements TrackingPlatform {
  Set<String> selectedApps = {};
  bool serviceEnabled = true;
  bool serviceOperational = true;
  bool serviceInterruptedToday = false;
  bool consentAcknowledged = true;
  bool overlayPermissionGranted = false;
  bool profileAvailable = true;
  bool debugProfileAvailable = false;
  bool debugCountingEnabled = false;
  int lastValidatedFeedExitAtMillis = 0;
  int confirmedCount = 2;
  int estimatedCount = 3;
  int instagramConfirmedCount = 0;
  int instagramEstimatedCount = 0;
  int snapshotCalls = 0;
  bool bubbleEnabled = false;

  @override
  Future<ProgressRange> queryProgress(
    DateTime startDate,
    DateTime endDate,
  ) async => const ProgressRange(checkedAtMillis: 0, days: []);

  @override
  Future<ProgressCorrection> addCorrection({
    required String localDate,
    required String appId,
    required int delta,
    String? reason,
  }) async => throw UnimplementedError();

  @override
  Future<ProgressCorrection> undoCorrection(String correctionId) async =>
      throw UnimplementedError();

  @override
  Future<TrackingSnapshot> getSnapshot(Set<String> appIds) async {
    snapshotCalls++;
    return TrackingSnapshot(
      serviceEnabled: serviceEnabled,
      serviceOperational: serviceOperational,
      serviceInterruptedToday: serviceInterruptedToday,
      consentAcknowledged: consentAcknowledged,
      bubbleEnabled: bubbleEnabled,
      debugCountingEnabled: debugCountingEnabled,
      overlayPermissionGranted: overlayPermissionGranted,
      checkedAtMillis: 1_800_000_000_000,
      lastDetectionAtMillis: 1_800_000_000_000,
      lastValidatedFeedExitAtMillis: lastValidatedFeedExitAtMillis,
      localDate: '2026-11-06',
      apps: {
        'youtube': AppTrackingSnapshot(
          appId: 'youtube',
          selected: appIds.contains('youtube'),
          installed: true,
          versionName: '21.43.523',
          profileAvailable: profileAvailable,
          debugProfileAvailable: debugProfileAvailable,
          confidence: TrackingConfidence.confirmed,
          confirmedCount: confirmedCount,
          estimatedCount: estimatedCount,
        ),
        'instagram': AppTrackingSnapshot(
          appId: 'instagram',
          selected: appIds.contains('instagram'),
          installed: true,
          versionName: '455.0.0.51.72',
          profileAvailable: true,
          confidence: TrackingConfidence.confirmed,
          confirmedCount: instagramConfirmedCount,
          estimatedCount: instagramEstimatedCount,
        ),
      },
    );
  }

  @override
  Future<bool> openAccessibilitySettings() async => true;

  @override
  Future<bool> openSupportedApp(String appId) async => true;

  @override
  Future<bool> openInstagramProfile(String handle) async => true;

  @override
  Future<bool> openSupportedAppSettings(String appId) async => true;

  @override
  Future<bool> openSupportEmail(SupportEmailKind kind) async => true;

  @override
  Future<void> setConsentAcknowledged(bool acknowledged) async {
    consentAcknowledged = acknowledged;
  }

  @override
  Future<void> setBubbleEnabled(bool enabled) async {
    bubbleEnabled = enabled;
  }

  @override
  Future<bool> openOverlaySettings() async => true;

  @override
  Future<void> setSelectedApps(Set<String> appIds) async {
    selectedApps = appIds;
  }
}
