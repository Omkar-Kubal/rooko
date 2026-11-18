import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rive/rive.dart' as rive;

void main() {
  testWidgets('Recovering Rook Rive opens with eye-only blink', (tester) async {
    final file = await tester.runAsync(
      () => rive.File.path(
        'assets/rook/rook-recovering.riv',
        riveFactory: rive.Factory.flutter,
      ),
    );
    expect(file, isNotNull);
    final controller = rive.RiveWidgetController(file!);
    const boundaryKey = ValueKey('recovering-rook-rive');
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          backgroundColor: Colors.transparent,
          body: Center(
            child: RepaintBoundary(
              key: boundaryKey,
              child: SizedBox(
                width: 300,
                height: 300,
                child: rive.RiveWidget(
                  controller: controller,
                  fit: rive.Fit.contain,
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 1000));
    final open = await _capture(tester, boundaryKey);
    final samples = <Frame>[];
    for (var i = 0; i < 45; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      samples.add(await _capture(tester, boundaryKey));
    }
    final blink = samples.reduce(
      (a, b) => _changedPixels(open, a) > _changedPixels(open, b) ? a : b,
    );
    final changed = _changedPixels(open, blink);
    final outsideEyes = _changedOutsideEyes(open, blink);
    debugPrint(
      'Recovering blink changed $changed pixels; outside eyes: $outsideEyes',
    );
    expect(changed, greaterThan(100));
    expect(outsideEyes, 0);
    for (final frame in [open, blink]) {
      expect(_alphaAt(frame, 0, 0), 0);
      expect(_alphaAt(frame, 299, 0), 0);
      expect(_alphaAt(frame, 0, 299), 0);
      expect(_alphaAt(frame, 299, 299), 0);
    }

    final evidence = Directory('docs/qa/2026-11-14-rook-recovering-rive');
    evidence.createSync(recursive: true);
    File('${evidence.path}/recovering-open.png').writeAsBytesSync(open.png);
    File('${evidence.path}/recovering-blink.png').writeAsBytesSync(blink.png);
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
    file.dispose();
  });
}

class Frame {
  Frame(this.rgba, this.png);
  final List<int> rgba;
  final List<int> png;
}

Future<Frame> _capture(WidgetTester tester, Key key) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(key));
  final image = await tester.runAsync(() => boundary.toImage(pixelRatio: 1));
  final rgba = await tester.runAsync(
    () => image!.toByteData(format: ui.ImageByteFormat.rawRgba),
  );
  final png = await tester.runAsync(
    () => image!.toByteData(format: ui.ImageByteFormat.png),
  );
  image!.dispose();
  return Frame(rgba!.buffer.asUint8List(), png!.buffer.asUint8List());
}

int _changedPixels(Frame a, Frame b) {
  var count = 0;
  for (var i = 0; i < a.rgba.length; i += 4) {
    if (a.rgba[i] != b.rgba[i] ||
        a.rgba[i + 1] != b.rgba[i + 1] ||
        a.rgba[i + 2] != b.rgba[i + 2] ||
        a.rgba[i + 3] != b.rgba[i + 3]) {
      count++;
    }
  }
  return count;
}

int _changedOutsideEyes(Frame a, Frame b) {
  var count = 0;
  for (var y = 0; y < 300; y++) {
    for (var x = 0; x < 300; x++) {
      if (x >= 65 && x <= 225 && y >= 95 && y <= 180) continue;
      final i = (y * 300 + x) * 4;
      if (a.rgba[i] != b.rgba[i] ||
          a.rgba[i + 1] != b.rgba[i + 1] ||
          a.rgba[i + 2] != b.rgba[i + 2] ||
          a.rgba[i + 3] != b.rgba[i + 3]) {
        count++;
      }
    }
  }
  return count;
}

int _alphaAt(Frame frame, int x, int y) => frame.rgba[(y * 300 + x) * 4 + 3];
