import 'package:intellitaxi/core/places/place_prediction_display.dart';

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
  final double? lat;
  final double? lng;

  PlacePrediction({
    required this.placeId,
    required this.description,
    required this.mainText,
    required this.secondaryText,
    this.lat,
    this.lng,
  });

  bool get hasCoordinates => lat != null && lng != null;

  factory PlacePrediction.fromJson(Map<String, dynamic> json) {
    if (json.containsKey('structured_formatting')) {
      return PlacePrediction.fromGoogleJson(json);
    }
    return PlacePrediction.fromBackendJson(json);
  }

  factory PlacePrediction.fromGoogleJson(Map<String, dynamic> json) {
    return PlacePrediction(
      placeId: json['place_id'] ?? '',
      description: json['description'] ?? '',
      mainText: json['structured_formatting']['main_text'] ?? '',
      secondaryText: json['structured_formatting']['secondary_text'] ?? '',
    );
  }

  factory PlacePrediction.fromBackendJson(Map<String, dynamic> json) {
    final formatted = PlacePredictionDisplay.formatBackend(
      name: json['name']?.toString(),
      address: json['address']?.toString(),
      description: json['description']?.toString(),
    );
    return PlacePrediction(
      placeId: json['place_id']?.toString() ?? '',
      description: formatted.description,
      mainText: formatted.mainText,
      secondaryText: formatted.secondaryText,
      lat: (json['lat'] as num?)?.toDouble(),
      lng: (json['lng'] as num?)?.toDouble(),
    );
  }
}