import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('preserve Ready art while clearing empty canvas edge', () async {
    final source = File('assets/rook/rook-ready-transparent.png');
    final codec = await ui.instantiateImageCodec(source.readAsBytesSync());
    final frame = await codec.getNextFrame();
    final image = frame.image;
    expect(image.width, 1254);
    expect(image.height, 1254);
    final raw = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    final pixels = Uint8List.fromList(raw!.buffer.asUint8List());
    final original = Uint8List.fromList(pixels);

    for (var y = 0; y < 1254; y++) {
      for (var x = 0; x < 1254; x++) {
        if (x >= 4 && x < 1250 && y >= 4 && y < 1250) continue;
        pixels[(y * 1254 + x) * 4 + 3] = 0;
      }
    }
    for (var y = 4; y < 1250; y++) {
      final start = (y * 1254 + 4) * 4;
      final end = (y * 1254 + 1250) * 4;
      expect(pixels.sublist(start, end), original.sublist(start, end));
    }

    final buffer = await ui.ImmutableBuffer.fromUint8List(pixels);
    final descriptor = ui.ImageDescriptor.raw(
      buffer,
      width: 1254,
      height: 1254,
      pixelFormat: ui.PixelFormat.rgba8888,
    );
    final outputCodec = await descriptor.instantiateCodec();
    final outputFrame = await outputCodec.getNextFrame();
    final output = await outputFrame.image.toByteData(
      format: ui.ImageByteFormat.png,
    );
    File('assets/rook/rook-victorious-ready-base.png')
        .writeAsBytesSync(output!.buffer.asUint8List());

    outputFrame.image.dispose();
    outputCodec.dispose();
    descriptor.dispose();
    buffer.dispose();
    image.dispose();
    codec.dispose();
  });
}
