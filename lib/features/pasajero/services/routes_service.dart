import 'package:intellitaxi/core/map/intellitaxi_maps.dart';
import 'package:intellitaxi/config/maps_config.dart';
import 'package:intellitaxi/core/dio_client.dart';
import 'package:intellitaxi/core/services/app_logger.dart';
import 'package:intellitaxi/features/taxi/services/taxi_maps_api_service.dart';

class RoutesService {
  RoutesService({TaxiMapsApiService? taxiMaps})
      : _taxiMaps = taxiMaps ?? TaxiMapsApiService(DioClient.getInstance());

  final TaxiMapsApiService _taxiMaps;
  static const Duration _routeCacheTtl = Duration(minutes: 30);
  final Map<String, _RouteCacheEntry> _routeCache = {};
  final _RoutesMetrics _metrics = _RoutesMetrics();

  /// Obtiene la ruta entre dos puntos (OSRM vía backend o legacy Google).
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

    if (MapsConfig.useBackendProxy) {
      return _getRouteViaBackend(origin, destination, routeKey);
    }

    AppLogger.w(
      'RoutesService: Google Directions deshabilitado; active useBackendProxy.',
      tag: 'TaxiMapsProxy',
    );
    return null;
  }

  Future<RouteInfo?> _getRouteViaBackend(
    LatLng origin,
    LatLng destination,
    String routeKey,
  ) async {
    try {
      final result = await _taxiMaps.calcularRuta(
        fromLat: origin.latitude,
        fromLng: origin.longitude,
        toLat: destination.latitude,
        toLng: destination.longitude,
      );
      _metrics.apiCalls++;
      _metrics.logIfNeeded();

      if (result == null) return null;

      final polylinePoints = result.polylinePoints
          .map((p) => LatLng(p.lat, p.lng))
          .toList();

      final routeInfo = RouteInfo(
        polylinePoints: polylinePoints,
        distance: result.distanceText,
        distanceValue: result.distanceMeters,
        duration: result.durationText,
        durationValue: result.durationSeconds,
        startAddress: '',
        endAddress: '',
      );

      _routeCache[routeKey] = _RouteCacheEntry(
        routeInfo: routeInfo,
        expiresAt: DateTime.now().add(_routeCacheTtl),
      );
      return routeInfo;
    } catch (e) {
      AppLogger.d('Error ruta OSRM: $e', tag: 'TaxiMapsProxy');
      return null;
    }
  }

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
      '📊 Rutas | api=$apiCalls cache_hits=$cacheHits',
      tag: 'MapsMetrics',
    );
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
}
