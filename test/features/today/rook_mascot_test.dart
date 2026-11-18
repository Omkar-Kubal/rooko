import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:rooko/features/today/rook_mascot.dart';
import 'package:rooko/features/today/rook_state.dart';

void main() {
  testWidgets('reduced motion uses each state label with its static frame', (
    tester,
  ) async {
    for (final state in RookState.values) {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: Scaffold(body: RookMascot(state: state)),
          ),
        ),
      );
      await tester.pump();

      expect(find.bySemanticsLabel('${state.label} Rook'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('backgrounded Rook uses a static frame without Rive', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: RookMascot(state: RookState.strained)),
      ),
    );
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();

    expect(find.byType(SvgPicture), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('all eight Rook states have bundled Rive assets', (tester) async {
    const sharedStates = {
      RookState.ready,
      RookState.strained,
      RookState.injured,
      RookState.queasy,
    };
    for (final state in RookState.values) {
      final riveAsset = await rootBundle.load(state.riveAsset);
      expect(riveAsset.lengthInBytes, greaterThan(0), reason: state.label);
      expect(state.usesSharedStateMachine, sharedStates.contains(state));
    }
  });
}
