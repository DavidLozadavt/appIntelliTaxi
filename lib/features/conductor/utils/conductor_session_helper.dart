import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// IDs de sesión del conductor (user / persona) para canales Pusher privados.
class ConductorSessionHelper {
  ConductorSessionHelper._();

  static const String _keyServiciosRechazados = 'conductor_servicios_rechazados';

  /// IDs de servicios que el conductor rechazó (persistencia local).
  static Future<Set<int>> cargarServiciosRechazadosLocal() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyServiciosRechazados);
    if (raw == null || raw.isEmpty) return {};

    try {
      final decoded = json.decode(raw);
      if (decoded is! List) return {};
      return decoded
          .map((e) => int.tryParse(e.toString()))
          .whereType<int>()
          .where((id) => id > 0)
          .toSet();
    } catch (_) {
      return {};
    }
  }

  static Future<void> guardarServiciosRechazados(Set<int> ids) async {
    final prefs = await SharedPreferences.getInstance();
    final lista = ids.where((id) => id > 0).toList()..sort();
    await prefs.setString(_keyServiciosRechazados, json.encode(lista));
  }

  static Future<void> agregarServicioRechazado(int servicioId) async {
    if (servicioId <= 0) return;
    final actuales = await cargarServiciosRechazadosLocal();
    actuales.add(servicioId);
    await guardarServiciosRechazados(actuales);
  }

  /// `persona.id` del conductor (no `user.id`) — canal `private-conductor.{idPersona}`.
  static Future<int?> obtenerIdPersonaConductor() async {
    final prefs = await SharedPreferences.getInstance();
    final userDataStr = prefs.getString('user_data');
    if (userDataStr == null || userDataStr.isEmpty) return null;

    try {
      final userData = json.decode(userDataStr);
      final personaId = userData['user']?['persona']?['id'];
      if (personaId is int && personaId > 0) return personaId;
      return int.tryParse(personaId?.toString() ?? '');
    } catch (_) {
      return null;
    }
  }

  /// Canal privado del conductor (`servicio.cercano`, ofertas directas).
  static Set<String> canalesOfertaDirecta(int? idPersona) {
    if (idPersona == null || idPersona <= 0) return {};
    return {'private-conductor.$idPersona'};
  }
}
