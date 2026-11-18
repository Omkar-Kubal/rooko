import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:rooko/features/today/rook_mascot.dart';
import 'package:rooko/features/today/rook_state.dart';

void main() {
  testWidgets('reduced motion uses the static Rook frame without Rive', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
        home: const Scaffold(body: RookMascot(state: RookState.ready)),
      ),
    );

    expect(find.byType(SvgPicture), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  });

  for (final state in RookState.values) {
    testWidgets('${state.name} static frame paints visible artwork', (
      tester,
    ) async {
      final visiblePixels = await _visiblePixels(
        tester,
        SvgPicture.asset(state.svgAsset),
      );
      expect(tester.takeException(), isNull);
      expect(visiblePixels, greaterThan(100));
    });
  }
}

Future<int> _visiblePixels(WidgetTester tester, Widget child) async {
  const boundaryKey = ValueKey('artwork-boundary');
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        backgroundColor: const Color(0x00000000),
        body: RepaintBoundary(
          key: boundaryKey,
          child: SizedBox(width: 200, height: 200, child: child),
        ),
      ),
    ),
  );
  await tester.runAsync(vg.waitForPendingDecodes);
  await tester.pumpAndSettle();
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(boundaryKey),
  );
  final image = await tester.runAsync(() => boundary.toImage(pixelRatio: 1));
  final bytes = await tester.runAsync(
    () => image!.toByteData(format: ui.ImageByteFormat.rawRgba),
  );
  final rgba = bytes!.buffer.asUint8List();
  var visiblePixels = 0;
  for (var offset = 3; offset < rgba.length; offset += 4) {
    if (rgba[offset] > 0) visiblePixels++;
  }
  return visiblePixels;
}
