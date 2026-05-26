import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:intellitaxi/config/app_config.dart';
import 'package:intellitaxi/core/services/app_logger.dart';

class RoutesService {
  final PolylinePoints _polylinePoints = PolylinePoints();
  static const Duration _routeCacheTtl = Duration(minutes: 5);
  final Map<String, _RouteCacheEntry> _routeCache = {};
  final _RoutesMetrics _metrics = _RoutesMetrics();

  /// Obtiene la ruta entre dos puntos
  Future<RouteInfo?> getRoute({
    required LatLng origin,
    required LatLng destination,
  }) async {
    final routeKey = _buildRouteKey(origin, destination);
    final cached = _routeCache[routeKey];
    if (cached != null && DateTime.now().isBefore(cached.expiresAt)) {
      _metrics.cacheHits++;
      _metrics.logIfNeeded();
      return cached.routeInfo;
    }

    try {
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/directions/json?'
        'origin=${origin.latitude},${origin.longitude}'
        '&destination=${destination.latitude},${destination.longitude}'
        '&mode=driving'
        '&key=${AppConfig.googleMapsApiKey}'
        '&language=es',
      );

      final response = await http
          .get(url)
          .timeout(const Duration(seconds: 4));
      _metrics.apiCalls++;
      _metrics.logIfNeeded();

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] == 'OK' && data['routes'].isNotEmpty) {
          final route = data['routes'][0];
          final leg = route['legs'][0];

          // Decodificar la polilínea
          final polylineString = route['overview_polyline']['points'];
          final polylineCoordinates = _decodePolyline(polylineString);

          final routeInfo = RouteInfo(
            polylinePoints: polylineCoordinates,
            distance: leg['distance']['text'],
            distanceValue: leg['distance']['value'], // en metros
            duration: leg['duration']['text'],
            durationValue: leg['duration']['value'], // en segundos
            startAddress: leg['start_address'],
            endAddress: leg['end_address'],
          );

          _routeCache[routeKey] = _RouteCacheEntry(
            routeInfo: routeInfo,
            expiresAt: DateTime.now().add(_routeCacheTtl),
          );
          return routeInfo;
        }
      }

      return null;
    } catch (e) {
      AppLogger.d('Error obteniendo ruta: $e');
      return null;
    }
  }

  /// Decodifica una polilínea de Google Maps
  List<LatLng> _decodePolyline(String encoded) {
    final List<PointLatLng> points = _polylinePoints.decodePolyline(encoded);
    return points
        .map((point) => LatLng(point.latitude, point.longitude))
        .toList();
  }

  // Nota: El precio no se calcula aquí porque funciona con taxímetro

  String _buildRouteKey(LatLng origin, LatLng destination) {
    String normalize(double value) => value.toStringAsFixed(4);
    return '${normalize(origin.latitude)},${normalize(origin.longitude)}'
        '->${normalize(destination.latitude)},${normalize(destination.longitude)}';
  }
}

class _RouteCacheEntry {
  final RouteInfo routeInfo;
  final DateTime expiresAt;

  const _RouteCacheEntry({required this.routeInfo, required this.expiresAt});
}

class _RoutesMetrics {
  int apiCalls = 0;
  int cacheHits = 0;
  int _lastLoggedTotal = 0;

  void logIfNeeded() {
    final total = apiCalls + cacheHits;
    if (total - _lastLoggedTotal < 8) return;
    _lastLoggedTotal = total;
    AppLogger.i(
      '📊 MAPS Routes ahorro | api=$apiCalls cache_hits=$cacheHits ahorro=${cacheHitRate.toStringAsFixed(1)}%',
      tag: 'MapsMetrics',
    );
  }

  double get cacheHitRate {
    final denominator = apiCalls + cacheHits;
    if (denominator == 0) return 0;
    return (cacheHits / denominator) * 100;
  }
}

/// Información de una ruta
class RouteInfo {
  final List<LatLng> polylinePoints;
  final String distance;
  final int distanceValue;
  final String duration;
  final int durationValue;
  final String startAddress;
  final String endAddress;

  RouteInfo({
    required this.polylinePoints,
    required this.distance,
    required this.distanceValue,
    required this.duration,
    required this.durationValue,
    required this.startAddress,
    required this.endAddress,
  });

  // Nota: El precio no se muestra porque funciona con taxímetro
}
