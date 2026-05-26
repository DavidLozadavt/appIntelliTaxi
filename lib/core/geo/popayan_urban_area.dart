import 'dart:math' as math;

/// Perímetro urbano aproximado de Popayán (Cauca) para búsqueda de direcciones.
///
/// Viewport ajustado al casco urbano (no el área metropolitana de ~20 km).
class PopayanUrbanArea {
  PopayanUrbanArea._();

  static const double centerLat = 2.4419;
  static const double centerLng = -76.6063;

  /// Esquina suroeste del rectángulo urbano.
  static const double southWestLat = 2.4220;
  static const double southWestLng = -76.6380;

  /// Esquina noreste del rectángulo urbano.
  static const double northEastLat = 2.4620;
  static const double northEastLng = -76.5780;

  /// Radio máximo desde el centro (~4 km) como respaldo al rectángulo.
  static const double maxRadiusKm = 4.0;

  static const String searchNotice =
      'Búsqueda limitada al perímetro urbano de Popayán.';

  /// Parámetro `bounds` de Places Autocomplete (legacy): sw|ne.
  static const String autocompleteBounds =
      '$southWestLat,$southWestLng|$northEastLat,$northEastLng';

  static bool contains(double lat, double lng) {
    if (lat < southWestLat || lat > northEastLat) return false;
    if (lng < southWestLng || lng > northEastLng) return false;
    return distanceFromCenterKm(lat, lng) <= maxRadiusKm;
  }

  static double distanceFromCenterKm(double lat, double lng) {
    return _haversineKm(centerLat, centerLng, lat, lng);
  }

  /// Filtra sugerencias cuya descripción apunta fuera del casco urbano.
  static bool isPredictionAllowed(String description) {
    final text = description.toLowerCase();
    const excluded = [
      'cali,',
      'cali ',
      'pasto,',
      'bogotá',
      'bogota,',
      'pereira,',
      'armenia,',
      'ibagué',
      'ibague,',
      'neiva,',
      'santander de quilichao',
      'piendamó',
      'piendamo',
      'timbío',
      'timbio',
      'puracé',
      'purace',
      'silvia,',
      'morroa,',
      'totoró',
      'totoro',
      'el bordo',
      'puerto tejada',
      'villa rica',
    ];
    for (final token in excluded) {
      if (text.contains(token)) return false;
    }
    return true;
  }

  static double _haversineKm(
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
