import 'package:intellitaxi/core/geo/place_precision.dart';

/// Respuesta de `POST taxi/conductor/ubicacion-mapa` (y fallback legacy).
///
/// El backend puede devolver la zona ya resuelta (Nominatim en servidor) para
/// no llamar `reverse-geocode` desde el móvil. Campos aceptados (cualquiera con valor):
/// - `zona`, `zona_label`, `zona_conductor`, `label_zona`
/// - `barrio` (si no hay `zona`, se usa barrio)
/// - `address` / `direccion` (último recurso: primera parte antes de coma)
class ConductorUbicacionMapaResult {
  ConductorUbicacionMapaResult({
    this.zonaLabel,
    this.barrio,
    this.address,
    this.raw,
  });

  final String? zonaLabel;
  final String? barrio;
  final String? address;
  final Map<String, dynamic>? raw;

  bool get hasZona => displayZona.trim().isNotEmpty;

  String get displayZona {
    String? street;
    String? fallback;
    for (final raw in [zonaLabel, address, barrio]) {
      final v = raw?.trim() ?? '';
      if (v.isEmpty) continue;
      final first = v.split(',').first.trim();
      if (PlacePrecision.isPlusCodeLabel(first)) continue;
      if (PlacePrecision.looksLikeStreetLabel(first)) {
        street ??= first;
      } else {
        fallback ??= first;
      }
    }
    return street ?? fallback ?? '';
  }

  static ConductorUbicacionMapaResult? tryFromResponse(dynamic data) {
    if (data == null) return null;
    Map<String, dynamic>? root;
    if (data is Map) {
      root = Map<String, dynamic>.from(data);
    } else {
      return null;
    }

    if (root['success'] == false) return null;

    final payload = root['data'] is Map
        ? Map<String, dynamic>.from(root['data'] as Map)
        : root;

    final ubicacion = payload['ubicacion'] is Map
        ? Map<String, dynamic>.from(payload['ubicacion'] as Map)
        : null;

    String? pick(Map<String, dynamic> m, List<String> keys) {
      for (final key in keys) {
        final v = m[key]?.toString().trim();
        if (v != null && v.isNotEmpty) return v;
      }
      return null;
    }

    final zona = pick(payload, _zonaKeys) ??
        (ubicacion != null ? pick(ubicacion, _zonaKeys) : null);
    final barrio = pick(payload, _barrioKeys) ??
        (ubicacion != null ? pick(ubicacion, _barrioKeys) : null);
    final address = pick(payload, _addressKeys) ??
        (ubicacion != null ? pick(ubicacion, _addressKeys) : null);

    if (zona == null && barrio == null && address == null) {
      return ConductorUbicacionMapaResult(raw: root);
    }

    return ConductorUbicacionMapaResult(
      zonaLabel: zona,
      barrio: barrio,
      address: address,
      raw: root,
    );
  }

  static const _zonaKeys = [
    'zona',
    'zona_label',
    'zona_conductor',
    'label_zona',
    'zona_actual',
    'zona_texto',
  ];

  static const _barrioKeys = [
    'barrio',
    'origen_barrio',
    'neighborhood',
  ];

  static const _addressKeys = [
    'address',
    'direccion',
    'formatted_address',
    'direccion_texto',
  ];
}
