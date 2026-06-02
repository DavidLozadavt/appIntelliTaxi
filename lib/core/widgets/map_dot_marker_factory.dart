import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:intellitaxi/core/map/intellitaxi_maps.dart';

/// Genera iconos circulares (punto con borde blanco) para marcadores del mapa.
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
    return BitmapDescriptor.fromBytes(bytes!.buffer.asUint8List(), width: size);
  }
}
