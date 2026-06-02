import 'dart:math' as math;

import 'package:geolocator/geolocator.dart';
import 'package:intellitaxi/core/map/intellitaxi_maps.dart';

/// Utilidades para orientar marcadores de vehículos en el mapa.
class MapMarkerBearingHelper {
  MapMarkerBearingHelper._();

  static const double minMoveMetersForBearing = 3;

  /// Rumbo válido enviado por el backend (grados respecto al norte).
  static double? parseRumbo(dynamic value) {
    if (value == null) return null;
    final parsed = switch (value) {
      final num n => n.toDouble(),
      final String s => double.tryParse(s.trim().replaceAll(',', '.')),
      _ => null,
    };
    if (parsed == null || !parsed.isFinite) return null;
    if (parsed < 0 || parsed > 360) return null;
    return parsed;
  }

  static double? bearingFromMovement(LatLng? from, LatLng to) {
    if (from == null) return null;
    final dist = Geolocator.distanceBetween(
      from.latitude,
      from.longitude,
      to.latitude,
      to.longitude,
    );
    if (dist < minMoveMetersForBearing) return null;
    return Geolocator.bearingBetween(
      from.latitude,
      from.longitude,
      to.latitude,
      to.longitude,
    );
  }

  static double resolveBearing({
    required LatLng to,
    LatLng? from,
    double? backendRumbo,
    double? fallback,
  }) {
    final movimiento = bearingFromMovement(from, to);
    if (movimiento != null) return movimiento;
    if (backendRumbo != null) return backendRumbo;
    return fallback ?? 0;
  }

  static double smoothBearing({
    required double current,
    required double target,
    required double factor,
    required bool initialized,
  }) {
    if (!initialized) return target;

    var diff = target - current;
    if (diff > 180) diff -= 360;
    if (diff < -180) diff += 360;

    var suavizado = current + diff * factor;
    if (suavizado < 0) suavizado += 360;
    if (suavizado >= 360) suavizado -= 360;
    return suavizado;
  }

  /// Avanza `current` hacia `target` siguiendo el rumbo entre ambos.
  static LatLng advanceToward(LatLng current, LatLng target, double factor) {
    final dist = Geolocator.distanceBetween(
      current.latitude,
      current.longitude,
      target.latitude,
      target.longitude,
    );
    if (dist <= 0) return target;

    final step = dist * factor;
    if (step >= dist) return target;

    final bearing = Geolocator.bearingBetween(
      current.latitude,
      current.longitude,
      target.latitude,
      target.longitude,
    );
    return offsetMeters(current, bearing, step);
  }

  static LatLng offsetMeters(LatLng from, double bearingDegrees, double meters) {
    const earthRadius = 6378137.0;
    final lat1 = from.latitude * math.pi / 180;
    final lon1 = from.longitude * math.pi / 180;
    final brng = bearingDegrees * math.pi / 180;
    final d = meters / earthRadius;

    final lat2 = math.asin(
      math.sin(lat1) * math.cos(d) +
          math.cos(lat1) * math.sin(d) * math.cos(brng),
    );
    final lon2 = lon1 +
        math.atan2(
          math.sin(brng) * math.sin(d) * math.cos(lat1),
          math.cos(d) - math.sin(lat1) * math.sin(lat2),
        );

    return LatLng(lat2 * 180 / math.pi, lon2 * 180 / math.pi);
  }
}
