import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:intellitaxi/core/geo/barrios/barrio.dart';
import 'package:intellitaxi/core/geo/barrios/geo_polygon.dart';
import 'package:intellitaxi/core/geo/place_precision.dart';

class BarriosCatalog {
  BarriosCatalog._(this._barrios);

  static const assetPath = 'assets/geo/barrios_popayan.json';
  static const double borderMeters = 50;
  static const double nearbyLimitMeters = 450;
  static const int maxCandidates = 3;

  static BarriosCatalog? _instance;
  static Future<BarriosCatalog>? _loading;

  final List<Barrio> _barrios;

  List<Barrio> get all => List.unmodifiable(_barrios);

  @visibleForTesting
  factory BarriosCatalog.test(List<Barrio> barrios) => BarriosCatalog._(barrios);

  static Future<BarriosCatalog> instance() {
    if (_instance != null) return Future.value(_instance);
    return _loading ??= _load().then((c) {
      _instance = c;
      return c;
    });
  }

  static Future<BarriosCatalog> _load() async {
    final raw = await rootBundle.loadString(assetPath);
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final features = json['features'] as List? ?? const [];
    final barrios = <Barrio>[];
    for (final item in features) {
      if (item is! Map) continue;
      final barrio = Barrio.fromJson(Map<String, dynamic>.from(item));
      if (barrio.nombre.isEmpty || !barrio.hasGeometry) continue;
      barrios.add(barrio);
    }
    return BarriosCatalog._(barrios);
  }

  BarrioResolveResult resolve(double lat, double lng) {
    if (!lat.isFinite || !lng.isFinite) {
      return const BarrioResolveResult(kind: BarrioResolveKind.unknown);
    }

    final containing = <({Barrio barrio, double edge})>[];
    final nearby = <({Barrio barrio, double edge})>[];
    final padLng = borderMeters / GeoPolygon.metersPerDegLng(lat);
    final padLat = borderMeters / 111320.0;

    for (final barrio in _barrios) {
      if (!_bboxHits(barrio.bbox, lat, lng, padLng * 12, padLat * 12)) {
        continue;
      }
      final inside = GeoPolygon.multiContains(barrio.polygons, lat, lng);
      final edge = GeoPolygon.distanceToBoundaryMeters(
        barrio.polygons,
        lat,
        lng,
      );
      if (inside) {
        containing.add((barrio: barrio, edge: edge));
      } else if (edge <= nearbyLimitMeters) {
        nearby.add((barrio: barrio, edge: edge));
      }
    }

    containing.sort((a, b) => a.edge.compareTo(b.edge));
    nearby.sort((a, b) => a.edge.compareTo(b.edge));

    if (containing.isNotEmpty) {
      final best = containing.first;
      final othersNear = <Barrio>[
        for (final item in containing.skip(1)) item.barrio,
        for (final item in nearby)
          if (item.edge <= borderMeters) item.barrio,
      ];
      if (GeoPolygon.nearBorder(best.edge) || othersNear.isNotEmpty) {
        final candidates = <Barrio>[best.barrio, ...othersNear]
            .take(maxCandidates)
            .toList();
        return BarrioResolveResult(
          kind: BarrioResolveKind.nearBorder,
          match: best.barrio,
          candidates: candidates,
          distanceToBoundaryM: best.edge,
        );
      }
      return BarrioResolveResult(
        kind: BarrioResolveKind.inside,
        match: best.barrio,
        candidates: [best.barrio],
        distanceToBoundaryM: best.edge,
      );
    }

    if (nearby.isNotEmpty) {
      final candidates =
          nearby.take(maxCandidates).map((e) => e.barrio).toList();
      return BarrioResolveResult(
        kind: BarrioResolveKind.nearby,
        match: null,
        candidates: candidates,
        distanceToBoundaryM: nearby.first.edge,
      );
    }

    return const BarrioResolveResult(kind: BarrioResolveKind.unknown);
  }

  List<Barrio> search(String query, {int limit = 20}) {
    final q = _fold(query);
    if (q.length < 2) return const [];
    final scored = <({Barrio barrio, int score})>[];
    for (final barrio in _barrios) {
      final name = _fold(barrio.nombre);
      if (name == q) {
        scored.add((barrio: barrio, score: 0));
      } else if (name.startsWith(q)) {
        scored.add((barrio: barrio, score: 1));
      } else if (name.contains(q)) {
        scored.add((barrio: barrio, score: 2));
      }
    }
    scored.sort((a, b) => a.score.compareTo(b.score));
    return scored.take(limit).map((e) => e.barrio).toList();
  }

  Barrio? byId(int id) {
    for (final barrio in _barrios) {
      if (barrio.id == id) return barrio;
    }
    return null;
  }

  static bool _bboxHits(
    List<double> bbox,
    double lat,
    double lng,
    double padLng,
    double padLat,
  ) {
    if (bbox.length < 4) return false;
    return lng >= bbox[0] - padLng &&
        lat >= bbox[1] - padLat &&
        lng <= bbox[2] + padLng &&
        lat <= bbox[3] + padLat;
  }

  static String _fold(String value) {
    return PlacePrecision.normalizeNeighborhood(value)
        .toLowerCase()
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ü', 'u');
  }
}
