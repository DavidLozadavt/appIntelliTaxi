/// Resolución de estado UI del servicio activo del conductor (sin dependencias de Flutter).
class ConductorServicioEstadoHelper {
  ConductorServicioEstadoHelper._();

  static double parseDouble(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  static bool tieneDestinoDefinido(Map<String, dynamic> servicio) {
    final lat = parseDouble(servicio['destino_lat']);
    final lng = parseDouble(servicio['destino_lng']);
    return lat != 0.0 && lng != 0.0;
  }

  static int? idEstadoServicio(Map<String, dynamic> servicio) {
    final estadoObj = servicio['estado'];
    final raw = servicio['idEstado'] ??
        servicio['id_estado'] ??
        (estadoObj is Map ? estadoObj['id'] : null);
    if (raw is int) return raw;
    return int.tryParse(raw?.toString() ?? '');
  }

  static String? estadoDesdeId(int? idEstado) {
    switch (idEstado) {
      case 1:
      case 2:
        return 'aceptado';
      case 19:
        return 'en_camino';
      case 3:
      case 20:
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
        return null;
    }
  }

  static String? normalizarEstadoBackend(dynamic estadoRaw) {
    String? estado;
    if (estadoRaw is String) {
      estado = estadoRaw;
    } else if (estadoRaw is Map && estadoRaw['estado'] is String) {
      estado = estadoRaw['estado'] as String;
    }

    if (estado == null || estado.trim().isEmpty) return null;

    final e = estado
        .trim()
        .toLowerCase()
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('-', '_')
        .replaceAll(' ', '_');

    if (e.contains('en_curso') || e.contains('curso')) return 'en_curso';
    if (e.contains('llegue') || e.contains('llego')) return 'llegue';
    if (e.contains('en_camino') || e.contains('camino')) return 'en_camino';
    if (e.contains('acept')) return 'aceptado';
    if (e.contains('cancel')) return 'cancelado';
    if (e.contains('final') || e.contains('complet')) return 'finalizado';

    return null;
  }

  static String resolverEstadoInicial(Map<String, dynamic> servicio) {
    final estadoDesdeCampo =
        normalizarEstadoBackend(servicio['estado']);
    if (estadoDesdeCampo != null) return estadoDesdeCampo;

    final idEstadoRaw = servicio['idEstado'] ?? servicio['id_estado'];
    final idEstado = idEstadoRaw is int
        ? idEstadoRaw
        : int.tryParse(idEstadoRaw?.toString() ?? '');

    return estadoDesdeId(idEstado) ?? 'aceptado';
  }

  static String estadoUi({
    required Map<String, dynamic> servicio,
    required String estadoActual,
  }) {
    return estadoDesdeId(idEstadoServicio(servicio)) ??
        normalizarEstadoBackend(estadoActual) ??
        resolverEstadoInicial(servicio);
  }

  static String estadoUiEfectivo({
    required Map<String, dynamic> servicio,
    required String estadoActual,
  }) {
    return estadoDesdeId(idEstadoServicio(servicio)) ??
        normalizarEstadoBackend(servicio['estado']) ??
        estadoUi(servicio: servicio, estadoActual: estadoActual);
  }

  static String mensajeEstado(String estado) {
    switch (estado) {
      case 'en_camino':
        return 'En camino al punto de recogida';
      case 'llegue':
        return '¡Has llegado! Esperando al pasajero';
      case 'en_curso':
        return 'Viaje iniciado';
      case 'finalizado':
        return '¡Viaje finalizado exitosamente!';
      default:
        return 'Estado actualizado';
    }
  }
}
