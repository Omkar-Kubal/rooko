import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rive/rive.dart' as rive;

void main() {
  testWidgets('Injured and Queasy Rive states blink without moving Rook', (
    tester,
  ) async {
    final file = await tester.runAsync(
      () => rive.File.asset(
        'assets/rook/rook.riv',
        riveFactory: rive.Factory.flutter,
      ),
    );
    expect(file, isNotNull);
    final controller = rive.RiveWidgetController(file!);
    // This asset still uses the existing named Rive state-machine inputs.
    // ignore: deprecated_member_use
    final injured = controller.stateMachine.boolean('isInjured');
    // ignore: deprecated_member_use
    final strained = controller.stateMachine.boolean('isStrained');
    // ignore: deprecated_member_use
    final queasy = controller.stateMachine.boolean('isQueasy');
    expect(injured, isNotNull);
    expect(strained, isNotNull);
    expect(queasy, isNotNull);

    const boundaryKey = ValueKey('rook-rive-boundary');
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

    injured!.value = true;
    await tester.pump(const Duration(milliseconds: 1000));
    await tester.pump(const Duration(milliseconds: 300));
    final open = await _capture(tester, boundaryKey);
    final samples = <Uint8ListFrame>[];
    for (var i = 0; i < 45; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      samples.add(await _capture(tester, boundaryKey));
    }
    final blink = samples.reduce(
      (a, b) => _changedPixels(open, a) > _changedPixels(open, b) ? a : b,
    );
    final changed = _changedPixels(open, blink);
    final evidence = Directory('docs/qa/2026-11-14-rook-injured-rive');
    evidence.createSync(recursive: true);
    File('${evidence.path}/injured-open.png').writeAsBytesSync(open.png);
    File('${evidence.path}/injured-blink.png').writeAsBytesSync(blink.png);
    debugPrint(
      'Injured open/blink changed $changed pixels; outside eyes: ${_changedOutsideEyes(open, blink)}',
    );
    expect(changed, greaterThan(100));
    expect(_changedOutsideEyes(open, blink), 0);
    expect(_alphaAt(open, 0, 0), 0);
    expect(_alphaAt(blink, 299, 299), 0);

    injured.value = false;
    queasy!.value = true;
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    final queasyOpen = await _capture(tester, boundaryKey);
    expect(_changedPixels(open, queasyOpen), greaterThan(100));
    final queasySamples = <Uint8ListFrame>[];
    for (var i = 0; i < 45; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      queasySamples.add(await _capture(tester, boundaryKey));
    }
    final queasyBlink = queasySamples.reduce(
      (a, b) =>
          _changedPixels(queasyOpen, a) > _changedPixels(queasyOpen, b) ? a : b,
    );
    final queasyChanged = _changedPixels(queasyOpen, queasyBlink);
    final queasyEvidence = Directory('docs/qa/2026-11-14-rook-queasy-rive');
    queasyEvidence.createSync(recursive: true);
    File('${queasyEvidence.path}/queasy-open.png')
        .writeAsBytesSync(queasyOpen.png);
    File('${queasyEvidence.path}/queasy-blink.png')
        .writeAsBytesSync(queasyBlink.png);
    debugPrint(
      'Queasy open/blink changed $queasyChanged pixels; outside eyes: ${_changedOutsideEyes(queasyOpen, queasyBlink)}',
    );
    expect(queasyChanged, greaterThan(100));
    expect(_changedOutsideEyes(queasyOpen, queasyBlink), 0);
    expect(_alphaAt(queasyOpen, 0, 0), 0);
    expect(_alphaAt(queasyBlink, 299, 299), 0);

    queasy.value = false;
    injured.value = true;
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    final injuredReturn = await _capture(tester, boundaryKey);
    expect(_changedPixels(queasyOpen, injuredReturn), greaterThan(100));
    File('${queasyEvidence.path}/injured-return.png')
        .writeAsBytesSync(injuredReturn.png);

    injured.value = false;
    strained!.value = true;
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    final strainedFrame = await _capture(tester, boundaryKey);
    expect(_changedPixels(open, strainedFrame), greaterThan(100));
    File('${evidence.path}/strained-return.png')
        .writeAsBytesSync(strainedFrame.png);

    strained.value = false;
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    final readyFrame = await _capture(tester, boundaryKey);
    expect(_changedPixels(open, readyFrame), greaterThan(100));
    File('${evidence.path}/ready-return.png').writeAsBytesSync(readyFrame.png);

    await tester.pumpWidget(const SizedBox.shrink());
    injured.dispose();
    queasy.dispose();
    strained.dispose();
    controller.dispose();
    file.dispose();
  });
}

class Uint8ListFrame {
  Uint8ListFrame(this.rgba, this.png);
  final List<int> rgba;
  final List<int> png;
}

Future<Uint8ListFrame> _capture(WidgetTester tester, Key key) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(key));
  final image = await tester.runAsync(() => boundary.toImage(pixelRatio: 1));
  final rgba = await tester.runAsync(
    () => image!.toByteData(format: ui.ImageByteFormat.rawRgba),
  );
  final png = await tester.runAsync(
    () => image!.toByteData(format: ui.ImageByteFormat.png),
  );
  image!.dispose();
  return Uint8ListFrame(rgba!.buffer.asUint8List(), png!.buffer.asUint8List());
}

int _changedPixels(Uint8ListFrame a, Uint8ListFrame b) {
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

int _changedOutsideEyes(Uint8ListFrame a, Uint8ListFrame b) {
  var count = 0;
  for (var y = 0; y < 300; y++) {
    for (var x = 0; x < 300; x++) {
      if ((x >= 65 && x <= 225 && y >= 95 && y <= 180)) {
        continue;
      }
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

int _alphaAt(Uint8ListFrame frame, int x, int y) =>
    frame.rgba[(y * 300 + x) * 4 + 3];
