import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_svg/flutter_svg.dart';

void main() {
  testWidgets('render transparent Sleeping eye overlay', (tester) async {
    tester.view.physicalSize = const Size(1254, 1254);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    const key = ValueKey('sleeping-eye-overlay');
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: RepaintBoundary(
          key: key,
          child: SizedBox(
            width: 1254,
            height: 1254,
            child: SvgPicture.file(
              File('assets/rook/rook-sleeping-eye-blink-overlay.svg'),
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
    final image = await tester.runAsync(() => boundary.toImage());
    final raw = await tester.runAsync(
      () => image!.toByteData(format: ui.ImageByteFormat.rawRgba),
    );
    final png = await tester.runAsync(
      () => image!.toByteData(format: ui.ImageByteFormat.png),
    );
    expect(image!.width, 1254);
    expect(image.height, 1254);
    final pixels = raw!.buffer.asUint8List();
    int alphaAt(int x, int y) => pixels[(y * 1254 + x) * 4 + 3];
    expect(alphaAt(0, 0), 0);
    expect(alphaAt(1253, 1253), 0);
    expect(alphaAt(430, 562), greaterThan(0));
    File('assets/rook/rook-sleeping-eye-blink-overlay.png')
        .writeAsBytesSync(png!.buffer.asUint8List());
    image.dispose();
  });
}
