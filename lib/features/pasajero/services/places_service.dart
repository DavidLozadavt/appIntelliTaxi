import 'dart:convert';

import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:intellitaxi/config/app_config.dart';
import 'package:intellitaxi/config/maps_config.dart';
import 'package:intellitaxi/core/dio_client.dart';
import 'package:intellitaxi/core/geo/place_precision.dart';
import 'package:intellitaxi/core/geo/popayan_urban_area.dart';
import 'package:intellitaxi/core/services/app_logger.dart';
import 'package:intellitaxi/features/pasajero/model/place_details_model.dart';
import 'package:intellitaxi/features/taxi/services/taxi_maps_api_service.dart';
import 'package:uuid/uuid.dart';

class PlacesService {
  PlacesService({TaxiMapsApiService? taxiMaps})
      : _taxiMaps = taxiMaps ?? TaxiMapsApiService(DioClient.getInstance());

  static const String _googleBaseUrl = 'https://maps.googleapis.com/maps/api';
  static const Duration _cacheTtl = Duration(minutes: 45);
  static const Duration _sessionTtl = Duration(minutes: 3);
  static const Uuid _uuid = Uuid();

  /// Cuántos candidatos pide al geocoder.
  ///
  /// El backend valida el límite: `taxi/places-autocomplete` y `taxi/geocode`
  /// rechazan con "The limit must not be greater than 10" cualquier valor
  /// mayor, y responden `success: false` sin predicciones (la búsqueda
  /// quedaba vacía sin error visible).
  ///
  /// Se piden más de los que se muestran para poder descartar los que caen
  /// fuera del área y aun así tener sugerencias locales.
  static const int _backendCandidateLimit = TaxiMapsApiService.maxResultsPerRequest;

  /// Máximo de sugerencias que se devuelven al usuario.
  static const int _maxResults = 5;

  /// Vigencia de la posición del usuario usada para ordenar por cercanía.
  static const Duration _searchContextTtl = Duration(minutes: 10);

  final TaxiMapsApiService _taxiMaps;

  final Map<String, _CacheEntry<List<PlaceResult>>> _searchCache = {};
  final Map<String, _CacheEntry<List<PlacePrediction>>> _autocompleteCache = {};
  final Map<String, _CacheEntry<PlaceDetails>> _detailsCache = {};
  final _PlacesMetrics _metrics = _PlacesMetrics();

  static const Set<String> _mapPoiTypes = {
    'shopping_mall',
    'establishment',
    'store',
    'point_of_interest',
    'food',
    'lodging',
  };

  String? _autocompleteSessionToken;
  DateTime? _autocompleteSessionStartedAt;

  /// Posición del usuario: define el "acá" contra el que se ordenan los
  /// resultados para que salgan primero los lugares más cercanos.
  double? _contextLat;
  double? _contextLng;
  DateTime? _contextUpdatedAt;

  int get _minAutocompleteChars =>
      MapsConfig.useBackendProxy ? MapsConfig.autocompleteMinChars : 2;

  /// Actualiza el punto de referencia para ordenar resultados por cercanía.
  ///
  /// Se llama cuando el GPS entrega una posición (pasajero o conductor).
  /// Si el usuario se aleja mucho, el contexto se re-anchoriza solo.
  void updateSearchContext({required double lat, required double lng}) {
    if (!lat.isFinite || !lng.isFinite) return;
    if (!PopayanUrbanArea.contains(lat, lng)) {
      // Fuera del área de servicio: el contexto no sirve para ordenar.
      _contextLat = null;
      _contextLng = null;
      _contextUpdatedAt = null;
      return;
    }
    final previousLat = _contextLat;
    final previousLng = _contextLng;
    if (previousLat != null && previousLng != null) {
      final drift = PlacePrecision.distanceMeters(
        previousLat,
        previousLng,
        lat,
        lng,
      );
      // Re-anchoriza solo si se movió lo suficiente como para cambiar el orden.
      if (drift < 150) {
        _contextUpdatedAt = DateTime.now();
        return;
      }
    }
    _contextLat = lat;
    _contextLng = lng;
    _contextUpdatedAt = DateTime.now();
  }

  /// Contexto de búsqueda vigente (si no está vencido).
  ({double lat, double lng})? get _searchContext {
    final lat = _contextLat;
    final lng = _contextLng;
    final updatedAt = _contextUpdatedAt;
    if (lat == null || lng == null || updatedAt == null) return null;
    if (DateTime.now().difference(updatedAt) > _searchContextTtl) return null;
    return (lat: lat, lng: lng);
  }

