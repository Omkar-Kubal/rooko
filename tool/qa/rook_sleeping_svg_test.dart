import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_svg/flutter_svg.dart';

void main() {
  testWidgets('Sleeping Rook SVG renders on a transparent canvas', (
    tester,
  ) async {
    const key = ValueKey('sleeping-rook');
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
              child: SvgPicture.file(File('assets/rook/rook-sleeping.svg')),
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

    Future<void> render(int size, String output) async {
      final image = await tester.runAsync(
        () => boundary.toImage(pixelRatio: size / 230),
      );
      final raw = await tester.runAsync(
        () => image!.toByteData(format: ui.ImageByteFormat.rawRgba),
      );
      final png = await tester.runAsync(
        () => image!.toByteData(format: ui.ImageByteFormat.png),
      );
      expect(image!.width, size);
      expect(image.height, size);
      final pixels = raw!.buffer.asUint8List();
      int alphaAt(int x, int y) => pixels[(y * size + x) * 4 + 3];
      for (final point in [
        (0, 0),
        (size - 1, 0),
        (0, size - 1),
        (size - 1, size - 1),
      ]) {
        expect(alphaAt(point.$1, point.$2), 0);
      }
      expect(alphaAt(size ~/ 2, size ~/ 2), greaterThan(0));
      File(output).writeAsBytesSync(png!.buffer.asUint8List());
      image.dispose();
    }

    await render(230, 'assets/rook/build/sleeping-transparent-preview.png');
    await render(1254, 'assets/rook/rook-sleeping-transparent.png');
  });
}
