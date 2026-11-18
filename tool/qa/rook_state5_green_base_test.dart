import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('tint state 5 skin a muted green while preserving alpha', () async {
    final source = File('assets/rook/rook-about-to-vomit-transparent.png');
    final codec = await ui.instantiateImageCodec(source.readAsBytesSync());
    final frame = await codec.getNextFrame();
    final image = frame.image;
    expect(image.width, 1254);
    expect(image.height, 1254);

    final raw = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    final rgba = Uint8List.fromList(raw!.buffer.asUint8List());
    var changed = 0;
    for (var i = 0; i < rgba.length; i += 4) {
      final red = rgba[i];
      final green = rgba[i + 1];
      final blue = rgba[i + 2];
      final alpha = rgba[i + 3];
      if (alpha == 0 || red <= 80 || red <= green + 5 || green < blue - 2) {
        continue;
      }
      rgba[i] = (red - 14).clamp(0, 255);
      rgba[i + 1] = (green + 7).clamp(0, 255);
      rgba[i + 2] = (blue - 3).clamp(0, 255);
      changed++;
    }
    expect(changed, greaterThan(100000));

    final buffer = await ui.ImmutableBuffer.fromUint8List(rgba);
    final descriptor = ui.ImageDescriptor.raw(
      buffer,
      width: image.width,
      height: image.height,
      pixelFormat: ui.PixelFormat.rgba8888,
    );
    final outputCodec = await descriptor.instantiateCodec();
    final outputFrame = await outputCodec.getNextFrame();
    final output = await outputFrame.image.toByteData(
      format: ui.ImageByteFormat.png,
    );
    File('assets/rook/rook-vomiting-base-green.png')
        .writeAsBytesSync(output!.buffer.asUint8List());

    outputFrame.image.dispose();
    outputCodec.dispose();
    descriptor.dispose();
    buffer.dispose();
    image.dispose();
    codec.dispose();
  });
}
