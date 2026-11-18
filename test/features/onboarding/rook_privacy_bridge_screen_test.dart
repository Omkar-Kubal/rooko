import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rooko/features/onboarding/rook_privacy_bridge_screen.dart';

void main() {
  testWidgets('shield bridge stages its heading and pauses in background', (
    tester,
  ) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: false),
          child: RookPrivacyBridgeScreen(onBack: () {}, onContinue: () {}),
        ),
      ),
    );
    double opacity() => tester
        .widget<Opacity>(
          find.byKey(const ValueKey('privacy-bridge-heading-opacity')),
        )
        .opacity;
    expect(opacity(), 0);
    await tester.pump(const Duration(milliseconds: 400));
    final beforePause = opacity();
    expect(beforePause, greaterThan(0));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(seconds: 3));
    expect(opacity(), closeTo(beforePause, 0.001));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(opacity(), 1);
  });

  testWidgets('reduced motion presents the settled shield immediately', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: RookPrivacyBridgeScreen(onBack: () {}, onContinue: () {}),
        ),
      ),
    );
    await tester.pump();
    expect(
      tester
          .widget<Opacity>(
            find.byKey(const ValueKey('privacy-bridge-heading-opacity')),
          )
          .opacity,
      1,
    );
    expect(find.text('Keep the count in sight.'), findsOneWidget);
  });
}
