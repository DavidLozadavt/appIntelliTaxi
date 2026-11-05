import 'dart:math' as math;

/// Geometría plana en WGS84 para barrios de Popayán.
///
/// Anillos en `[lng, lat]`. Distancia en metros con proyección
/// equirectangular local (válida a ~2.4° N).
abstract final class GeoPolygon {
  static const double _metersPerDegLat = 111320.0;
  static const double _borderMeters = 50;
  static const double popayanLat = 2.4419;

  static double metersPerDegLng([double lat = popayanLat]) =>
      _metersPerDegLat * math.cos(lat * math.pi / 180);

  static bool ringContains(List<List<double>> ring, double lat, double lng) {
    if (ring.length < 4) return false;
    var inside = false;
    for (var i = 0, j = ring.length - 1; i < ring.length; j = i++) {
      final xi = ring[i][0], yi = ring[i][1];
      final xj = ring[j][0], yj = ring[j][1];
      final intersect = ((yi > lat) != (yj > lat)) &&
          (lng < (xj - xi) * (lat - yi) / ((yj - yi) == 0 ? 1e-12 : (yj - yi)) + xi);
      if (intersect) inside = !inside;
    }
    return inside;
  }

  static bool polygonContains(
    List<List<List<double>>> polygon,
    double lat,
    double lng,
  ) {
    if (polygon.isEmpty) return false;
    if (!ringContains(polygon.first, lat, lng)) return false;
    for (var i = 1; i < polygon.length; i++) {
      if (ringContains(polygon[i], lat, lng)) return false;
    }
    return true;
  }

  static bool multiContains(
    List<List<List<List<double>>>> polygons,
    double lat,
    double lng,
  ) {
    for (final poly in polygons) {
      if (polygonContains(poly, lat, lng)) return true;
    }
    return false;
  }

  static double distanceToRingMeters(
    List<List<double>> ring,
    double lat,
    double lng, {
    double atLat = popayanLat,
  }) {
    if (ring.length < 2) return double.infinity;
    var best = double.infinity;
    final mLng = metersPerDegLng(atLat);
    for (var i = 0; i < ring.length - 1; i++) {
      final d = _distanceToSegmentMeters(
        lng,
        lat,
        ring[i][0],
        ring[i][1],
        ring[i + 1][0],
        ring[i + 1][1],
        mLng,
      );
      if (d < best) best = d;
    }
    return best;
  }

  static double distanceToBoundaryMeters(
    List<List<List<List<double>>>> polygons,
    double lat,
    double lng,
  ) {
    var best = double.infinity;
    for (final poly in polygons) {
      for (final ring in poly) {
        final d = distanceToRingMeters(ring, lat, lng);
        if (d < best) best = d;
      }
    }
    return best;
  }

  static bool nearBorder(double distanceMeters) =>
      distanceMeters.isFinite && distanceMeters <= _borderMeters;

  static double _distanceToSegmentMeters(
    double x,
    double y,
    double x1,
    double y1,
    double x2,
    double y2,
    double metersPerDegLng,
  ) {
    final dx = (x2 - x1) * metersPerDegLng;
    final dy = (y2 - y1) * _metersPerDegLat;
    final px = (x - x1) * metersPerDegLng;
    final py = (y - y1) * _metersPerDegLat;
    final len2 = dx * dx + dy * dy;
    var t = len2 == 0 ? 0.0 : (px * dx + py * dy) / len2;
    t = t.clamp(0.0, 1.0);
    final ex = px - dx * t;
    final ey = py - dy * t;
    return math.sqrt(ex * ex + ey * ey);
  }
}
