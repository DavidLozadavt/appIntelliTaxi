import 'package:flutter_test/flutter_test.dart';
import 'package:intellitaxi/features/taxi/services/taxi_maps_api_service.dart';

void main() {
  group('Contrato con el backend de mapas', () {
    test('el límite de resultados no supera lo que acepta el backend', () {
      // `taxi/places-autocomplete` y `taxi/geocode` validan `limit` y
      // responden "The limit must not be greater than 10" con `success: false`
      // si se excede. En ese caso el cliente recibe una lista vacía y la
      // búsqueda se ve rota sin que salte ningún error.
      expect(
        TaxiMapsApiService.maxResultsPerRequest,
        lessThanOrEqualTo(10),
        reason: 'El backend rechaza limit > 10 y la búsqueda queda vacía',
      );
    });
  });
}
