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
    return points.map((point) => LatLng(point.latitude, point.longitude)).toList();
  }

  /// Calcula el precio estimado basado en la distancia
  double calculateEstimatedPrice(int distanceInMeters) {
    // Tarifa base
    const double baseFare = 5000; // $5,000 COP
    
    // Precio por kilómetro
    const double pricePerKm = 2500; // $2,500 COP por km
    
    final distanceInKm = distanceInMeters / 1000;
    final totalPrice = baseFare + (distanceInKm * pricePerKm);
    
    // Redondear a múltiplos de 100
    return (totalPrice / 100).ceil() * 100;
  }

  /// Formatea el precio en pesos colombianos
  String formatPrice(double price) {
    return '\$${price.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    )}';
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

  double get estimatedPrice {
    const double baseFare = 5000;
    const double pricePerKm = 2500;
    final distanceInKm = distanceValue / 1000;
    final totalPrice = baseFare + (distanceInKm * pricePerKm);
    return (totalPrice / 100).ceil() * 100;
  }

  String get formattedPrice {
    return '\$${estimatedPrice.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    )}';
  }
}