  /// Búsqueda por texto (forward geocode en backend).
  Future<List<PlaceResult>> searchPlaces(String query) async {
    final normalized = query.trim();
    if (normalized.isEmpty) return [];

    if (MapsConfig.useBackendProxy) {
      final backend = await _searchPlacesBackend(normalized);
      if (backend.isNotEmpty) return backend;
      return _searchPlacesGoogle(normalized);
    }
    return _searchPlacesGoogle(normalized);
  }

  Future<List<PlaceResult>> _searchPlacesBackend(String normalized) async {
    final cacheKey = normalized.toLowerCase();
    final cached = _getCached(_searchCache, cacheKey);
    if (cached != null) return cached;

    // El backend ya ancla la búsqueda a Popayán (verificado: "carrera 5"
    // devuelve 10 resultados locales). Aquí solo se filtran los que caen
    // fuera del área y se ordenan por cercanía.
    final results = await _taxiMaps.forwardGeocode(
      normalized,
      limit: _backendCandidateLimit,
    );

    final places = <PlaceResult>[];
    for (final r in results) {
      if (!_isInsideServiceArea(r.lat, r.lng, r.address)) continue;
      places.add(
        PlaceResult(
          placeId: r.placeId,
          name: r.name.isNotEmpty ? r.name : r.address.split(',').first,
          address: r.address,
          lat: r.lat,
          lng: r.lng,
        ),
      );
    }

    final ranked = _rankByProximity(places);
    _searchCache[cacheKey] = _CacheEntry(
      value: ranked,
      expiresAt: DateTime.now().add(_cacheTtl),
    );
    return ranked;
  }

