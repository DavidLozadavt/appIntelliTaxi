import 'dart:convert';
import 'dart:math' as math;
import 'package:http/http.dart' as http;
import 'package:intellitaxi/config/app_config.dart';
import 'package:intellitaxi/core/services/app_logger.dart';
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

  // Coordenadas de Popayán, Cauca
  static const double popyanLat = 2.4419;
  static const double popyanLng = -76.6063;
  static const double searchRadiusKm = 20.0; // Radio de búsqueda en km

  /// Busca lugares cercanos limitados a Popayán
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
      AppLogger.d('🔍 Buscando lugares: "$normalized"');

      final url = Uri.parse(
        '$_baseUrl/place/textsearch/json?'
        'query=${Uri.encodeComponent(normalized)}'
        '&location=$popyanLat,$popyanLng'
        '&radius=${searchRadiusKm * 1000}' // Convertir a metros
        '&key=${AppConfig.googleMapsApiKey}'
        '&language=es',
      );

      AppLogger.d('🌐 URL: $url');

      final response = await http.get(url);
      _metrics.searchApiCalls++;
      _metrics.logIfNeeded();
      AppLogger.d('📡 Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        AppLogger.d('📦 Response data status: ${data['status']}');
        _metrics.trackStatus('textsearch', data['status']?.toString());

        if (data['status'] == 'OK') {
          final results = (data['results'] as List)
              .map((place) => PlaceResult.fromJson(place))
              .where((place) => _isNearPopayan(place.lat, place.lng))
              .toList();
          _searchCache[cacheKey] = _CacheEntry(
            value: results,
            expiresAt: DateTime.now().add(_cacheTtl),
          );
          AppLogger.d('✅ Encontrados ${results.length} lugares');
          return results;
        } else if (data['status'] == 'ZERO_RESULTS') {
          AppLogger.d('⚠️ No se encontraron resultados para: "$query"');
          return [];
        } else {
          AppLogger.d('❌ Error de Google API: ${data['status']}');
          if (data['error_message'] != null) {
            AppLogger.d('   Mensaje: ${data['error_message']}');
          }
          return [];
        }
      } else {
        AppLogger.d('❌ Error HTTP: ${response.statusCode}');
        AppLogger.d('   Body: ${response.body}');
      }

      return [];
    } catch (e, stackTrace) {
      AppLogger.d('❌ Error buscando lugares: $e');
      AppLogger.d('   Stack trace: $stackTrace');
      return [];
    }
  }

  /// Autocomplete de lugares limitado a Popayán
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
      AppLogger.d('🔍 Buscando: "$normalized"');

      final url = Uri.parse(
        '$_baseUrl/place/autocomplete/json?'
        'input=${Uri.encodeComponent(normalized)}'
        '&location=$popyanLat,$popyanLng'
        '&radius=${searchRadiusKm * 1000}'
        '&strictbounds=true' // Limitar estrictamente al radio
        '&components=country:co' // Solo Colombia
        '${activeSessionToken == null ? '' : '&sessiontoken=$activeSessionToken'}'
        '&key=${AppConfig.googleMapsApiKey}'
        '&language=es',
      );

      AppLogger.d('🌐 URL: $url');

      final response = await http.get(url);
      _metrics.autocompleteApiCalls++;
      _metrics.logIfNeeded();
      AppLogger.d('📡 Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        AppLogger.d('📦 Response data status: ${data['status']}');
        _metrics.trackStatus('autocomplete', data['status']?.toString());

        if (data['status'] == 'OK') {
          final predictions = (data['predictions'] as List)
              .map((pred) => PlacePrediction.fromJson(pred))
              .toList();
          _autocompleteCache[cacheKey] = _CacheEntry(
            value: predictions,
            expiresAt: DateTime.now().add(_cacheTtl),
          );
          AppLogger.d('✅ Encontrados ${predictions.length} resultados');
          return predictions;
        } else if (data['status'] == 'ZERO_RESULTS') {
          AppLogger.d('⚠️ No se encontraron resultados para: "$input"');
          return [];
        } else {
          AppLogger.d('❌ Error de Google API: ${data['status']}');
          if (data['error_message'] != null) {
            AppLogger.d('   Mensaje: ${data['error_message']}');
          }
          return [];
        }
      } else {
        AppLogger.d('❌ Error HTTP: ${response.statusCode}');
        AppLogger.d('   Body: ${response.body}');
      }

      return [];
    } catch (e, stackTrace) {
      AppLogger.d('❌ Error en autocomplete: $e');
      AppLogger.d('   Stack trace: $stackTrace');
      return [];
    }
  }

  /// Obtiene los detalles de un lugar por su placeId
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
      AppLogger.d('📍 Obteniendo detalles del lugar: $normalizedPlaceId');
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
      AppLogger.d('📡 Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        AppLogger.d('📦 Response data status: ${data['status']}');
        _metrics.trackStatus('details', data['status']?.toString());

        if (data['status'] == 'OK') {
          final placeDetails = PlaceDetails.fromJson(data['result']);
          _detailsCache[normalizedPlaceId] = _CacheEntry(
            value: placeDetails,
            expiresAt: DateTime.now().add(_cacheTtl),
          );
          clearAutocompleteSession();
          AppLogger.d('✅ Detalles obtenidos: ${placeDetails.name}');
          return placeDetails;
        } else {
          AppLogger.d('❌ Error de Google API: ${data['status']}');
          if (data['error_message'] != null) {
            AppLogger.d('   Mensaje: ${data['error_message']}');
          }
        }
      } else {
        AppLogger.d('❌ Error HTTP: ${response.statusCode}');
        AppLogger.d('   Body: ${response.body}');
      }

      return null;
    } catch (e, stackTrace) {
      AppLogger.d('❌ Error obteniendo detalles: $e');
      AppLogger.d('   Stack trace: $stackTrace');
      return null;
    }
  }

  /// Verifica si las coordenadas están cerca de Popayán
  bool _isNearPopayan(double lat, double lng) {
    final distance = _calculateDistance(popyanLat, popyanLng, lat, lng);
    return distance <= searchRadiusKm;
  }

  /// Calcula la distancia entre dos puntos en km (Haversine)
  double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double earthRadius = 6371; // Radio de la Tierra en km

    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);

    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(lat1)) *
            math.cos(_toRadians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);

    final c = 2 * math.asin(math.sqrt(a));

    return earthRadius * c;
  }

  double _toRadians(double degrees) => degrees * (math.pi / 180);

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

