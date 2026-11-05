class Barrio {
  const Barrio({
    required this.id,
    required this.nombre,
    this.comuna,
    required this.bbox,
    required this.polygons,
  });

  final int id;
  final String nombre;
  final int? comuna;

  /// `[minLng, minLat, maxLng, maxLat]`
  final List<double> bbox;

  /// MultiPolygon: polígonos → anillos → `[lng, lat]`.
  final List<List<List<List<double>>>> polygons;

  bool get hasGeometry => polygons.isNotEmpty;

  String get chipLabel {
    if (comuna != null && comuna! > 0) {
      return '$nombre · Comuna $comuna';
    }
    return nombre;
  }

  factory Barrio.fromJson(Map<String, dynamic> json) {
    final rawPolys = json['polygons'] as List? ?? const [];
    final polygons = <List<List<List<double>>>>[];
    for (final poly in rawPolys) {
      if (poly is! List) continue;
      final rings = <List<List<double>>>[];
      for (final ring in poly) {
        if (ring is! List) continue;
        final pts = <List<double>>[];
        for (final p in ring) {
          if (p is! List || p.length < 2) continue;
          pts.add([(p[0] as num).toDouble(), (p[1] as num).toDouble()]);
        }
        if (pts.length >= 4) rings.add(pts);
      }
      if (rings.isNotEmpty) polygons.add(rings);
    }

    final bboxRaw = json['bbox'] as List? ?? const [];
    final bbox = bboxRaw.length >= 4
        ? [
            (bboxRaw[0] as num).toDouble(),
            (bboxRaw[1] as num).toDouble(),
            (bboxRaw[2] as num).toDouble(),
            (bboxRaw[3] as num).toDouble(),
          ]
        : const [0.0, 0.0, 0.0, 0.0];

    return Barrio(
      id: (json['id'] as num).toInt(),
      nombre: (json['nombre'] ?? '').toString().trim(),
      comuna: json['comuna'] == null ? null : (json['comuna'] as num).toInt(),
      bbox: bbox,
      polygons: polygons,
    );
  }
}

enum BarrioResolveKind { inside, nearBorder, nearby, unknown }

class BarrioResolveResult {
  const BarrioResolveResult({
    required this.kind,
    this.match,
    this.candidates = const [],
    this.distanceToBoundaryM,
  });

  final BarrioResolveKind kind;
  final Barrio? match;
  final List<Barrio> candidates;
  final double? distanceToBoundaryM;

  bool get needsUserChoice =>
      kind == BarrioResolveKind.nearBorder ||
      kind == BarrioResolveKind.nearby ||
      kind == BarrioResolveKind.unknown;

  String get displayName {
    if (match != null) return match!.nombre;
    return 'Barrio por confirmar';
  }
}
