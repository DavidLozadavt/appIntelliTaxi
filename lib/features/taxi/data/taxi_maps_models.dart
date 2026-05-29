/// Modelos para proxies `/api/taxi/*` (Nominatim + OSRM).
class TaxiReverseGeocodeResult {
  TaxiReverseGeocodeResult({
    required this.lat,
    required this.lng,
    this.address,
    this.barrio,
    this.zona,
    this.provider,
  });

  factory TaxiReverseGeocodeResult.fromJson(Map<String, dynamic> j) {
    return TaxiReverseGeocodeResult(
      lat: (j['lat'] as num).toDouble(),
      lng: (j['lng'] as num).toDouble(),
      address: j['address']?.toString(),
      barrio: j['barrio']?.toString(),
      zona: j['zona']?.toString(),
      provider: j['provider']?.toString(),
    );
  }

  final double lat;
  final double lng;
  final String? address;
  final String? barrio;
  /// Texto corto de calle (mismo criterio que `ubicacion-mapa`).
  final String? zona;
  final String? provider;
}

class TaxiPlacePredictionDto {
  TaxiPlacePredictionDto({
    required this.description,
    required this.address,
    required this.name,
    required this.lat,
    required this.lng,
    required this.placeId,
  });

  factory TaxiPlacePredictionDto.fromJson(Map<String, dynamic> j) {
    return TaxiPlacePredictionDto(
      description: j['description']?.toString() ?? '',
      address: j['address']?.toString() ?? '',
      name: j['name']?.toString() ?? '',
      lat: (j['lat'] as num).toDouble(),
      lng: (j['lng'] as num).toDouble(),
      placeId: j['place_id']?.toString() ?? '',
    );
  }

  final String description;
  final String address;
  final String name;
  final double lat;
  final double lng;
  final String placeId;
}

class TaxiForwardGeocodeResult {
  TaxiForwardGeocodeResult({
    required this.lat,
    required this.lng,
    required this.address,
    required this.name,
    required this.placeId,
  });

  factory TaxiForwardGeocodeResult.fromJson(Map<String, dynamic> j) {
    return TaxiForwardGeocodeResult(
      lat: (j['lat'] as num).toDouble(),
      lng: (j['lng'] as num).toDouble(),
      address: j['address']?.toString() ?? '',
      name: j['name']?.toString() ?? '',
      placeId: j['place_id']?.toString() ?? '',
    );
  }

  final double lat;
  final double lng;
  final String address;
  final String name;
  final String placeId;
}

class TaxiOsrmRouteResult {
  TaxiOsrmRouteResult({
    required this.distanceMeters,
    required this.durationSeconds,
    required this.distanceText,
    required this.durationText,
    required this.polylinePoints,
    this.cacheHit = false,
  });

  factory TaxiOsrmRouteResult.fromJson(
    Map<String, dynamic> j, {
    required List<Map<String, dynamic>> routesJson,
  }) {
    return TaxiOsrmRouteResult(
      distanceMeters: j['distance_value'] as int? ?? 0,
      durationSeconds: j['duration_value'] as int? ?? 0,
      distanceText: j['distance_text']?.toString() ?? '',
      durationText: j['duration_text']?.toString() ?? '',
      cacheHit: j['cache_hit'] == true,
      polylinePoints: _polylineFromRoutes(routesJson),
    );
  }

  final int distanceMeters;
  final int durationSeconds;
  final String distanceText;
  final String durationText;
  final bool cacheHit;
  final List<({double lat, double lng})> polylinePoints;

  static List<({double lat, double lng})> _polylineFromRoutes(
    List<Map<String, dynamic>> routes,
  ) {
    if (routes.isEmpty) return const [];
    final geometry = routes.first['geometry'];
    if (geometry is! Map) return const [];
    final coords = geometry['coordinates'];
    if (coords is! List) return const [];
    return coords
        .map((c) {
          if (c is! List || c.length < 2) return null;
          final lng = (c[0] as num).toDouble();
          final lat = (c[1] as num).toDouble();
          return (lat: lat, lng: lng);
        })
        .whereType<({double lat, double lng})>()
        .toList();
  }
}