/// Modelo para resultado de búsqueda de lugares
class PlaceResult {
  final String placeId;
  final String name;
  final String address;
  final double lat;
  final double lng;

  PlaceResult({
    required this.placeId,
    required this.name,
    required this.address,
    required this.lat,
    required this.lng,
  });

  factory PlaceResult.fromJson(Map<String, dynamic> json) {
    return PlaceResult(
      placeId: json['place_id'] ?? '',
      name: json['name'] ?? '',
      address: json['formatted_address'] ?? '',
      lat: json['geometry']['location']['lat'],
      lng: json['geometry']['location']['lng'],
    );
  }
}

/// Modelo para predicciones de autocomplete
class PlacePrediction {
  final String placeId;
  final String description;
  final String mainText;
  final String secondaryText;

  PlacePrediction({
    required this.placeId,
    required this.description,
    required this.mainText,
    required this.secondaryText,
  });

  factory PlacePrediction.fromJson(Map<String, dynamic> json) {
    return PlacePrediction(
      placeId: json['place_id'] ?? '',
      description: json['description'] ?? '',
      mainText: json['structured_formatting']['main_text'] ?? '',
      secondaryText: json['structured_formatting']['secondary_text'] ?? '',
    );
  }
}

/// Modelo para detalles de un lugar
class PlaceDetails {
  final String name;
  final String address;
  final double lat;
  final double lng;

  PlaceDetails({
    required this.name,
    required this.address,
    required this.lat,
    required this.lng,
  });

  factory PlaceDetails.fromJson(Map<String, dynamic> json) {
    return PlaceDetails(
      name: json['name'] ?? '',
      address: json['formatted_address'] ?? '',
      lat: json['geometry']['location']['lat'],
      lng: json['geometry']['location']['lng'],
    );
  }
}
