class ServicioPayloadAdapter {
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

    return normalized;
  }
}
