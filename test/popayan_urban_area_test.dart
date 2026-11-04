import 'package:flutter_test/flutter_test.dart';
import 'package:intellitaxi/core/geo/popayan_urban_area.dart';

void main() {
  group('PopayanUrbanArea.contains', () {
    test('acepta el centro y barrios/veredas del área de servicio', () {
      const points = <(String, double, double)>[
        ('centro', 2.4419, -76.6063),
        ('Julumito', 2.421, -76.648),
        ('Calibío', 2.53, -76.55),
        ('El Tambo', 2.452, -76.811),
        ('esquina NE del bbox', 2.58, -76.42),
        ('esquina SW del bbox', 2.32, -76.82),
      ];
      for (final point in points) {
        expect(
          PopayanUrbanArea.contains(point.$2, point.$3),
          isTrue,
          reason: '${point.$1} debe estar dentro del perímetro',
        );
      }
    });

    test('rechaza otras ciudades', () {
      expect(PopayanUrbanArea.contains(3.4516, -76.5320), isFalse); // Cali
      expect(PopayanUrbanArea.contains(1.2136, -77.2811), isFalse); // Pasto
      expect(PopayanUrbanArea.contains(4.7110, -74.0721), isFalse); // Bogotá
    });
  });

  group('PopayanUrbanArea.isPredictionAllowed', () {
    test('acepta direcciones locales aunque mencionen la vía a Totoró', () {
      expect(
        PopayanUrbanArea.isPredictionAllowed(
          'Vía Totoró, Popayán, Cauca, Colombia',
        ),
        isTrue,
      );
      expect(
        PopayanUrbanArea.isPredictionAllowed('Vía a Totoró, Popayán'),
        isTrue,
      );
      expect(
        PopayanUrbanArea.isPredictionAllowed('Carrera 5 # 12-34, Popayán'),
        isTrue,
      );
    });

    test('rechaza otras ciudades', () {
      expect(
        PopayanUrbanArea.isPredictionAllowed('Carrera 5, Cali, Valle'),
        isFalse,
      );
      expect(
        PopayanUrbanArea.isPredictionAllowed('Totoró, Cauca, Colombia'),
        isFalse,
      );
    });
  });
}
