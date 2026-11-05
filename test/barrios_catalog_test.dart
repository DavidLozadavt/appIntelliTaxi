import 'package:flutter_test/flutter_test.dart';
import 'package:intellitaxi/core/geo/barrios/barrio.dart';
import 'package:intellitaxi/core/geo/barrios/barrios_catalog.dart';
import 'package:intellitaxi/core/geo/barrios/geo_polygon.dart';

void main() {
  // Cuadrado ~220 m de lado alrededor del centro de Popayán.
  const square = [
    [
      [
        [-76.6073, 2.4409],
        [-76.6053, 2.4409],
        [-76.6053, 2.4429],
        [-76.6073, 2.4429],
        [-76.6073, 2.4409],
      ],
    ],
  ];

  const neighbor = [
    [
      [
        [-76.6053, 2.4409],
        [-76.6033, 2.4409],
        [-76.6033, 2.4429],
        [-76.6053, 2.4429],
        [-76.6053, 2.4409],
      ],
    ],
  ];

  Barrio barrio(int id, String name, List<List<List<List<double>>>> polys) {
    final ring = polys.first.first;
    final xs = ring.map((p) => p[0]);
    final ys = ring.map((p) => p[1]);
    return Barrio(
      id: id,
      nombre: name,
      comuna: 4,
      bbox: [xs.reduce((a, b) => a < b ? a : b), ys.reduce((a, b) => a < b ? a : b),
          xs.reduce((a, b) => a > b ? a : b), ys.reduce((a, b) => a > b ? a : b)],
      polygons: polys,
    );
  }

  test('point-in-polygon detecta el interior', () {
    expect(GeoPolygon.multiContains(square, 2.4419, -76.6063), isTrue);
    expect(GeoPolygon.multiContains(square, 2.45, -76.62), isFalse);
  });

  test('dentro del polígono y lejos del borde se confirma el barrio', () {
    final catalog = BarriosCatalog.test([
      barrio(1, 'Bolívar', square),
      barrio(2, 'Caldas', neighbor),
    ]);
    final result = catalog.resolve(2.4419, -76.6063);
    expect(result.kind, BarrioResolveKind.inside);
    expect(result.match?.nombre, 'Bolívar');
  });

  test('cerca del borde pide elegir entre vecinos', () {
    final catalog = BarriosCatalog.test([
      barrio(1, 'Bolívar', square),
      barrio(2, 'Caldas', neighbor),
    ]);
    final result = catalog.resolve(2.4419, -76.60535);
    expect(result.needsUserChoice, isTrue);
    expect(result.candidates.map((e) => e.nombre), contains('Bolívar'));
  });

  test('fuera de polígonos ofrece los más cercanos, no adivina', () {
    final catalog = BarriosCatalog.test([
      barrio(1, 'Bolívar', square),
    ]);
    final result = catalog.resolve(2.4445, -76.6063);
    expect(result.kind, isNot(BarrioResolveKind.inside));
    expect(result.match, isNull);
  });
}
