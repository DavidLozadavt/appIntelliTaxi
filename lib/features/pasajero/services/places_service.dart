import 'dart:convert';

import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:intellitaxi/config/app_config.dart';
import 'package:intellitaxi/config/maps_config.dart';
import 'package:intellitaxi/core/dio_client.dart';
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

  int get _minAutocompleteChars =>
      MapsConfig.useBackendProxy ? MapsConfig.autocompleteMinChars : 2;

  /// Búsqueda por texto (forward geocode en backend).
  Future<List<PlaceResult>> searchPlaces(String query) async {
    final normalized = query.trim();
    if (normalized.isEmpty) return [];

    if (MapsConfig.useBackendProxy) {
      return _searchPlacesBackend(normalized);
    }
    return _searchPlacesGoogle(normalized);
  }

  Future<List<PlaceResult>> _searchPlacesBackend(String normalized) async {
    final cacheKey = normalized.toLowerCase();
    final cached = _getCached(_searchCache, cacheKey);
    if (cached != null) return cached;

    final results = await _taxiMaps.forwardGeocode(normalized);
    final places = results
        .where((r) => PopayanUrbanArea.contains(r.lat, r.lng))
        .map(
          (r) => PlaceResult(
            placeId: r.placeId,
            name: r.name.isNotEmpty ? r.name : r.address.split(',').first,
            address: r.address,
            lat: r.lat,
            lng: r.lng,
          ),
        )
        .toList();

    _searchCache[cacheKey] = _CacheEntry(
      value: places,
      expiresAt: DateTime.now().add(_cacheTtl),
    );
    return places;
  }

  Future<List<PlaceResult>> _searchPlacesGoogle(String normalized) async {
    final cacheKey = normalized.toLowerCase();
    final cached = _getCached(_searchCache, cacheKey);
    if (cached != null) return cached;

    try {
      final url = Uri.parse(
        '$_googleBaseUrl/place/textsearch/json?'
        'query=${Uri.encodeComponent('$normalized Popayán')}'
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
          _searchCache[cacheKey] = _CacheEntry(
            value: results,
            expiresAt: DateTime.now().add(_cacheTtl),
          );
          return results;
        }
      }
    } catch (e) {
      AppLogger.d('❌ Error buscando lugares: $e');
    }
    return [];
  }

  String? get currentAutocompleteSessionToken => _autocompleteSessionToken;

  void startAutocompleteSession() {
    if (MapsConfig.useBackendProxy) return;
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
      return _autocompleteBackend(normalized);
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
    final dtos = await _taxiMaps.autocomplete(normalized);
    _metrics.autocompleteApiCalls++;

    final predictions = dtos
        .map(
          (d) => PlacePrediction.fromBackendJson({
            'place_id': d.placeId,
            'description': d.description,
            'address': d.address,
            'name': d.name,
            'lat': d.lat,
            'lng': d.lng,
          }),
        )
        .where((p) => PopayanUrbanArea.isPredictionAllowed(p.description))
        .toList();

    _autocompleteCache[cacheKey] = _CacheEntry(
      value: predictions,
      expiresAt: DateTime.now().add(_cacheTtl),
    );
    return predictions;
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
        'input=${Uri.encodeComponent(normalized)}'
        '&location=${PopayanUrbanArea.centerLat},${PopayanUrbanArea.centerLng}'
        '&radius=${(PopayanUrbanArea.maxRadiusKm * 1000).round()}'
        '&bounds=${PopayanUrbanArea.autocompleteBounds}'
        '&strictbounds=true'
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

  /// Sin Places nearby en modo proxy (evita Google).
  Future<PlaceResult?> findNearestPlaceAt(
    double lat,
    double lng, {
    double maxDistanceMeters = 130,
  }) async {
    if (MapsConfig.useBackendProxy) return null;
    if (!PopayanUrbanArea.contains(lat, lng)) return null;

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