  Future<List<PlaceResult>> _searchPlacesGoogle(String normalized) async {
    final cacheKey = normalized.toLowerCase();
    final cached = _getCached(_searchCache, cacheKey);
    if (cached != null) return cached;

    try {
      final url = Uri.parse(
        '$_googleBaseUrl/place/textsearch/json?'
        'query=${Uri.encodeComponent(PlacePrecision.withAreaContext(normalized))}'
        '&location=${PopayanUrbanArea.centerLat},${PopayanUrbanArea.centerLng}'
        '&radius=${(PopayanUrbanArea.maxRadiusKm * 1000).round()}'
        '&key=${AppConfig.googleMapsApiKey}'
        '&language=es',
      );
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK') {
          final results = (data['results'] as List)
              .map((place) => PlaceResult.fromJson(place))
              .where((p) => PopayanUrbanArea.contains(p.lat, p.lng))
              .toList();
          final ranked = _rankByProximity(results);
          _searchCache[cacheKey] = _CacheEntry(
            value: ranked,
            expiresAt: DateTime.now().add(_cacheTtl),
          );
          return ranked;
        }
      }
    } catch (e) {
      AppLogger.d('❌ Error buscando lugares: $e');
    }
    return [];
  }

  String? get currentAutocompleteSessionToken => _autocompleteSessionToken;

  void startAutocompleteSession() {
    final now = DateTime.now();
    final isExpired =
        _autocompleteSessionStartedAt == null ||
        now.difference(_autocompleteSessionStartedAt!) > _sessionTtl;
    if (_autocompleteSessionToken == null || isExpired) {
      _autocompleteSessionToken = _uuid.v4();
      _autocompleteSessionStartedAt = now;
    }
  }

  void clearAutocompleteSession() {
    _autocompleteSessionToken = null;
    _autocompleteSessionStartedAt = null;
  }

  Future<List<PlacePrediction>> getAutocompletePredictions(
    String input, {
    String? sessionToken,
  }) async {
    final normalized = input.trim();
    if (normalized.length < _minAutocompleteChars) return [];

    if (MapsConfig.useBackendProxy) {
      final backend = await _autocompleteBackend(normalized);
      if (backend.isNotEmpty) return backend;
      return _autocompleteGoogle(normalized, sessionToken);
    }
    return _autocompleteGoogle(normalized, sessionToken);
  }

  Future<List<PlacePrediction>> _autocompleteBackend(String normalized) async {
    final cacheKey = normalized.toLowerCase();
    final cached = _getCached(_autocompleteCache, cacheKey);
    if (cached != null) {
      _metrics.autocompleteCacheHits++;
      return cached;
    }

    AppLogger.d('🔍 Autocomplete backend: "$normalized"');
    final dtos = await _taxiMaps.autocomplete(
      normalized,
      limit: _backendCandidateLimit,
    );
    _metrics.autocompleteApiCalls++;

    final predictions = <PlacePrediction>[];
    for (final d in dtos) {
      // Filtro por coordenadas reales: el texto puede no mencionar la
      // ciudad y el geocoder igual devuelve un punto de Cali o Bogotá.
      if (!_isInsideServiceArea(d.lat, d.lng, d.description)) continue;
      if (!PopayanUrbanArea.isPredictionAllowed(d.description)) continue;

      predictions.add(
        PlacePrediction.fromBackendJson({
          'place_id': d.placeId,
          'description': d.description,
          'address': d.address,
          'name': d.name,
          'lat': d.lat,
          'lng': d.lng,
        }),
      );
    }

    final ranked = _rankPredictionsByProximity(predictions);
    if (ranked.isNotEmpty) {
      final detalle = ranked
          .take(3)
          .map(
            (p) =>
                '${p.mainText}'
                '${p.distanceMeters == null ? '' : ' (${PlacePrecision.formatDistance(p.distanceMeters!)})'}',
          )
          .join(' · ');
      AppLogger.d('   → $detalle');
    }
    _autocompleteCache[cacheKey] = _CacheEntry(
      value: ranked,
      expiresAt: DateTime.now().add(_cacheTtl),
    );
    return ranked;
  }

  Future<List<PlacePrediction>> _autocompleteGoogle(
    String normalized,
    String? sessionToken,
  ) async {
    startAutocompleteSession();
    final activeSessionToken = sessionToken ?? _autocompleteSessionToken;
    final cacheKey =
        '${normalized.toLowerCase()}::${activeSessionToken ?? "no-session"}';
    final cached = _getCached(_autocompleteCache, cacheKey);
    if (cached != null) return cached;

    try {
      final url = Uri.parse(
        '$_googleBaseUrl/place/autocomplete/json?'
        'input=${Uri.encodeComponent(PlacePrecision.withAreaContext(normalized))}'
        '&location=${PopayanUrbanArea.centerLat},${PopayanUrbanArea.centerLng}'
        '&radius=${(PopayanUrbanArea.maxRadiusKm * 1000).round()}'
        '&bounds=${PopayanUrbanArea.autocompleteBounds}'
        '&components=country:co'
        '${activeSessionToken == null ? '' : '&sessiontoken=$activeSessionToken'}'
        '&key=${AppConfig.googleMapsApiKey}'
        '&language=es',
      );
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK') {
          final predictions = (data['predictions'] as List)
              .map((pred) => PlacePrediction.fromGoogleJson(pred))
              .where(
                (pred) => PopayanUrbanArea.isPredictionAllowed(pred.description),
              )
              .toList();
          _autocompleteCache[cacheKey] = _CacheEntry(
            value: predictions,
            expiresAt: DateTime.now().add(_cacheTtl),
          );
          return predictions;
        }
      }
    } catch (e) {
      AppLogger.d('❌ Error en autocomplete Google: $e');
    }
    return [];
  }

  /// Lugar cercano al punto, para nombrar el punto de recogida.
  ///
  /// En modo proxy no hay Places Nearby, así que se resuelve con el
  /// reverse-geocode del backend: devuelve la vía/comercio del punto.
  /// Antes de esto devolvía `null` y el conductor nunca recibía el nombre
  /// del lugar de recogida.
  Future<PlaceResult?> findNearestPlaceAt(
    double lat,
    double lng, {
    double maxDistanceMeters = 130,
  }) async {
    if (!PopayanUrbanArea.contains(lat, lng)) return null;
    if (MapsConfig.useBackendProxy) {
      final viaProxy = await _findNearestPlaceViaProxy(
        lat,
        lng,
        maxDistanceMeters,
      );
      if (viaProxy != null) return viaProxy;
    }

    try {
      final url = Uri.parse(
        '$_googleBaseUrl/place/nearbysearch/json?'
        'location=$lat,$lng'
        '&radius=${maxDistanceMeters.round()}'
        '&key=${AppConfig.googleMapsApiKey}'
        '&language=es',
      );
      final response = await http.get(url);
      if (response.statusCode != 200) return null;

      final data = json.decode(response.body) as Map<String, dynamic>;
      if (data['status'] != 'OK') return null;

      PlaceResult? best;
      var bestScore = double.negativeInfinity;
      for (final raw in data['results'] as List<dynamic>? ?? []) {
        if (raw is! Map) continue;
        final place = PlaceResult.fromJson(Map<String, dynamic>.from(raw));
        if (!PopayanUrbanArea.contains(place.lat, place.lng)) continue;
        final distance = Geolocator.distanceBetween(
          lat,
          lng,
          place.lat,
          place.lng,
        );
        if (distance > maxDistanceMeters) continue;
        final types = (raw['types'] as List<dynamic>? ?? [])
            .map((e) => e.toString())
            .toSet();
        final poiBoost = types.any(_mapPoiTypes.contains) ? 40.0 : 0.0;
        final score = poiBoost - distance;
        if (score > bestScore) {
          bestScore = score;
          best = place;
        }
      }
      return best;
    } catch (e) {
      AppLogger.d('❌ Error nearby: $e');
      return null;
    }
  }

  /// Versión proxy de [findNearestPlaceAt]: usa el reverse-geocode del
  /// backend para nombrar el punto (vía + comercio cuando aparece).
  Future<PlaceResult?> _findNearestPlaceViaProxy(
    double lat,
    double lng,
    double maxDistanceMeters,
  ) async {
    final result = await _taxiMaps.reverseGeocode(lat, lng);
    if (result == null) return null;

    // El backend devuelve el punto que realmente geocodificó: si está
    // lejos del consultado, es otro sector y no sirve.
    final drift = PlacePrecision.distanceMeters(
      lat,
      lng,
      result.lat,
      result.lng,
    );
    if (drift > maxDistanceMeters) {
      AppLogger.d(
        '🗺️ Reverse proxy desalineado (${drift.round()} m) para nearby',
        tag: 'PlacesService',
      );
      return null;
    }

    final address = result.address?.trim() ?? '';
    final zona = result.zona?.trim() ?? '';
    final barrio = result.barrio?.trim() ?? '';

    // El nombre corto es el comercio o la vía; la dirección completa es
    // todo lo que devolvió el backend.
    var name = address.isNotEmpty ? address.split(',').first.trim() : '';
    if (name.isEmpty) name = zona;
    if (name.isEmpty) name = barrio;
    if (name.isEmpty) return null;

    final fullAddress = address.isNotEmpty
        ? address
        : [zona, barrio].where((e) => e.isNotEmpty).join(', ');

    return PlaceResult(
      placeId: result.provider != null && result.provider!.isNotEmpty
          ? 'nominatim:${result.lat},${result.lng}'
          : '',
      name: name,
      address: fullAddress.isEmpty ? name : fullAddress,
      lat: lat,
      lng: lng,
    );
  }

  /// Predicción del backend ya trae lat/lng — sin place details extra.
  Future<PlaceDetails?> resolvePrediction(PlacePrediction prediction) async {
    if (MapsConfig.useBackendProxy && prediction.hasCoordinates) {
      if (!PopayanUrbanArea.contains(prediction.lat!, prediction.lng!)) {
        return null;
      }
      return PlaceDetails(
        name: prediction.mainText.isNotEmpty
            ? prediction.mainText
            : prediction.description,
        address: prediction.description,
        lat: prediction.lat!,
        lng: prediction.lng!,
      );
    }
    return getPlaceDetails(prediction.placeId);
  }

  Future<PlaceDetails?> getPlaceDetails(
    String placeId, {
    String? sessionToken,
  }) async {
    final normalizedPlaceId = placeId.trim();
    if (normalizedPlaceId.isEmpty) return null;

    if (MapsConfig.useBackendProxy) {
      return _placeDetailsFromNominatimIdAsync(normalizedPlaceId);
    }

    final cached = _getCached(_detailsCache, normalizedPlaceId);
    if (cached != null) return cached;

    try {
      final activeSessionToken = sessionToken ?? _autocompleteSessionToken;
      final url = Uri.parse(
        '$_googleBaseUrl/place/details/json?'
        'place_id=$normalizedPlaceId'
        '&fields=name,formatted_address,geometry'
        '${activeSessionToken == null ? '' : '&sessiontoken=$activeSessionToken'}'
        '&key=${AppConfig.googleMapsApiKey}'
        '&language=es',
      );
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK') {
          var placeDetails = PlaceDetails.fromJson(data['result']);
          if (!PopayanUrbanArea.contains(placeDetails.lat, placeDetails.lng)) {
            return null;
          }
          _detailsCache[normalizedPlaceId] = _CacheEntry(
            value: placeDetails,
            expiresAt: DateTime.now().add(_cacheTtl),
          );
          clearAutocompleteSession();
          return placeDetails;
        }
      }
    } catch (e) {
      AppLogger.d('❌ Error place details: $e');
    }
    return null;
  }

  Future<PlaceDetails?> _placeDetailsFromNominatimIdAsync(String placeId) async {
    if (!placeId.startsWith('nominatim:')) return null;
    final parts = placeId.split(':');
    if (parts.length < 3) return null;
    final lat = double.tryParse(parts[1]);
    final lng = double.tryParse(parts[2]);
    if (lat == null || lng == null) return null;
    if (!PopayanUrbanArea.contains(lat, lng)) return null;

    final r = await _taxiMaps.reverseGeocode(lat, lng);
    final addr = r?.address?.trim() ?? '';
    final name = addr.isNotEmpty
        ? addr.split(',').first.trim()
        : (r?.barrio?.trim().isNotEmpty == true ? r!.barrio! : 'Destino');
    return PlaceDetails(
      name: name,
      address: addr.isNotEmpty ? addr : name,
      lat: lat,
      lng: lng,
    );
  }

  T? _getCached<T>(Map<String, _CacheEntry<T>> cache, String key) {
    final entry = cache[key];
    if (entry == null) return null;
    if (DateTime.now().isAfter(entry.expiresAt)) {
      cache.remove(key);
      return null;
    }
    return entry.value;
  }

  /// El punto tiene que estar realmente dentro del área de servicio.
  ///
  /// El filtro por texto (que busca el nombre de la ciudad) no alcanza: hay
  /// direcciones que no mencionan la ciudad y aun así pertenecen a otra.
  bool _isInsideServiceArea(double lat, double lng, String? description) {
    if (!lat.isFinite || !lng.isFinite) return false;
    if (!PopayanUrbanArea.contains(lat, lng)) return false;
    if (description == null || description.isEmpty) return true;
    return PopayanUrbanArea.isPredictionAllowed(description);
  }

  /// Ordena los resultados de búsqueda por cercanía al usuario.
  List<PlaceResult> _rankByProximity(List<PlaceResult> places) {
    if (places.isEmpty) return places;

    final deduped = PlacePrecision.dedupeByProximity(
      places,
      latOf: (p) => p.lat,
      lngOf: (p) => p.lng,
      keyOf: (p) => p.name.isNotEmpty ? p.name : p.address,
    );

    final context = _searchContext;
    if (context == null) {
      return deduped.take(_maxResults).toList();
    }

    final sorted = PlacePrecision.sortByProximity(
      deduped,
      originLat: context.lat,
      originLng: context.lng,
      latOf: (p) => p.lat,
      lngOf: (p) => p.lng,
    );
    return sorted.take(_maxResults).toList();
  }

  /// Igual que [_rankByProximity] pero además deja la distancia calculada
  /// en cada predicción para poder mostrarla en la lista.
  List<PlacePrediction> _rankPredictionsByProximity(
    List<PlacePrediction> predictions,
  ) {
    if (predictions.isEmpty) return predictions;

    final context = _searchContext;
    final withDistance = <PlacePrediction>[];
    for (final p in predictions) {
      if (context == null || !p.hasCoordinates) {
        withDistance.add(p);
        continue;
      }
      final meters = PlacePrecision.distanceMeters(
        context.lat,
        context.lng,
        p.lat!,
        p.lng!,
      );
      withDistance.add(p.copyWith(distanceMeters: meters));
    }

    final deduped = PlacePrecision.dedupeByProximity(
      withDistance,
      latOf: (p) => p.lat ?? double.nan,
      lngOf: (p) => p.lng ?? double.nan,
      keyOf: (p) => p.mainText.isNotEmpty ? p.mainText : p.description,
    );

    if (context == null) return deduped.take(_maxResults).toList();

    final sorted = PlacePrecision.sortByProximity(
      deduped,
      originLat: context.lat,
      originLng: context.lng,
      latOf: (p) => p.lat ?? double.nan,
      lngOf: (p) => p.lng ?? double.nan,
    );
    return sorted.take(_maxResults).toList();
  }
}

class _CacheEntry<T> {
  final T value;
  final DateTime expiresAt;

  const _CacheEntry({required this.value, required this.expiresAt});
}

class _PlacesMetrics {
  int autocompleteApiCalls = 0;
  int autocompleteCacheHits = 0;
}
