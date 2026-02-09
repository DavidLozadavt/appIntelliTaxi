import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:intellitaxi/config/app_config.dart';

class RoutesService {
  final PolylinePoints _polylinePoints = PolylinePoints();

  /// Obtiene la ruta entre dos puntos
  Future<RouteInfo?> getRoute({
    required LatLng origin,
    required LatLng destination,
  }) async {
    try {
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/directions/json?'
        'origin=${origin.latitude},${origin.longitude}'
        '&destination=${destination.latitude},${destination.longitude}'
        '&mode=driving'
        '&key=${AppConfig.googleMapsApiKey}'
        '&language=es',
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] == 'OK' && data['routes'].isNotEmpty) {
          final route = data['routes'][0];
          final leg = route['legs'][0];

          // Decodificar la polilínea
          final polylineString = route['overview_polyline']['points'];
          final polylineCoordinates = _decodePolyline(polylineString);

          return RouteInfo(
            polylinePoints: polylineCoordinates,
            distance: leg['distance']['text'],
            distanceValue: leg['distance']['value'], // en metros
            duration: leg['duration']['text'],
            durationValue: leg['duration']['value'], // en segundos
            startAddress: leg['start_address'],
            endAddress: leg['end_address'],
          );
        }
      }

      return null;
    } catch (e) {
      print('Error obteniendo ruta: $e');
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
