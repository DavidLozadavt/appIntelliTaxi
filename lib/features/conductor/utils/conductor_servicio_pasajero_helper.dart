import 'package:intellitaxi/config/app_config.dart';

/// Datos del pasajero / cliente extraídos del payload del servicio (API / Pusher).
/// Servicios web (APP_WEB, IA) pueden no traer objeto `pasajero`; el teléfono va en
/// [telefonoLlamada].
class ConductorServicioPasajeroHelper {
  ConductorServicioPasajeroHelper._();

  static bool esOrigenWeb(Map<String, dynamic> servicio) {
    final origen = (servicio['origenServicio'] ??
            servicio['origen_servicio'] ??
            '')
        .toString()
        .toUpperCase();
    return origen.contains('WEB') || origen == 'APP_WEB';
  }

  static bool tienePasajeroEnPayload(Map<String, dynamic> servicio) {
    final nombre = servicio['pasajero_nombre']?.toString().trim();
    if (nombre != null &&
        nombre.isNotEmpty &&
        nombre.toLowerCase() != 'pasajero') {
      return true;
    }

    if (servicio['usuario_pasajero'] is Map) return true;

    final pasajero = servicio['pasajero'];
    if (pasajero is Map) {
      final n =
          pasajero['nombre']?.toString() ?? pasajero['name']?.toString() ?? '';
      if (n.trim().isNotEmpty) return true;
    }

    return false;
  }

  /// Servicio pedido por web / IA sin usuario pasajero en BD.
  static bool esServicioSinPasajeroRegistrado(Map<String, dynamic> servicio) {
    if (tienePasajeroEnPayload(servicio)) return false;
    if (esOrigenWeb(servicio)) return true;
    return telefonoLlamada(servicio) != null;
  }

  static String? telefonoLlamada(Map<String, dynamic> servicio) {
    for (final key in const [
      'telefonoLlamada',
      'telefono_llamada',
      'telefono_llamada_servicio',
    ]) {
      final v = servicio[key]?.toString().trim();
      if (v != null && v.isNotEmpty) return v;
    }
    return null;
  }

  static String nombre(Map<String, dynamic> servicio) {
    final desdePasajero = _nombreDesdePasajero(servicio);
    if (desdePasajero != null) return desdePasajero;

    if (esServicioSinPasajeroRegistrado(servicio)) {
      final tel = telefono(servicio);
      if (tel != null && tel.isNotEmpty) {
        return 'Cliente web · $tel';
      }
      return 'Cliente web';
    }

    return 'Pasajero';
  }

  static String? telefono(Map<String, dynamic> servicio) {
    final usuarioPasajero = servicio['usuario_pasajero'];
    if (usuarioPasajero is Map && usuarioPasajero['persona'] is Map) {
      final persona = usuarioPasajero['persona'] as Map;
      final celular = persona['celular'];
      if (celular != null && celular.toString().trim().isNotEmpty) {
        return celular.toString().trim();
      }
    }

    if (servicio['pasajero_telefono'] != null) {
      final v = servicio['pasajero_telefono'].toString().trim();
      if (v.isNotEmpty) return v;
    }

    final pasajero = servicio['pasajero'];
    if (pasajero is Map) {
      for (final key in const ['telefono', 'phone', 'celular']) {
        final v = pasajero[key]?.toString().trim();
        if (v != null && v.isNotEmpty) return v;
      }
    }

    return telefonoLlamada(servicio);
  }

  static String? fotoUrl(Map<String, dynamic> servicio) {
    if (esServicioSinPasajeroRegistrado(servicio)) return null;

    final usuarioPasajero = servicio['usuario_pasajero'];
    if (usuarioPasajero is Map && usuarioPasajero['persona'] is Map) {
      final persona = usuarioPasajero['persona'] as Map;
      final fotoRaw =
          persona['rutaFotoUrl'] ?? persona['rutaFoto'] ?? persona['foto'];
      final foto = resolverFotoUrl(fotoRaw?.toString());
      if (foto != null) return foto;
    }

    final fotoServicio = resolverFotoUrl(
      servicio['pasajero_foto']?.toString(),
    );
    if (fotoServicio != null) return fotoServicio;

    final pasajero = servicio['pasajero'];
    if (pasajero is Map) {
      return resolverFotoUrl(
        pasajero['rutaFotoUrl']?.toString() ??
            pasajero['rutaFoto']?.toString() ??
            pasajero['foto']?.toString(),
      );
    }

    return null;
  }

  static String? resolverFotoUrl(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final foto = value.trim();
    if (foto.startsWith('http://') || foto.startsWith('https://')) return foto;

    final base = Uri.parse(AppConfig.baseUrl);
    final origin =
        '${base.scheme}://${base.host}${base.hasPort ? ':${base.port}' : ''}';
    if (foto.startsWith('/')) return '$origin$foto';
    return '$origin/$foto';
  }

  static String? _nombreDesdePasajero(Map<String, dynamic> servicio) {
    final directo = servicio['pasajero_nombre']?.toString().trim();
    if (directo != null &&
        directo.isNotEmpty &&
        directo.toLowerCase() != 'pasajero') {
      return directo;
    }

    final usuarioPasajero = servicio['usuario_pasajero'];
    if (usuarioPasajero is Map && usuarioPasajero['persona'] is Map) {
      final persona = Map<String, dynamic>.from(
        usuarioPasajero['persona'] as Map,
      );
      final nombre1 = persona['nombre1']?.toString() ?? '';
      final nombre2 = persona['nombre2']?.toString() ?? '';
      final apellido1 = persona['apellido1']?.toString() ?? '';
      final apellido2 = persona['apellido2']?.toString() ?? '';
      final nombreCompleto =
          '$nombre1 ${nombre2.isEmpty ? '' : nombre2} $apellido1 ${apellido2.isEmpty ? '' : apellido2}'
              .trim();
      if (nombreCompleto.isNotEmpty) return nombreCompleto;
    }

    final pasajero = servicio['pasajero'];
    if (pasajero is Map) {
      final n = pasajero['nombre']?.toString() ??
          pasajero['name']?.toString() ??
          '';
      if (n.trim().isNotEmpty) return n.trim();
    }

    return null;
  }
}
