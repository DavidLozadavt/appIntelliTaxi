import 'dart:math' as math;

/// Perímetro de servicio en Popayán y sectores aledaños (veredas, expansiones).
///
/// Incluye casco urbano, Vereda de Torres, Calibío, vías de ingreso, etc.
class PopayanUrbanArea {
  PopayanUrbanArea._();

  static const double centerLat = 2.4419;
  static const double centerLng = -76.6063;

  /// Esquina suroeste del rectángulo de cobertura (alineado al bbox del backend).
  static const double southWestLat = 2.32;
  static const double southWestLng = -76.82;

  /// Esquina noreste: incluye Calibío, Terra Plaza, veredas.
  static const double northEastLat = 2.58;
  static const double northEastLng = -76.42;

  /// Radio de sesgo para Places. No se usa como veto: las esquinas del
  /// bbox quedan a ~27 km y exigir radio **y** rectángulo rechazaba
  /// barrios/veredas reales (El Tambo, Calibío, vías de ingreso).
  static const double maxRadiusKm = 30.0;

  static const String searchNotice =
      'Servicio disponible en Popayán y zonas cercanas.';

  /// Parámetro `bounds` de Places Autocomplete (legacy): sw|ne.
  static const String autocompleteBounds =
      '$southWestLat,$southWestLng|$northEastLat,$northEastLng';

  static bool contains(double lat, double lng) {
    if (!lat.isFinite || !lng.isFinite) return false;
    return lat >= southWestLat &&
        lat <= northEastLat &&
        lng >= southWestLng &&
        lng <= northEastLng;
  }

  static double distanceFromCenterKm(double lat, double lng) {
    return _haversineKm(centerLat, centerLng, lat, lng);
  }

  static bool mentionsPopayan(String text) {
    final folded = _fold(text);
    return folded.contains('popayan');
  }

  /// Filtra sugerencias cuya descripción apunta a otra ciudad.
  ///
  /// Si el texto nombra Popayán, se acepta: "Vía Totoró, Popayán" es una
  /// vía local y no el municipio de Totoró.
  static bool isPredictionAllowed(String description) {
    final text = _fold(description);
    if (text.contains('popayan')) return true;
    const excluded = [
      'cali,',
      'cali ',
      'pasto,',
      'bogotá',
      'bogota,',
      'bogota ',
      'pereira,',
      'armenia,',
      'ibagué',
      'ibague,',
      'neiva,',
      'santander de quilichao',
      'silvia,',
      'morroa,',
      'el bordo',
      'puerto tejada',
      'villa rica',
    ];
    for (final token in excluded) {
      if (text.contains(_fold(token))) return false;
    }
    if (_isForeignMunicipality(text)) return false;
    return true;
  }

  static bool _isForeignMunicipality(String folded) {
    const towns = ['totoro', 'purace', 'piendamo'];
    for (final town in towns) {
      if (!folded.contains(town)) continue;
      if (RegExp('via\\s+(a\\s+)?$town').hasMatch(folded)) continue;
      return true;
    }
    return false;
  }

  static String _fold(String value) {
    return value
        .toLowerCase()
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ü', 'u');
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
