import 'package:flutter_test/flutter_test.dart';
import 'package:intellitaxi/core/places/place_prediction_display.dart';

void main() {
  group('PlacePredictionDisplay.readableAddress', () {
    test('quita el ruido de geocoder y deja el texto útil completo', () {
      expect(
        PlacePredictionDisplay.readableAddress(
          'Galeria Alfonso López, Calle 13, Moscopán, Comuna 4, '
          'Perímetro Urbano Popayán, Popayán, Cauca, Colombia',
        ),
        'Galeria Alfonso López, Calle 13, Moscopán, Comuna 4',
      );
    });

    test('no recorta una dirección corta', () {
      expect(
        PlacePredictionDisplay.readableAddress('Carrera 5 # 12-34, Centro'),
        'Carrera 5 # 12-34, Centro',
      );
    });
  });
}
