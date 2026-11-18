import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_svg/flutter_svg.dart';

void main() {
  testWidgets('Victorious SVG renders without a background', (tester) async {
    const key = ValueKey('victorious-rook');
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: RepaintBoundary(
            key: key,
            child: SizedBox(
              width: 230,
              height: 230,
              child: SvgPicture.file(File('assets/rook/rook-victorious.svg')),
            ),
          ),
        ),
      ),
    );
    // ignore: invalid_use_of_visible_for_testing_member
    await tester.runAsync(vg.waitForPendingDecodes);
    await tester.pumpAndSettle();
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(key),
    );
    final preview = await tester.runAsync(
      () => boundary.toImage(pixelRatio: 1),
    );
    final rgba = await tester.runAsync(
      () => preview!.toByteData(format: ui.ImageByteFormat.rawRgba),
    );
    final png = await tester.runAsync(
      () => preview!.toByteData(format: ui.ImageByteFormat.png),
    );
    final pixels = rgba!.buffer.asUint8List();
    int alphaAt(int x, int y) => pixels[(y * 230 + x) * 4 + 3];
    expect(preview!.width, 230);
    expect(preview.height, 230);
    for (final point in [(0, 0), (229, 0), (0, 229), (229, 229)]) {
      expect(alphaAt(point.$1, point.$2), 0);
    }
    expect(alphaAt(115, 115), greaterThan(0));
    File('assets/rook/build/victorious-transparent-preview.png')
        .writeAsBytesSync(png!.buffer.asUint8List());
    preview.dispose();

    final full = await tester.runAsync(
      () => boundary.toImage(pixelRatio: 1254 / 230),
    );
    final fullPng = await tester.runAsync(
      () => full!.toByteData(format: ui.ImageByteFormat.png),
    );
    final fullRgba = await tester.runAsync(
      () => full!.toByteData(format: ui.ImageByteFormat.rawRgba),
    );
    expect(full!.width, 1254);
    expect(full.height, 1254);
    final fullPixels = fullRgba!.buffer.asUint8List();
    int fullAlphaAt(int x, int y) => fullPixels[(y * 1254 + x) * 4 + 3];
    for (final point in [(0, 0), (1253, 0), (0, 1253), (1253, 1253)]) {
      expect(fullAlphaAt(point.$1, point.$2), 0);
    }
    File('assets/rook/rook-victorious-transparent.png')
        .writeAsBytesSync(fullPng!.buffer.asUint8List());
    full.dispose();
  });

  testWidgets('Victorious eye-only blink overlay is transparent', (
    tester,
  ) async {
    const key = ValueKey('victorious-eyes');
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: RepaintBoundary(
            key: key,
            child: SizedBox(
              width: 230,
              height: 230,
              child: SvgPicture.file(
                File('assets/rook/rook-victorious-eye-blink-overlay.svg'),
              ),
            ),
          ),
        ),
      ),
    );
    // ignore: invalid_use_of_visible_for_testing_member
    await tester.runAsync(vg.waitForPendingDecodes);
    await tester.pumpAndSettle();
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(key),
    );
    final image = await tester.runAsync(
      () => boundary.toImage(pixelRatio: 1254 / 230),
    );
    final png = await tester.runAsync(
      () => image!.toByteData(format: ui.ImageByteFormat.png),
    );
    expect(image!.width, 1254);
    expect(image.height, 1254);
    File('assets/rook/rook-victorious-eye-blink-overlay.png')
        .writeAsBytesSync(png!.buffer.asUint8List());
    image.dispose();
  });
}
