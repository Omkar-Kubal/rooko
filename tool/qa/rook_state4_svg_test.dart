import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_svg/flutter_svg.dart';

void main() {
  testWidgets('state 4 SVG renders without a background', (tester) async {
    const key = ValueKey('state-four');
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
                File('assets/rook/rook-about-to-vomit.svg'),
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
    final image = await tester.runAsync(() => boundary.toImage(pixelRatio: 1));
    final raw = await tester.runAsync(
      () => image!.toByteData(format: ui.ImageByteFormat.rawRgba),
    );
    final png = await tester.runAsync(
      () => image!.toByteData(format: ui.ImageByteFormat.png),
    );
    final pixels = raw!.buffer.asUint8List();
    expect(image!.width, 230);
    expect(image.height, 230);
    int alphaAt(int x, int y) => pixels[(y * 230 + x) * 4 + 3];
    expect(alphaAt(0, 0), 0);
    expect(alphaAt(229, 0), 0);
    expect(alphaAt(0, 229), 0);
    expect(alphaAt(229, 229), 0);
    expect(alphaAt(115, 115), greaterThan(0));
    final output = File('assets/rook/build/state4-transparent-preview.png');
    output.writeAsBytesSync(png!.buffer.asUint8List());
    image.dispose();

    final fullSize = await tester.runAsync(
      () => boundary.toImage(pixelRatio: 1254 / 230),
    );
    expect(fullSize!.width, 1254);
    expect(fullSize.height, 1254);
    final fullPng = await tester.runAsync(
      () => fullSize.toByteData(format: ui.ImageByteFormat.png),
    );
    File('assets/rook/rook-about-to-vomit-transparent.png')
        .writeAsBytesSync(fullPng!.buffer.asUint8List());
    fullSize.dispose();
  });
}
