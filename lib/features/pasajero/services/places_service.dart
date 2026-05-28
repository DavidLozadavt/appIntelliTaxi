import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intellitaxi/config/app_config.dart';
import 'package:intellitaxi/core/geo/popayan_urban_area.dart';
import 'package:intellitaxi/core/services/app_logger.dart';
import 'package:intellitaxi/features/pasajero/model/place_details_model.dart';
import 'package:uuid/uuid.dart';

class PlacesService {
  static const String _baseUrl = 'https://maps.googleapis.com/maps/api';
  static const Duration _cacheTtl = Duration(minutes: 10);
  static const Duration _sessionTtl = Duration(minutes: 3);
  static const int _minAutocompleteChars = 2;
  static const Uuid _uuid = Uuid();

  final Map<String, _CacheEntry<List<PlaceResult>>> _searchCache = {};
  final Map<String, _CacheEntry<List<PlacePrediction>>> _autocompleteCache = {};
  final Map<String, _CacheEntry<PlaceDetails>> _detailsCache = {};
  final _PlacesMetrics _metrics = _PlacesMetrics();

  String? _autocompleteSessionToken;
  DateTime? _autocompleteSessionStartedAt;

  /// Busca lugares dentro del perímetro urbano de Popayán.
  Future<List<PlaceResult>> searchPlaces(String query) async {
    final normalized = query.trim();
    if (normalized.isEmpty) return [];
    final cacheKey = normalized.toLowerCase();
    final cached = _getCached(_searchCache, cacheKey);
    if (cached != null) {
      _metrics.searchCacheHits++;
      _metrics.logIfNeeded();
      return cached;
    }

    try {
      AppLogger.d('🔍 Buscando lugares (urbano Popayán): "$normalized"');

      final url = Uri.parse(
        '$_baseUrl/place/textsearch/json?'
        'query=${Uri.encodeComponent('$normalized Popayán')}'
        '&location=${PopayanUrbanArea.centerLat},${PopayanUrbanArea.centerLng}'
        '&radius=${(PopayanUrbanArea.maxRadiusKm * 1000).round()}'
        '&key=${AppConfig.googleMapsApiKey}'
        '&language=es',
      );

      final response = await http.get(url);
      _metrics.searchApiCalls++;
      _metrics.logIfNeeded();

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _metrics.trackStatus('textsearch', data['status']?.toString());

        if (data['status'] == 'OK') {
          final results = (data['results'] as List)
              .map((place) => PlaceResult.fromJson(place))
              .where(
                (place) => PopayanUrbanArea.contains(place.lat, place.lng),
              )
              .toList();
          _searchCache[cacheKey] = _CacheEntry(
            value: results,
            expiresAt: DateTime.now().add(_cacheTtl),
          );
          AppLogger.d('✅ Encontrados ${results.length} lugares en urbano');
          return results;
        } else if (data['status'] == 'ZERO_RESULTS') {
          return [];
        } else {
          AppLogger.d('❌ Error de Google API: ${data['status']}');
          return [];
        }
      }

      return [];
    } catch (e, stackTrace) {
      AppLogger.d('❌ Error buscando lugares: $e');
      AppLogger.d('   Stack trace: $stackTrace');
      return [];
    }
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

  /// Autocomplete restringido al perímetro urbano de Popayán.
  Future<List<PlacePrediction>> getAutocompletePredictions(
    String input, {
    String? sessionToken,
  }) async {
    final normalized = input.trim();
    if (normalized.length < _minAutocompleteChars) return [];
    startAutocompleteSession();

    final activeSessionToken = sessionToken ?? _autocompleteSessionToken;
    final cacheKey =
        '${normalized.toLowerCase()}::${activeSessionToken ?? "no-session"}';
    final cached = _getCached(_autocompleteCache, cacheKey);
    if (cached != null) {
      _metrics.autocompleteCacheHits++;
      _metrics.logIfNeeded();
      return cached;
    }

    try {
      AppLogger.d('🔍 Autocomplete urbano Popayán: "$normalized"');

      final url = Uri.parse(
        '$_baseUrl/place/autocomplete/json?'
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
      _metrics.autocompleteApiCalls++;
      _metrics.logIfNeeded();

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _metrics.trackStatus('autocomplete', data['status']?.toString());

        if (data['status'] == 'OK') {
          final predictions = (data['predictions'] as List)
              .map((pred) => PlacePrediction.fromJson(pred))
              .where(
                (pred) => PopayanUrbanArea.isPredictionAllowed(pred.description),
              )
              .toList();
          _autocompleteCache[cacheKey] = _CacheEntry(
            value: predictions,
            expiresAt: DateTime.now().add(_cacheTtl),
          );
          AppLogger.d('✅ ${predictions.length} sugerencias en urbano');
          return predictions;
        } else if (data['status'] == 'ZERO_RESULTS') {
          return [];
        } else {
          AppLogger.d('❌ Error de Google API: ${data['status']}');
          return [];
        }
      }

      return [];
    } catch (e, stackTrace) {
      AppLogger.d('❌ Error en autocomplete: $e');
      AppLogger.d('   Stack trace: $stackTrace');
      return [];
    }
  }

