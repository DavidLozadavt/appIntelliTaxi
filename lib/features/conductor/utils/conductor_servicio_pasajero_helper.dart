import 'package:intellitaxi/config/app_config.dart';

/// Datos del pasajero extraídos del payload del servicio (API / Pusher).
class ConductorServicioPasajeroHelper {
  ConductorServicioPasajeroHelper._();

  static String nombre(Map<String, dynamic> servicio) {
    if (servicio['pasajero_nombre'] != null) {
      return servicio['pasajero_nombre'].toString();
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
      return pasajero['nombre']?.toString() ??
          pasajero['name']?.toString() ??
          'Pasajero';
    }

    return 'Pasajero';
  }

  static String? telefono(Map<String, dynamic> servicio) {
    final usuarioPasajero = servicio['usuario_pasajero'];
    if (usuarioPasajero is Map && usuarioPasajero['persona'] is Map) {
      final persona = usuarioPasajero['persona'] as Map;
      final celular = persona['celular'];
      if (celular != null && celular.toString().isNotEmpty) {
        return celular.toString();
      }
    }

    if (servicio['pasajero_telefono'] != null) {
      return servicio['pasajero_telefono'].toString();
    }

    final pasajero = servicio['pasajero'];
    if (pasajero is Map) {
      return pasajero['telefono']?.toString() ??
          pasajero['phone']?.toString() ??
          pasajero['celular']?.toString();
    }

    return null;
  }

  static String? fotoUrl(Map<String, dynamic> servicio) {
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
}
