import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rooko/app.dart';
import 'package:rooko/core/design_system/app_colors.dart';
import 'package:rooko/core/design_system/app_theme.dart';
import 'package:rooko/core/models/progress.dart';
import 'package:rooko/core/platform/tracking_platform.dart';
import 'package:rooko/features/settings/settings_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'shows settings groups and marks unfinished actions unavailable',
    (tester) async {
      final platform = FakeSettingsPlatform();
      await _pumpSettings(tester, platform);

      expect(find.text('Apps'), findsOneWidget);
      expect(find.text('Accessibility access'), findsOneWidget);
      expect(find.text('Floating counter'), findsOneWidget);
      expect(
        find.text(
          'The counter shows the shared daily total across selected apps.',
        ),
        findsNothing,
      );
      expect(find.text('Appearance'), findsOneWidget);
      expect(find.text('LIMITS'), findsNothing);
      expect(find.text('Set a limit'), findsNothing);
      expect(find.text('Notifications'), findsNothing);
      expect(find.text('Battery optimization'), findsNothing);
      expect(find.text('Text-key counter test'), findsNothing);
      expect(find.textContaining('debug test'), findsNothing);
      expect(find.textContaining('estimated'), findsNothing);
      expect(find.textContaining('partial'), findsNothing);
      expect(find.textContaining('confirmed'), findsNothing);

      for (final title in [
        'Export data',
        'Delete local data',
        'Help & diagnostics',
      ]) {
        await tester.scrollUntilVisible(
          find.text(title),
          120,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.text(title), findsOneWidget);
        final tile = tester.widget<ListTile>(
          find
              .ancestor(of: find.text(title), matching: find.byType(ListTile))
              .first,
        );
        expect(tile.enabled, isFalse);
        expect(tile.onTap, isNull);
      }
      for (final text in ['Rooko', 'Version 1.0.0', 'Privacy Policy']) {
        await tester.scrollUntilVisible(
          find.text(text),
          120,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.text(text), findsOneWidget);
      }
    },
  );

  testWidgets('explains the combined counter total when enabled', (
    tester,
  ) async {
    final platform = FakeSettingsPlatform()
      ..snapshot = _snapshot(bubbleEnabled: true);
    await _pumpSettings(tester, platform);

    expect(
      find.text(
        'The counter shows the shared daily total across selected apps.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('distinguishes granted access from unsupported app versions', (
    tester,
  ) async {
    final platform = FakeSettingsPlatform()
      ..snapshot = _snapshot(
        serviceEnabled: true,
        serviceOperational: true,
        bubbleEnabled: true,
        overlayPermissionGranted: true,
        profileAvailable: false,
      );
    await _pumpSettings(tester, platform, selectedAppIds: {'instagram'});

    expect(find.text('On'), findsOneWidget);
    expect(find.text('1 selected · 0 supported'), findsOneWidget);
    expect(
      find.text(
        'No selected app version is supported yet. The counter stays hidden on feeds.',
      ),
      findsOneWidget,
    );
  });

  testWidgets(
    'estimated counting starts with tracking consent and has no toggle',
    (tester) async {
      final platform = FakeSettingsPlatform()
        ..snapshot = _snapshot(
          serviceEnabled: true,
          serviceOperational: true,
          bubbleEnabled: true,
          overlayPermissionGranted: true,
          profileAvailable: false,
          debugProfileAvailable: true,
          debugCountingEnabled: true,
        );
      await _pumpSettings(tester, platform, selectedAppIds: {'instagram'});

      expect(find.byKey(const ValueKey('debug-counting-toggle')), findsNothing);
      expect(find.text('1 selected · 1 ready to count'), findsOneWidget);
    },
  );

  testWidgets('app selection and appearance changes call their owners', (
    tester,
  ) async {
    final platform = FakeSettingsPlatform();
    Set<String>? selectedApps;
    AppAppearance? appearance;
    await _pumpSettings(
      tester,
      platform,
      selectedAppIds: {'instagram'},
      onSelectedAppIdsChanged: (ids) async => selectedApps = ids,
      onAppearanceChanged: (value) => appearance = value,
    );

    await tester.tap(find.text('Apps'));
    await tester.pumpAndSettle();
    expect(find.text('Select apps to track'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('settings-app-youtube')),
      120,
      scrollable: find.byType(Scrollable).last,
    );
    expect(
      tester
          .widget<CheckboxListTile>(
            find.byKey(const ValueKey('settings-app-youtube')),
          )
          .value,
      isFalse,
    );
    await tester.tap(find.byKey(const ValueKey('settings-app-youtube')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<CheckboxListTile>(
            find.byKey(const ValueKey('settings-app-youtube')),
          )
          .value,
      isTrue,
    );
    expect(selectedApps, {'instagram', 'youtube'});
    expect(platform.selectedApps, {'instagram', 'youtube'});
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(
      find.byKey(const ValueKey('appearance-selector')),
    );
    await tester.tap(find.byKey(const ValueKey('appearance-selector')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('AMOLED').last);
    await tester.pumpAndSettle();
    expect(appearance, AppAppearance.amoled);
  });

  testWidgets('app picker shows the installed version read from the device', (
    tester,
  ) async {
    final platform = FakeSettingsPlatform();
    await _pumpSettings(tester, platform);

    await tester.tap(find.text('Apps'));
    await tester.pumpAndSettle();

    expect(find.text('Version 454.0.0.54.77 · Available'), findsOneWidget);
    expect(find.text('Available'), findsNothing);
  });

  testWidgets('Accessibility settings require affirmative disclosure consent', (
    tester,
  ) async {
    final platform = FakeSettingsPlatform()
      ..snapshot = _snapshot(consent: false);
    await _pumpSettings(tester, platform);

    await tester.scrollUntilVisible(
      find.text('Set up access'),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Set up access'));
    await tester.pumpAndSettle();
    expect(platform.accessibilitySettingsCalls, 0);
    expect(
      find.text('I understand how this access will be used.'),
      findsOneWidget,
    );

    await tester.tap(find.text('I understand how this access will be used.'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(platform.consentAcknowledged, isTrue);
    expect(platform.accessibilitySettingsCalls, 1);

    platform.snapshot = _snapshot(
      consent: true,
      serviceEnabled: true,
      serviceOperational: true,
    );
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.text('On'), findsOneWidget);
  });

  testWidgets('overlay denial clears the enabled preference after return', (
    tester,
  ) async {
    final platform = FakeSettingsPlatform();
    await _pumpSettings(tester, platform);
    await tester.ensureVisible(
      find.byKey(const ValueKey('floating-counter-toggle')),
    );
    await tester.tap(find.byKey(const ValueKey('floating-counter-toggle')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(platform.overlaySettingsCalls, 1);
    expect(platform.bubbleEnabled, isTrue);
    platform.snapshot = _snapshot(consent: true, bubbleEnabled: true);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(platform.bubbleEnabled, isFalse);
    final counterToggle = tester.widget<SwitchListTile>(
      find.byKey(const ValueKey('floating-counter-toggle')),
    );
    expect(counterToggle.value, isFalse);
    expect(find.text('Review overlay access'), findsNothing);
  });

  testWidgets('refreshes permissions after an external Settings return', (
    tester,
  ) async {
    final platform = FakeSettingsPlatform()
      ..snapshot = _snapshot(
        consent: true,
        serviceEnabled: true,
        serviceOperational: true,
        bubbleEnabled: true,
        overlayPermissionGranted: true,
      );
    await _pumpSettings(tester, platform);
    expect(find.text('On'), findsOneWidget);
    expect(find.text('Overlay access on'), findsOneWidget);

    platform.snapshot = _snapshot(
      consent: true,
      serviceEnabled: false,
      serviceOperational: false,
      bubbleEnabled: true,
      overlayPermissionGranted: false,
    );
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(find.text('Off'), findsOneWidget);
    expect(find.text('Overlay access needed'), findsOneWidget);
  });

  testWidgets('shows access as on after a recovered same-day service gap', (
    tester,
  ) async {
    final platform = FakeSettingsPlatform()
      ..snapshot = _snapshot(
        consent: true,
        serviceEnabled: true,
        serviceOperational: true,
        serviceInterruptedToday: true,
      );

    await _pumpSettings(tester, platform);

    expect(find.text('On'), findsOneWidget);
    expect(find.text('Check needed'), findsNothing);
  });

  testWidgets('privacy policy opens the published page', (tester) async {
    final opened = <Uri>[];
    await _pumpSettings(
      tester,
      FakeSettingsPlatform(),
      launchPrivacyPolicy: (uri) async {
        opened.add(uri);
        return true;
      },
    );
    final scrollable = find.byType(Scrollable).first;
    for (var attempt = 0; attempt < 4; attempt++) {
      await tester.drag(scrollable, const Offset(0, -300));
      await tester.pumpAndSettle();
    }
    await tester.ensureVisible(find.text('Privacy Policy').last);
    await tester.tap(find.text('Privacy Policy').last);
    await tester.pumpAndSettle();

    expect(
      opened.single.toString(),
      'https://sites.google.com/view/rooko/home',
    );
    expect(find.text('Last updated: November 18, 2026'), findsNothing);
  });

  testWidgets('appearance selection persists and applies the AMOLED theme', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(432, 960);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData.fromView(tester.view)
            .copyWith(disableAnimations: true),
        child: const RookoApp(
          onboardingComplete: true,
          initialAppearance: AppAppearance.system,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('top-nav-settings')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const ValueKey('appearance-selector')),
    );
    await tester.tap(find.byKey(const ValueKey('appearance-selector')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('AMOLED').last);
    await tester.pumpAndSettle();

    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getString('rooko_appearance'), 'amoled');
    expect(
      Theme.of(tester.element(find.byKey(const ValueKey('top-nav-settings'))))
          .colorScheme
          .surface,
      AppColors.canvasAmoled,
    );
  });
}

Future<void> _pumpSettings(
  WidgetTester tester,
  FakeSettingsPlatform platform, {
  Set<String> selectedAppIds = const {},
  Future<void> Function(Set<String>)? onSelectedAppIdsChanged,
  ValueChanged<AppAppearance>? onAppearanceChanged,
  Future<bool> Function(Uri)? launchPrivacyPolicy,
}) async {
  tester.view.physicalSize = const Size(432, 960);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SettingsScreen(
          trackingPlatform: platform,
          selectedAppIds: selectedAppIds,
          onSelectedAppIdsChanged: onSelectedAppIdsChanged ?? (_) async {},
          appearance: AppAppearance.system,
          onAppearanceChanged: onAppearanceChanged ?? (_) {},
          launchPrivacyPolicy: launchPrivacyPolicy,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

TrackingSnapshot _snapshot({
  bool consent = true,
  bool serviceEnabled = false,
  bool serviceOperational = false,
  bool serviceInterruptedToday = false,
  bool bubbleEnabled = false,
  bool overlayPermissionGranted = false,
  bool profileAvailable = true,
  bool debugProfileAvailable = false,
  bool debugCountingEnabled = false,
}) => TrackingSnapshot(
  serviceEnabled: serviceEnabled,
  serviceOperational: serviceOperational,
  serviceInterruptedToday: serviceInterruptedToday,
  consentAcknowledged: consent,
  bubbleEnabled: bubbleEnabled,
  debugCountingEnabled: debugCountingEnabled,
  overlayPermissionGranted: overlayPermissionGranted,
  appVersion: '1.0.0',
  checkedAtMillis: 1,
  localDate: '2026-11-10',
  apps: {
    'instagram': AppTrackingSnapshot(
      appId: 'instagram',
      selected: true,
      installed: true,
      versionName: '454.0.0.54.77',
      profileAvailable: profileAvailable,
      debugProfileAvailable: debugProfileAvailable,
      confidence: TrackingConfidence.estimated,
      confirmedCount: 0,
      estimatedCount: 0,
    ),
  },
);

class FakeSettingsPlatform implements TrackingPlatform {
  TrackingSnapshot snapshot = _snapshot();
  Set<String> selectedApps = {};
  bool consentAcknowledged = true;
  bool bubbleEnabled = false;
  int accessibilitySettingsCalls = 0;
  int overlaySettingsCalls = 0;

  @override
  Future<void> setSelectedApps(Set<String> appIds) async {
    selectedApps = Set.of(appIds);
  }

  @override
  Future<void> setConsentAcknowledged(bool acknowledged) async {
    consentAcknowledged = acknowledged;
    snapshot = _snapshot(consent: acknowledged);
  }

  @override
  Future<void> setBubbleEnabled(bool enabled) async {
    bubbleEnabled = enabled;
    snapshot = _snapshot(consent: consentAcknowledged, bubbleEnabled: enabled);
  }

  @override
  Future<bool> openOverlaySettings() async {
    overlaySettingsCalls++;
    return true;
  }

  @override
  Future<bool> openAccessibilitySettings() async {
    accessibilitySettingsCalls++;
    return true;
  }

  @override
  Future<bool> openSupportedApp(String appId) async => true;

  @override
  Future<bool> openSupportedAppSettings(String appId) async => true;

  @override
  Future<bool> openSupportEmail(SupportEmailKind kind) async => true;

  @override
  Future<TrackingSnapshot> getSnapshot(Set<String> appIds) async => snapshot;

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
}
