import 'dart:async';

import 'package:intellitaxi/config/maps_config.dart';
import 'package:intellitaxi/features/pasajero/model/place_details_model.dart';
import 'package:intellitaxi/features/pasajero/services/places_service.dart';

/// Autocompletado de origen/destino con debounce (sin UI).
class PasajeroPlacesSearchController {
  PasajeroPlacesSearchController({PlacesService? placesService})
      : _placesService = placesService ?? PlacesService();

  final PlacesService _placesService;

  Timer? _originDebounce;
  Timer? _destinationDebounce;
  int _originRequestId = 0;
  int _destinationRequestId = 0;

  static Duration get debounceDuration => MapsConfig.autocompleteDebounce;

  void dispose() {
    _originDebounce?.cancel();
    _destinationDebounce?.cancel();
  }

  void clearSessionIfBothEmpty({
    required String originQuery,
    required String destinationQuery,
  }) {
    if (originQuery.isEmpty && destinationQuery.isEmpty) {
      _placesService.clearAutocompleteSession();
    }
  }

  void searchOrigin({
    required String query,
    required void Function(List<PlacePrediction> predictions, bool searching)
        onResult,
  }) {
    _originDebounce?.cancel();
    if (query.isEmpty) {
      onResult(const [], false);
      return;
    }

    onResult(const [], true);
    final requestId = ++_originRequestId;
    _originDebounce = Timer(debounceDuration, () async {
      final predictions = await _placesService.getAutocompletePredictions(query);
      if (requestId != _originRequestId) return;
      onResult(predictions, false);
    });
  }

  void searchDestination({
    required String query,
    required void Function(List<PlacePrediction> predictions, bool searching)
        onResult,
  }) {
    _destinationDebounce?.cancel();
    if (query.isEmpty) {
      onResult(const [], false);
      return;
    }

    onResult(const [], true);
    final requestId = ++_destinationRequestId;
    _destinationDebounce = Timer(debounceDuration, () async {
      final predictions = await _placesService.getAutocompletePredictions(query);
      if (requestId != _destinationRequestId) return;
      onResult(predictions, false);
    });
  }

  Future<PlaceDetails?> resolvePlace(PlacePrediction prediction) {
    return _placesService.resolvePrediction(prediction);
  }
}