  /// Detalles del lugar; `null` si queda fuera del perímetro urbano.
  Future<PlaceDetails?> getPlaceDetails(
    String placeId, {
    String? sessionToken,
  }) async {
    final normalizedPlaceId = placeId.trim();
    if (normalizedPlaceId.isEmpty) return null;
    final cached = _getCached(_detailsCache, normalizedPlaceId);
    if (cached != null) {
      _metrics.detailsCacheHits++;
      _metrics.logIfNeeded();
      return cached;
    }

    try {
      final activeSessionToken = sessionToken ?? _autocompleteSessionToken;

      final url = Uri.parse(
        '$_baseUrl/place/details/json?'
        'place_id=$normalizedPlaceId'
        '&fields=name,formatted_address,geometry'
        '${activeSessionToken == null ? '' : '&sessiontoken=$activeSessionToken'}'
        '&key=${AppConfig.googleMapsApiKey}'
        '&language=es',
      );

      final response = await http.get(url);
      _metrics.detailsApiCalls++;
      _metrics.logIfNeeded();

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _metrics.trackStatus('details', data['status']?.toString());

        if (data['status'] == 'OK') {
          var placeDetails = PlaceDetails.fromJson(data['result']);
          final refined = await _refineCoordinatesViaGeocodePlaceId(
            normalizedPlaceId,
          );
          if (refined != null) {
            placeDetails = PlaceDetails(
              name: placeDetails.name,
              address: placeDetails.address,
              lat: refined.$1,
              lng: refined.$2,
            );
          }
          if (!PopayanUrbanArea.contains(placeDetails.lat, placeDetails.lng)) {
            AppLogger.w(
              'Lugar fuera del urbano de Popayán: ${placeDetails.address}',
              tag: 'PlacesService',
            );
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

      return null;
    } catch (e, stackTrace) {
      AppLogger.d('❌ Error obteniendo detalles: $e');
      AppLogger.d('   Stack trace: $stackTrace');
      return null;
    }
  }

  /// Geocode por `place_id` priorizando ROOFTOP / RANGE_INTERPOLATED (más preciso que autocomplete).
  Future<(double, double)?> _refineCoordinatesViaGeocodePlaceId(
    String placeId,
  ) async {
    try {
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/geocode/json?'
        'place_id=${Uri.encodeComponent(placeId)}'
        '&key=${AppConfig.googleMapsApiKey}&language=es',
      );
      final response = await http.get(url);
      if (response.statusCode != 200) return null;
      final data = json.decode(response.body) as Map<String, dynamic>;
      if (data['status'] != 'OK') return null;
      final results = data['results'] as List<dynamic>? ?? [];
      if (results.isEmpty) return null;

      Map<String, dynamic>? best;
      for (final item in results) {
        if (item is! Map) continue;
        final m = Map<String, dynamic>.from(item);
        final locType =
            (m['geometry'] as Map?)?['location_type']?.toString() ?? '';
        if (locType == 'ROOFTOP' || locType == 'RANGE_INTERPOLATED') {
          best = m;
          break;
        }
        best ??= m;
      }
      final geometry = best?['geometry'] as Map<String, dynamic>?;
      final loc = geometry?['location'] as Map<String, dynamic>?;
      final lat = (loc?['lat'] as num?)?.toDouble();
      final lng = (loc?['lng'] as num?)?.toDouble();
      if (lat == null || lng == null) return null;
      return (lat, lng);
    } catch (e) {
      AppLogger.d('⚠️ Geocode place_id refine: $e');
      return null;
    }
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
  int searchApiCalls = 0;
  int searchCacheHits = 0;
  int autocompleteApiCalls = 0;
  int autocompleteCacheHits = 0;
  int detailsApiCalls = 0;
  int detailsCacheHits = 0;
  int _lastLoggedTotal = 0;
  final Map<String, int> statusCounters = {};

  void logIfNeeded() {
    final total = totalApiCalls + totalCacheHits;
    if (total - _lastLoggedTotal < 15) return;
    _lastLoggedTotal = total;
    AppLogger.i(
      '📊 MAPS Places ahorro | api=$totalApiCalls cache_hits=$totalCacheHits ahorro=${cacheHitRate.toStringAsFixed(1)}%',
      tag: 'MapsMetrics',
    );
  }

  int get totalApiCalls =>
      searchApiCalls + autocompleteApiCalls + detailsApiCalls;
  int get totalCacheHits =>
      searchCacheHits + autocompleteCacheHits + detailsCacheHits;

  void trackStatus(String operation, String? status) {
    final normalized = (status == null || status.isEmpty) ? 'UNKNOWN' : status;
    final key = '$operation:$normalized';
    statusCounters[key] = (statusCounters[key] ?? 0) + 1;

    if (normalized != 'OK' && normalized != 'ZERO_RESULTS') {
      AppLogger.w(
        'Places API status no exitoso | op=$operation status=$normalized counters=$statusCounters',
        tag: 'MapsMetrics',
      );
    }
  }

  double get cacheHitRate {
    final denominator = totalApiCalls + totalCacheHits;
    if (denominator == 0) return 0;
    return (totalCacheHits / denominator) * 100;
  }
}
