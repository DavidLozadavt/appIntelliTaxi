class ServicioPayloadAdapter {
  /// Normaliza el payload del servicio para que la app pueda usar
  /// los campos tanto en snake_case como en camelCase sin romperse.
  static Map<String, dynamic> normalize({
    required Map<String, dynamic> servicio,
    Map<String, dynamic>? pasajero,
    Map<String, dynamic>? conductor,
    Map<String, dynamic>? vehiculo,
  }) {
    final origenLat = servicio['origen_lat'] ?? servicio['origenLat'];
    final origenLng = servicio['origen_lng'] ?? servicio['origenLng'];
    final destinoLat = servicio['destino_lat'] ?? servicio['destinoLat'];
    final destinoLng = servicio['destino_lng'] ?? servicio['destinoLng'];

    final origenAddress =
        servicio['origen_address'] ?? servicio['origenAddress'] ?? 'Origen';
    final destinoAddress =
        servicio['destino_address'] ?? servicio['destinoAddress'] ?? 'Destino';

    final distancia = servicio['distancia'] ?? servicio['distanciaTexto'];
    final duracion = servicio['duracion'] ?? servicio['duracionTexto'];
    final precioFinal = servicio['precio_final'] ?? servicio['precioFinal'];

    final normalized = <String, dynamic>{
      ...servicio,
      'origen_lat': origenLat,
      'origen_lng': origenLng,
      'destino_lat': destinoLat,
      'destino_lng': destinoLng,
      'origen_address': origenAddress,
      'destino_address': destinoAddress,
      'origenLat': origenLat,
      'origenLng': origenLng,
      'destinoLat': destinoLat,
      'destinoLng': destinoLng,
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
