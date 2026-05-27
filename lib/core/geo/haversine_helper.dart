import 'dart:math' as math;

/// Distancia en línea recta entre dos puntos GPS (km).
class HaversineHelper {
  HaversineHelper._();

  static double distanceKm(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const earthRadius = 6371.0;
    final dLat = _toRad(lat2 - lat1);
    final dLon = _toRad(lon2 - lon1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRad(lat1)) *
            math.cos(_toRad(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    return earthRadius * 2 * math.asin(math.sqrt(a));
  }

  static double _toRad(double degrees) => degrees * (math.pi / 180);
}
