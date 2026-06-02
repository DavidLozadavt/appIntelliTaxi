import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intellitaxi/core/map/bitmap_descriptor.dart';

/// Widget de icono para un [BitmapDescriptor] en marcadores OSM.
class MarkerIconWidget extends StatelessWidget {
  const MarkerIconWidget({
    super.key,
    required this.descriptor,
    this.size = 48,
  });

  final BitmapDescriptor descriptor;
  final double size;

  @override
  Widget build(BuildContext context) {
    final w = descriptor.width > 0 ? descriptor.width : size;

    if (descriptor.bytes != null) {
      return Image.memory(
        descriptor.bytes!,
        width: w,
        height: w,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
      );
    }

    if (descriptor.assetPath != null) {
      return Image.asset(
        descriptor.assetPath!,
        width: w,
        height: w,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
      );
    }

    final color = _hueToColor(descriptor.hue ?? BitmapDescriptor.hueRed);
    return CustomPaint(
      size: Size(w, w * 1.2),
      painter: _PinPainter(color: color),
    );
  }

  static Color _hueToColor(double hue) {
    return HSVColor.fromAHSV(1, hue, 0.85, 0.95).toColor();
  }
}

class _PinPainter extends CustomPainter {
  _PinPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final centerX = w / 2;
    final headRadius = w * 0.28;
    final headCenterY = headRadius + 2;

    final shadow = Paint()
      ..color = Colors.black.withValues(alpha: 0.2)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    canvas.drawCircle(Offset(centerX, headCenterY + 1), headRadius, shadow);

    final fill = Paint()..color = color;
    canvas.drawCircle(Offset(centerX, headCenterY), headRadius, fill);

    final path = Path()
      ..moveTo(centerX - headRadius * 0.55, headCenterY + headRadius * 0.5)
      ..lineTo(centerX, h - 2)
      ..lineTo(centerX + headRadius * 0.55, headCenterY + headRadius * 0.5)
      ..close();
    canvas.drawPath(path, fill);

    canvas.drawCircle(
      Offset(centerX, headCenterY),
      headRadius * 0.35,
      Paint()..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(covariant _PinPainter oldDelegate) =>
      oldDelegate.color != color;
}

/// Aplica rotación de marcador (grados, norte = 0).
Widget rotatedMarkerChild({
  required Widget child,
  required double rotationDegrees,
  required bool flat,
  required double mapBearingDegrees,
}) {
  var angle = rotationDegrees * math.pi / 180;
  if (flat) {
    angle -= mapBearingDegrees * math.pi / 180;
  }
  if (angle == 0) return child;
  return Transform.rotate(angle: angle, child: child);
}
