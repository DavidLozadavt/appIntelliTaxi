import 'package:flutter_test/flutter_test.dart';
import 'package:intellitaxi/core/geo/place_precision.dart';

void main() {
  group('PlacePrecision.isPlausibleNeighborhood', () {
    test('acepta los barrios reales de Popayán', () {
      // Valores verificados contra Nominatim (`neighbourhood`).
      for (final barrio in [
        'Pandiguando',
        'Moscopán',
        'El Cadillal',
        'Tunel Bajo',
        'Valle Robledo',
        'Ciudad jardin',
        'Lomas de Pomona',
        'Los Comuneros',
        'Caldas',
        'Asoma Sol',
      ]) {
        expect(
          PlacePrecision.isPlausibleNeighborhood(barrio),
          isTrue,
          reason: '$barrio debería ser un barrio válido',
        );
      }
    });

    test('rechaza zonas amplias (no son barrios)', () {
      for (final zona in [
        'Centro',
        'Comuna 4',
        'Comuna 1',
        'Perímetro Urbano Popayán',
        'Popayán',
        'Cauca',
        'Colombia',
        'RAP Pacífico',
      ]) {
        expect(
          PlacePrecision.isPlausibleNeighborhood(zona),
          isFalse,
          reason: '$zona es una zona, no un barrio',
        );
      }
    });

    test('rechaza vías, códigos y valores sin sentido', () {
      for (final valor in [
        'Cra. 5',
        'Calle 22B',
        'Avenida 4 Norte',
        'C9VR+VR',
        '123',
        '9-27',
        '',
        'ab',
      ]) {
        expect(
          PlacePrecision.isPlausibleNeighborhood(valor),
          isFalse,
          reason: '$valor no debe ser un barrio',
        );
      }
    });
  });

  group('PlacePrecision.isPlausibleZoneLabel', () {
    test('acepta sector pero no barrio', () {
      expect(PlacePrecision.isPlausibleZoneLabel('Centro'), isTrue);
      expect(PlacePrecision.isPlausibleZoneLabel('Comuna 4'), isFalse);
      expect(PlacePrecision.isPlausibleZoneLabel('Pandiguando'), isFalse);
    });
  });

  group('PlacePrecision.normalizeNeighborhood', () {
    test('quita el prefijo redundante "Barrio"', () {
      expect(
        PlacePrecision.normalizeNeighborhood('Barrio solidaridad'),
        'Solidaridad',
      );
      expect(
        PlacePrecision.normalizeNeighborhood('barrio La Julita'),
        'La Julita',
      );
    });

    test('normaliza la capitalización sin romper acentos', () {
      expect(
        PlacePrecision.normalizeNeighborhood('Ciudad jardin'),
        'Ciudad jardin',
      );
      expect(
        PlacePrecision.normalizeNeighborhood('ciudad jardin'),
        'Ciudad jardin',
      );
      expect(PlacePrecision.normalizeNeighborhood('MOSCOPÁN'), 'MOSCOPÁN');
    });

    test('no capitaliza palabras internas', () {
      // "Los Alamos de Occidente", no "Los Alamos De Occidente".
      expect(
        PlacePrecision.normalizeNeighborhood('Los Alamos de Occidente'),
        'Los Alamos de Occidente',
      );
      expect(
        PlacePrecision.normalizeNeighborhood('Lomas de Pomona'),
        'Lomas de Pomona',
      );
    });

    test('colapsa espacios y descarta entradas vacías', () {
      expect(
        PlacePrecision.normalizeNeighborhood('  Los   Comuneros  '),
        'Los Comuneros',
      );
      expect(PlacePrecision.normalizeNeighborhood('   '), '');
      expect(PlacePrecision.normalizeNeighborhood(null), '');
    });
  });

  group('PlacePrecision.withAreaContext', () {
    test('ancla la consulta a la zona', () {
      expect(
        PlacePrecision.withAreaContext('carrera 5'),
        'carrera 5, Popayán, Cauca, Colombia',
      );
    });

    test('no duplica el contexto si el usuario ya lo puso', () {
      expect(
        PlacePrecision.withAreaContext('carrera 5 Popayán'),
        'carrera 5 Popayán',
      );
      expect(
        PlacePrecision.withAreaContext('Universidad del Cauca, Cauca'),
        'Universidad del Cauca, Cauca',
      );
    });

    test('no toca consultas vacías', () {
      expect(PlacePrecision.withAreaContext('  '), '');
    });
  });

  group('PlacePrecision.distanceMeters', () {
    test('calcula distancia conocida', () {
      // ~111 m por 0.001° de latitud.
      final d = PlacePrecision.distanceMeters(
        2.4419,
        -76.6063,
        2.4429,
        -76.6063,
      );
      expect(d, closeTo(111, 5));
    });

    test('devuelve infinito con coordenadas inválidas', () {
      expect(
        PlacePrecision.distanceMeters(2.44, -76.60, double.nan, -76.60),
        double.infinity,
      );
    });
  });

  group('PlacePrecision.sortByProximity', () {
    test('ordena de más cerca a más lejos', () {
      final items = [
        ('lejos', 2.4600, -76.6063),
        ('cerca', 2.4420, -76.6063),
        ('medio', 2.4500, -76.6063),
      ];

      final sorted = PlacePrecision.sortByProximity(
        items,
        originLat: 2.4419,
        originLng: -76.6063,
        latOf: (i) => i.$2,
        lngOf: (i) => i.$3,
      );

      expect(sorted.map((i) => i.$1), ['cerca', 'medio', 'lejos']);
    });

    test('sin origen conserva el orden original', () {
      final items = [('a', 2.46), ('b', 2.44)];
      final sorted = PlacePrecision.sortByProximity(
        items,
        originLat: null,
        originLng: null,
        latOf: (i) => i.$2,
        lngOf: (i) => 0.0,
      );
      expect(sorted.map((i) => i.$1), ['a', 'b']);
    });
  });

  group('PlacePrecision.dedupeByProximity', () {
    test('elimina el mismo lugar repetido', () {
      final items = [
        ('Cra 5 #1-2', 2.4420, -76.6063),
        ('Cra 5 #1-2', 2.4421, -76.6063),
        ('Cra 6 #3-4', 2.4500, -76.6063),
      ];

      final deduped = PlacePrecision.dedupeByProximity(
        items,
        latOf: (i) => i.$2,
        lngOf: (i) => i.$3,
        keyOf: (i) => i.$1,
      );

      expect(deduped.length, 2);
      expect(deduped.first.$1, 'Cra 5 #1-2');
    });

    test('mantiene el mismo nombre si está lejos', () {
      final items = [('Cra 5', 2.4420, -76.6063), ('Cra 5', 2.4600, -76.6063)];
      final deduped = PlacePrecision.dedupeByProximity(
        items,
        latOf: (i) => i.$2,
        lngOf: (i) => i.$3,
        keyOf: (i) => i.$1,
      );
      expect(deduped.length, 2);
    });
  });

  group('PlacePrecision.formatDistance', () {
    test('formatea metros y kilómetros', () {
      expect(PlacePrecision.formatDistance(250), '250 m');
      expect(PlacePrecision.formatDistance(999), '999 m');
      expect(PlacePrecision.formatDistance(1400), '1,4 km');
      expect(PlacePrecision.formatDistance(double.nan), '');
    });
  });

  group('PlacePrecision.hasMappedStreet', () {
    // Respuesta real de Google para Los Alamos de Occidente (Popayán).
    // Google inventa tres direcciones y marca la primera como plus_code.
    final resultadosSinCalle = <Map<String, dynamic>>[
      {
        'types': ['premise', 'street_address'],
        'formatted_address': 'C9X6+JV, Popayán, Cauca, Colombia',
        'address_components': <Map<String, dynamic>>[
          {'types': ['locality', 'political'], 'long_name': 'Popayán'},
          {'types': ['country', 'political'], 'long_name': 'Colombia'},
        ],
      },
      {
        'types': ['street_address'],
        'formatted_address': 'Cl. 15 # 37-222, Popayán, Cauca, Colombia',
        'address_components': <Map<String, dynamic>>[
          {'types': ['street_number'], 'long_name': '# 37-222'},
          {'types': ['route'], 'long_name': 'Calle 15'},
        ],
      },
    ];

    test('detecta que la calle fue inventada por Google', () {
      expect(PlacePrecision.hasMappedStreet(resultadosSinCalle), isFalse);
    });

    test('acepta un punto con calle real', () {
      final conCalle = <Map<String, dynamic>>[
        {
          'types': ['premise', 'street_address'],
          'formatted_address': 'Cl. 2 Nte. #9-27, Centro, Popayán',
          'address_components': <Map<String, dynamic>>[
            {'types': ['street_number'], 'long_name': '9-27'},
            {'types': ['route'], 'long_name': 'Calle 2 Norte'},
            {
              'types': ['sublocality', 'sublocality_level_1'],
              'long_name': 'Centro',
            },
          ],
        },
      ];
      expect(PlacePrecision.hasMappedStreet(conCalle), isTrue);
    });

    test('sin resultados no hay calle', () {
      expect(PlacePrecision.hasMappedStreet(const []), isFalse);
    });
  });

  group('PlacePrecision.looksLikeInventedGridStreet', () {
    test('detecta nomenclatura interpolada de Google', () {
      expect(
        PlacePrecision.looksLikeInventedGridStreet('Cl. 15 # 37-222'),
        isTrue,
      );
      expect(
        PlacePrecision.looksLikeInventedGridStreet('Aguas Vivas'),
        isFalse,
      );
    });
  });
}
