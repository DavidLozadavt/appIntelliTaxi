import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Genera iconos circulares (punto con borde blanco) para Google Maps.
class MapDotMarkerFactory {
  MapDotMarkerFactory._();

  static Future<BitmapDescriptor> create({
    required Color color,
    double size = 36,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    canvas.drawCircle(
      Offset(size / 2, size / 2 + 1),
      size / 3,
      Paint()
        ..color = color.withValues(alpha: 0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    canvas.drawCircle(
      Offset(size / 2, size / 2),
      size / 3,
      Paint()..color = Colors.white,
    );
    canvas.drawCircle(
      Offset(size / 2, size / 2),
      size / 4,
      Paint()..color = color,
    );

    final picture = recorder.endRecording();
    final image = await picture.toImage(size.toInt(), size.toInt());
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.bytes(bytes!.buffer.asUint8List());
  }
}
