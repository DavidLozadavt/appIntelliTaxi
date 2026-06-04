import 'package:intellitaxi/core/utils/json_payload_helper.dart';

class ServicioPayloadAdapter {
  /// Parseo numérico tolerante (String con coma, int, double).
  static double parseDouble(dynamic value, {double fallback = 0.0}) =>
      JsonPayloadHelper.parseDouble(value, fallback: fallback);

  /// Laravel / JSON pueden enviar decimales como String; normaliza a double usable en mapas.
  static double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is String) {
      final t = v.trim();
      if (t.isEmpty) return null;
      return double.tryParse(t);
    }
    return null;
  }

  static double? _firstDouble(Map<String, dynamic> m, List<String> keys) {
    for (final k in keys) {
      if (m.containsKey(k)) {
        final d = _toDouble(m[k]);
        if (d != null) return d;
      }
    }
    return null;
  }

  /// Normaliza el payload del servicio para que la app pueda usar
  /// los campos tanto en snake_case como en camelCase sin romperse.
  static Map<String, dynamic> normalize({
    required Map<String, dynamic> servicio,
    Map<String, dynamic>? pasajero,
    Map<String, dynamic>? conductor,
    Map<String, dynamic>? vehiculo,
  }) {
    final origenLat = _firstDouble(servicio, [
      'origen_lat',
      'origenLat',
      'origin_lat',
      'originLat',
    ]);
    final origenLng = _firstDouble(servicio, [
      'origen_lng',
      'origenLng',
      'origin_lng',
      'originLng',
    ]);
    final destinoLat = _firstDouble(servicio, [
      'destino_lat',
      'destinoLat',
      'destination_lat',
      'destinationLat',
    ]);
    final destinoLng = _firstDouble(servicio, [
      'destino_lng',
      'destinoLng',
      'destination_lng',
      'destinationLng',
    ]);

    final origenAddress =
        servicio['origen_address'] ??
        servicio['origenAddress'] ??
        servicio['origen'] ??
        'Origen';
    final destinoAddress =
        servicio['destino_address'] ??
        servicio['destinoAddress'] ??
        servicio['destino'] ??
        'Destino';

    final distancia = servicio['distancia'] ?? servicio['distanciaTexto'];
    final duracion = servicio['duracion'] ?? servicio['duracionTexto'];
    final precioFinal = servicio['precio_final'] ?? servicio['precioFinal'];

    final normalized = <String, dynamic>{
      ...servicio,
      'origen_lat': origenLat,
      'origen_lng': origenLng,
      'destino_lat': destinoLat,
      'destino_lng': destinoLng,
      'origenLat': origenLat,
      'origenLng': origenLng,
      'destinoLat': destinoLat,
      'destinoLng': destinoLng,
      'origen_address': origenAddress,
      'destino_address': destinoAddress,
      'origenAddress': origenAddress,
      'destinoAddress': destinoAddress,
      'distancia': distancia,
      'duracion': duracion,
      'precio_final': precioFinal,
      'precioFinal': precioFinal,
      'vehiculo': vehiculo ?? servicio['vehiculo'],
      'conductor': conductor ?? servicio['conductor'],
    };

    if (servicio['usuario_pasajero'] != null) {
      normalized['usuario_pasajero'] = servicio['usuario_pasajero'];
    } else if (pasajero != null) {
      normalized['usuario_pasajero'] = {
        'id': pasajero['id'],
        'persona': {
          'nombre1': pasajero['nombre']?.toString().split(' ').first ?? '',
          'apellido1':
              pasajero['nombre']?.toString().split(' ').skip(1).join(' ') ?? '',
          'celular': pasajero['celular'] ?? pasajero['telefono'],
          'rutaFotoUrl': pasajero['foto'],
          'foto': pasajero['foto'],
        },
      };
    }

    final telLlamada = servicio['telefonoLlamada'] ??
        servicio['telefono_llamada'];
    if (telLlamada != null && telLlamada.toString().trim().isNotEmpty) {
      normalized['telefonoLlamada'] = telLlamada;
      if (pasajero == null && servicio['usuario_pasajero'] == null) {
        normalized['pasajero_telefono'] ??= telLlamada.toString().trim();
      }
    }

    final origen = servicio['origenServicio'] ?? servicio['origen_servicio'];
    if (origen != null) {
      normalized['origenServicio'] = origen;
    }

    return normalized;
  }

  /// Bloque `{servicio, pasajero?, conductor?, vehiculo?}` para navegar tras aceptar.
  static Map<String, dynamic>? unwrapNavegacionPayload(
    Map<String, dynamic> raw,
  ) {
    if (raw.isEmpty) return null;

    Map<String, dynamic>? fromBlock(Map<String, dynamic> block) {
      if (block['servicio'] is Map) {
        return {
          'servicio': Map<String, dynamic>.from(block['servicio'] as Map),
          if (block['pasajero'] is Map)
            'pasajero': Map<String, dynamic>.from(block['pasajero'] as Map),
          if (block['conductor'] is Map)
            'conductor': Map<String, dynamic>.from(block['conductor'] as Map),
          if (block['vehiculo'] is Map)
            'vehiculo': Map<String, dynamic>.from(block['vehiculo'] as Map),
        };
      }
      final tieneId = block['id'] != null ||
          block['servicio_id'] != null ||
          block['servicioId'] != null;
      final tieneOrigen = block.containsKey('origen_lat') ||
          block.containsKey('origenLat') ||
          block.containsKey('origen_address') ||
          block.containsKey('origen');
      if (tieneId && tieneOrigen) {
        return {'servicio': Map<String, dynamic>.from(block)};
      }
      return null;
    }

    final top = fromBlock(raw);
    if (top != null) return top;

    final data = raw['data'];
    if (data is Map) {
      return fromBlock(Map<String, dynamic>.from(data));
    }

    return null;
  }

  /// Servicio listo para [ConductorServicioActivoScreen] desde respuesta de aceptar.
  static Map<String, dynamic>? servicioNormalizadoDesdeAceptacion(
    Map<String, dynamic> response,
  ) {
    final nav = unwrapNavegacionPayload(response);
    if (nav == null) return null;
    final servicio = nav['servicio'];
    if (servicio is! Map) return null;
    return normalize(
      servicio: Map<String, dynamic>.from(servicio),
      pasajero: nav['pasajero'] is Map
          ? Map<String, dynamic>.from(nav['pasajero'] as Map)
          : null,
      conductor: nav['conductor'] is Map
          ? Map<String, dynamic>.from(nav['conductor'] as Map)
          : null,
      vehiculo: nav['vehiculo'] is Map
          ? Map<String, dynamic>.from(nav['vehiculo'] as Map)
          : null,
    );
  }

  static bool esAceptacionExitosa(Map<String, dynamic> raw) {
    final success = raw['success'];
    if (success == true || success == 1 || success == '1') return true;
    if (success == false || success == 0 || success == '0') return false;
    return unwrapNavegacionPayload(raw) != null;
  }

  static int? servicioIdDesdeAceptacion(Map<String, dynamic> raw) {
    int? parseId(dynamic v) {
      if (v is int && v > 0) return v;
      return int.tryParse(v?.toString() ?? '');
    }

    for (final key in const ['servicio_id', 'servicioId', 'id']) {
      final id = parseId(raw[key]);
      if (id != null && id > 0) return id;
    }
    final data = raw['data'];
    if (data is Map) {
      final m = Map<String, dynamic>.from(data);
      for (final key in const ['servicio_id', 'servicioId', 'id']) {
        final id = parseId(m[key]);
        if (id != null && id > 0) return id;
      }
      if (m['servicio'] is Map) {
        final s = m['servicio'] as Map;
        for (final key in const ['id', 'servicio_id', 'servicioId']) {
          final id = parseId(s[key]);
          if (id != null && id > 0) return id;
        }
      }
    }
    return null;
  }
}
