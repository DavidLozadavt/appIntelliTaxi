import 'package:dio/dio.dart';
import 'package:intellitaxi/core/services/app_logger.dart';
import 'package:intellitaxi/features/taxi/data/taxi_maps_models.dart';

/// Proxies Laravel: reverse-geocode, places-autocomplete, geocode, ruta-osrm.
class TaxiMapsApiService {
  TaxiMapsApiService(this._dio);

  final Dio _dio;

  static const _base = 'taxi';

  Future<TaxiReverseGeocodeResult?> reverseGeocode(
    double lat,
    double lng,
  ) async {
    try {
      final res = await _dio.get(
        '$_base/reverse-geocode',
        queryParameters: {'lat': lat, 'lng': lng},
      );
      final data = res.data;
      if (data is! Map || data['success'] != true) return null;
      return TaxiReverseGeocodeResult.fromJson(
        Map<String, dynamic>.from(data),
      );
    } on DioException catch (e) {
      _logProxyError('reverse-geocode', e);
      return null;
    }
  }

  Future<List<TaxiPlacePredictionDto>> autocomplete(
    String query, {
    int limit = 5,
  }) async {
    final q = query.trim();
    if (q.length < 3) return [];

    try {
      final res = await _dio.get(
        '$_base/places-autocomplete',
        queryParameters: {'q': q, 'limit': limit},
      );
      final data = res.data;
      if (data is! Map || data['success'] != true) return [];
      final list = data['predictions'] as List? ?? [];
      return list
          .whereType<Map>()
          .map(
            (e) => TaxiPlacePredictionDto.fromJson(
              Map<String, dynamic>.from(e),
            ),
          )
          .toList();
    } on DioException catch (e) {
      _logProxyError('places-autocomplete', e);
      return [];
    }
  }

  Future<List<TaxiForwardGeocodeResult>> forwardGeocode(
    String query, {
    int limit = 5,
  }) async {
    final q = query.trim();
    if (q.isEmpty) return [];

    try {
      final res = await _dio.get(
        '$_base/geocode',
        queryParameters: {'q': q, 'limit': limit},
      );
      final data = res.data;
      if (data is! Map || data['success'] != true) return [];
      final list = data['results'] as List? ?? [];
      return list
          .whereType<Map>()
          .map(
            (e) => TaxiForwardGeocodeResult.fromJson(
              Map<String, dynamic>.from(e),
            ),
          )
          .toList();
    } on DioException catch (e) {
      _logProxyError('geocode', e);
      return [];
    }
  }

  Future<TaxiOsrmRouteResult?> calcularRuta({
    required double fromLat,
    required double fromLng,
    required double toLat,
    required double toLng,
  }) async {
    try {
      final res = await _dio.get(
        '$_base/ruta-osrm',
        queryParameters: {
          'from_lat': fromLat,
          'from_lng': fromLng,
          'to_lat': toLat,
          'to_lng': toLng,
        },
      );
      final data = res.data;
      if (data is! Map || data['success'] != true) return null;

      final map = Map<String, dynamic>.from(data);
      final routesRaw = map['routes'] as List? ?? [];
      final routesJson = routesRaw
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();

      return TaxiOsrmRouteResult.fromJson(map, routesJson: routesJson);
    } on DioException catch (e) {
      _logProxyError('ruta-osrm', e);
      return null;
    }
  }

  void _logProxyError(String op, DioException e) {
    final status = e.response?.statusCode;
    if (status == 429) {
      AppLogger.w(
        'Maps proxy $op: rate limit (429). No reintentar de inmediato.',
        tag: 'TaxiMapsProxy',
      );
      return;
    }
    if (status == 502) {
      AppLogger.w(
        'Maps proxy $op: servicio no disponible (502).',
        tag: 'TaxiMapsProxy',
      );
      return;
    }
    AppLogger.w(
      'Maps proxy $op: ${e.message} status=$status',
      tag: 'TaxiMapsProxy',
    );
  }
}
