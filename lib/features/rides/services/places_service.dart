import 'dart:convert';
import 'dart:math' as math;
import 'package:http/http.dart' as http;
import 'package:intellitaxi/config/app_config.dart';

class PlacesService {
  static const String _baseUrl = 'https://maps.googleapis.com/maps/api';
  
  // Coordenadas de Popayán, Cauca
  static const double popyanLat = 2.4419;
  static const double popyanLng = -76.6063;
  static const double searchRadiusKm = 20.0; // Radio de búsqueda en km

  /// Busca lugares cercanos limitados a Popayán
  Future<List<PlaceResult>> searchPlaces(String query) async {
    if (query.trim().isEmpty) return [];

    try {
      final url = Uri.parse(
        '$_baseUrl/place/textsearch/json?'
        'query=$query'
        '&location=$popyanLat,$popyanLng'
        '&radius=${searchRadiusKm * 1000}' // Convertir a metros
        '&key=${AppConfig.googleMapsApiKey}'
        '&language=es',
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['status'] == 'OK') {
          final results = (data['results'] as List)
              .map((place) => PlaceResult.fromJson(place))
              .where((place) => _isNearPopayan(place.lat, place.lng))
              .toList();
          
          return results;
        }
      }
      
      return [];
    } catch (e) {
      print('Error buscando lugares: $e');
      return [];
    }
  }

  /// Autocomplete de lugares limitado a Popayán
  Future<List<PlacePrediction>> getAutocompletePredictions(String input) async {
    if (input.trim().isEmpty) return [];

    try {
      final url = Uri.parse(
        '$_baseUrl/place/autocomplete/json?'
        'input=$input'
        '&location=$popyanLat,$popyanLng'
        '&radius=${searchRadiusKm * 1000}'
        '&strictbounds=true' // Limitar estrictamente al radio
        '&components=country:co' // Solo Colombia
        '&key=${AppConfig.googleMapsApiKey}'
        '&language=es',
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['status'] == 'OK') {
          return (data['predictions'] as List)
              .map((pred) => PlacePrediction.fromJson(pred))
              .toList();
        }
      }
      
      return [];
    } catch (e) {
      print('Error en autocomplete: $e');
      return [];
    }
  }

  /// Obtiene los detalles de un lugar por su placeId
  Future<PlaceDetails?> getPlaceDetails(String placeId) async {
    try {
      final url = Uri.parse(
        '$_baseUrl/place/details/json?'
        'place_id=$placeId'
        '&fields=name,formatted_address,geometry'
        '&key=${AppConfig.googleMapsApiKey}'
        '&language=es',
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['status'] == 'OK') {
          return PlaceDetails.fromJson(data['result']);
        }
      }
      
      return null;
    } catch (e) {
      print('Error obteniendo detalles: $e');
      return null;
    }
  }

  /// Verifica si las coordenadas están cerca de Popayán
  bool _isNearPopayan(double lat, double lng) {
    final distance = _calculateDistance(popyanLat, popyanLng, lat, lng);
    return distance <= searchRadiusKm;
  }

  /// Calcula la distancia entre dos puntos en km (Haversine)
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371; // Radio de la Tierra en km
    
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);
    
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(lat1)) *
        math.cos(_toRadians(lat2)) *
        math.sin(dLon / 2) *
        math.sin(dLon / 2);
    
    final c = 2 * math.asin(math.sqrt(a));
    
    return earthRadius * c;
  }

  double _toRadians(double degrees) => degrees * (math.pi / 180);
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
