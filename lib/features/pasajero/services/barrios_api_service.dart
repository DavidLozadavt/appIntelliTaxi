import 'package:intellitaxi/core/geo/barrios/barrio.dart';
import 'package:intellitaxi/core/geo/place_precision.dart';
import 'package:intellitaxi/core/services/reverse_geocoding_service.dart';
import 'package:intellitaxi/features/pasajero/services/places_service.dart';

/// Resuelve y busca barrios con los servicios de mapas del backend.
/// No carga geometrías locales: Maps devuelve el nombre del sector, no sus
/// límites oficiales ni un identificador municipal de barrio.
class BarrioResolver {
  BarrioResolver({ReverseGeocodingService? geocoding, PlacesService? places})
    : _geocoding = geocoding ?? ReverseGeocodingService(),
      _places = places ?? PlacesService();

  final ReverseGeocodingService _geocoding;
  final PlacesService _places;

  Future<BarrioResolveResult> resolve(double lat, double lng) async {
    final area = await _geocoding.resolveNearbyGoogleAreaName(
      lat: lat,
      lng: lng,
      maxDistanceMeters: 500,
    );
    final name = PlacePrecision.normalizeNeighborhood(area);
    if (name.isEmpty || !PlacePrecision.isPlausibleNeighborhood(name)) {
      return const BarrioResolveResult(kind: BarrioResolveKind.unknown);
    }

    final barrio = _mapResult(name);
    return BarrioResolveResult(
      kind: BarrioResolveKind.inside,
      match: barrio,
      candidates: [barrio],
    );
  }

  Future<List<Barrio>> search(String query) async {
    final q = query.trim();
    if (q.length < 2) return const [];

    final results = await _places.searchPlaces(
      PlacePrecision.withAreaContext('$q barrio'),
    );
    final seen = <String>{};
    final barrios = <Barrio>[];
    for (final result in results) {
      final name = PlacePrecision.normalizeNeighborhood(
        result.name.isNotEmpty ? result.name : result.address.split(',').first,
      );
      final key = PlacePrecision.normalizeNeighborhood(name).toLowerCase();
      if (!PlacePrecision.isPlausibleNeighborhood(name) || !seen.add(key)) {
        continue;
      }
      barrios.add(_mapResult(name));
    }
    return barrios;
  }

  Barrio _mapResult(String name) => Barrio(
    // Maps no devuelve un ID de barrio municipal. No enviar uno inventado.
    id: 0,
    nombre: name,
    bbox: const [],
    polygons: const [],
  );
}
