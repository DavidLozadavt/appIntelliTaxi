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
      print('🔍 Buscando lugares: "$query"');

      final url = Uri.parse(
        '$_baseUrl/place/textsearch/json?'
        'query=${Uri.encodeComponent(query)}'
        '&location=$popyanLat,$popyanLng'
        '&radius=${searchRadiusKm * 1000}' // Convertir a metros
        '&key=${AppConfig.googleMapsApiKey}'
        '&language=es',
      );

      print('🌐 URL: $url');

      final response = await http.get(url);
      print('📡 Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('📦 Response data status: ${data['status']}');

        if (data['status'] == 'OK') {
          final results = (data['results'] as List)
              .map((place) => PlaceResult.fromJson(place))
              .where((place) => _isNearPopayan(place.lat, place.lng))
              .toList();
          print('✅ Encontrados ${results.length} lugares');
          return results;
        } else if (data['status'] == 'ZERO_RESULTS') {
          print('⚠️ No se encontraron resultados para: "$query"');
          return [];
        } else {
          print('❌ Error de Google API: ${data['status']}');
          if (data['error_message'] != null) {
            print('   Mensaje: ${data['error_message']}');
          }
          return [];
        }
      } else {
        print('❌ Error HTTP: ${response.statusCode}');
        print('   Body: ${response.body}');
      }

      return [];
    } catch (e, stackTrace) {
      print('❌ Error buscando lugares: $e');
      print('   Stack trace: $stackTrace');
      return [];
    }
  }

  /// Autocomplete de lugares limitado a Popayán
  Future<List<PlacePrediction>> getAutocompletePredictions(String input) async {
    if (input.trim().isEmpty) return [];

    try {
      print('🔍 Buscando: "$input"');

      final url = Uri.parse(
        '$_baseUrl/place/autocomplete/json?'
        'input=${Uri.encodeComponent(input)}'
        '&location=$popyanLat,$popyanLng'
        '&radius=${searchRadiusKm * 1000}'
        '&strictbounds=true' // Limitar estrictamente al radio
        '&components=country:co' // Solo Colombia
        '&key=${AppConfig.googleMapsApiKey}'
        '&language=es',
      );

      print('🌐 URL: $url');

      final response = await http.get(url);
      print('📡 Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('📦 Response data status: ${data['status']}');

        if (data['status'] == 'OK') {
          final predictions = (data['predictions'] as List)
              .map((pred) => PlacePrediction.fromJson(pred))
              .toList();
          print('✅ Encontrados ${predictions.length} resultados');
          return predictions;
        } else if (data['status'] == 'ZERO_RESULTS') {
          print('⚠️ No se encontraron resultados para: "$input"');
          return [];
        } else {
          print('❌ Error de Google API: ${data['status']}');
          if (data['error_message'] != null) {
            print('   Mensaje: ${data['error_message']}');
          }
          return [];
        }
      } else {
        print('❌ Error HTTP: ${response.statusCode}');
        print('   Body: ${response.body}');
      }

      return [];
    } catch (e, stackTrace) {
      print('❌ Error en autocomplete: $e');
      print('   Stack trace: $stackTrace');
      return [];
    }
  }

  /// Obtiene los detalles de un lugar por su placeId
  Future<PlaceDetails?> getPlaceDetails(String placeId) async {
    try {
      print('📍 Obteniendo detalles del lugar: $placeId');

      final url = Uri.parse(
        '$_baseUrl/place/details/json?'
        'place_id=$placeId'
        '&fields=name,formatted_address,geometry'
        '&key=${AppConfig.googleMapsApiKey}'
        '&language=es',
      );

      final response = await http.get(url);
      print('📡 Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('📦 Response data status: ${data['status']}');

        if (data['status'] == 'OK') {
          final placeDetails = PlaceDetails.fromJson(data['result']);
          print('✅ Detalles obtenidos: ${placeDetails.name}');
          return placeDetails;
        } else {
          print('❌ Error de Google API: ${data['status']}');
          if (data['error_message'] != null) {
            print('   Mensaje: ${data['error_message']}');
          }
        }
      } else {
        print('❌ Error HTTP: ${response.statusCode}');
        print('   Body: ${response.body}');
      }

      return null;
    } catch (e, stackTrace) {
      print('❌ Error obteniendo detalles: $e');
      print('   Stack trace: $stackTrace');
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
