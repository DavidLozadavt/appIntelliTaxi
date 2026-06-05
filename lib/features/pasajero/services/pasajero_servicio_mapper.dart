import 'package:google_maps_flutter/google_maps_flutter.dart';

class PasajeroServicioMapper {
  static dynamic pick(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      if (data.containsKey(key) && data[key] != null) {
        return data[key];
      }
    }
    return null;
  }

  static double parseDouble(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  static LatLng origen(Map<String, dynamic> data) {
    final lat = parseDouble(pick(data, ['origen_lat', 'origenLat']));
    final lng = parseDouble(pick(data, ['origen_lng', 'origenLng']));
    return LatLng(lat, lng);
  }

  static LatLng? destino(Map<String, dynamic> data) {
    final lat = parseDouble(pick(data, ['destino_lat', 'destinoLat']));
    final lng = parseDouble(pick(data, ['destino_lng', 'destinoLng']));
    if (lat == 0.0 || lng == 0.0) return null;
    return LatLng(lat, lng);
  }

  static bool hasConductorAsignado(Map<String, dynamic> data) {
    return pick(data, ['conductor_id', 'idConductor', 'conductorId']) != null;
  }

  static LatLng? conductorUbicacion(Map<String, dynamic> data) {
    final lat = pick(data, ['conductor_lat', 'conductorLat', 'lat_conductor']);
    final lng = pick(data, ['conductor_lng', 'conductorLng', 'lng_conductor']);
    if (lat == null || lng == null) return null;
    return LatLng(parseDouble(lat), parseDouble(lng));
  }

  static Map<String, dynamic>? conductorResumen(
    Map<String, dynamic> source, {
    Map<String, dynamic>? conductor,
    Map<String, dynamic>? vehiculo,
  }) {
    final c = conductor ?? source['conductor'] as Map<String, dynamic>?;
    if (c == null) return null;

    final v =
        vehiculo ??
        (c['vehiculo'] is Map<String, dynamic>
            ? c['vehiculo'] as Map<String, dynamic>
            : source['vehiculo'] as Map<String, dynamic>?);

    return {
      'conductor_id':
          pick(c, ['id', 'conductor_id', 'conductorId']) ??
          pick(source, ['conductor_id', 'idConductor', 'conductorId']),
      'conductor_nombre':
          pick(c, ['nombre', 'conductor_nombre']) ?? 'Conductor',
      'conductor_telefono': pick(c, ['telefono', 'celular']) ?? '',
      'conductor_foto': pick(c, ['foto', 'conductor_foto', 'foto_perfil']),
      'conductor_calificacion':
          pick(c, [
            'calificacion',
            'conductor_calificacion',
            'calificacion_promedio',
          ]) ??
          5.0,
      'vehiculo_placa': v?['placa'] ?? '',
      'vehiculo_marca': v?['marca'] ?? '',
      'vehiculo_modelo': v?['modelo'] ?? '',
      'vehiculo_color': v?['color'] ?? '',
    };
  }

  static String normalizeEstado(dynamic raw) {
    if (raw == null) return 'buscando';
    final estado = raw.toString().trim().toLowerCase();

    if (estado.contains('en_curso') || estado.contains('curso')) {
      return 'en_curso';
    }
    if (estado.contains('llegue') || estado.contains('llego')) return 'llegue';
    if (estado.contains('acept') ||
        estado.contains('activo') ||
        estado.contains('en_camino') ||
        estado.contains('asignado')) {
      return 'aceptado';
    }
    if (estado.contains('cancel')) {
      return 'cancelado';
    }
    if (estado.contains('pend')) {
      return 'pendiente';
    }
    if (estado.contains('final')) {
      return 'finalizado';
    }
    if (estado.contains('timeout')) return 'timeout';
    if (estado.contains('busc')) return 'buscando';
    return 'buscando';
  }

  static String estadoInicial(Map<String, dynamic> data) {
    final estadoRaw = data['estado'];
    if (estadoRaw is String && estadoRaw.isNotEmpty) {
      return normalizeEstado(estadoRaw);
    }
    if (estadoRaw is Map && estadoRaw['estado'] is String) {
      return normalizeEstado(estadoRaw['estado']);
    }

    final idEstadoRaw = pick(data, ['idEstado', 'id_estado']);
    final idEstado = idEstadoRaw is int
        ? idEstadoRaw
        : int.tryParse(idEstadoRaw?.toString() ?? '');
    final hasConductor = hasConductorAsignado(data);

    switch (idEstado) {
      case 1:
      case 2:
      case 20:
        return hasConductor ? 'aceptado' : 'buscando';
      case 4:
        return hasConductor ? 'aceptado' : 'pendiente';
      case 3:
        return 'llegue';
      case 21:
        return 'en_curso';
      case 6:
        return 'cancelado';
      case 5:
      case 7:
      case 22:
      case 23:
        return 'finalizado';
      default:
        return hasConductor ? 'aceptado' : 'buscando';
    }
  }

  /// Indica que el conductor liberó/rechazó un servicio ya asignado.
  static bool esRechazoConductor(Map<String, dynamic> data) {
    final motivo = (pick(data, [
          'motivo',
          'motivo_codigo',
          'motivoCodigo',
          'tipo',
        ]) ??
            '')
        .toString()
        .trim()
        .toLowerCase();
    if (motivo.isEmpty) return false;
    return motivo == 'conductor_rechazo' ||
        motivo == 'rechazo_conductor' ||
        motivo == 'rechazada_por_conductor' ||
        motivo == 'conductor_rechazo_servicio' ||
        (motivo.contains('rechaz') && motivo.contains('conductor'));
  }

  /// Estado UI coherente con conductor ya asignado (evita «buscando» + tarjeta de conductor).
  static String resolverEstadoUi(Map<String, dynamic> data) {
    final estado = estadoInicial(data);
    final tieneConductor =
        hasConductorAsignado(data) || data['conductor'] is Map;
    if (tieneConductor &&
        (estado == 'buscando' || estado == 'pendiente')) {
      return 'aceptado';
    }
    return estado;
  }
}
