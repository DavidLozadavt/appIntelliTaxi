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

  /// `persona.id` del conductor (comparaciones de aceptación / tomada).
  static Future<int?> obtenerIdPersonaConductor() async {
    final ids = await obtenerIdsConductorSesion();
    if (ids.isEmpty) return null;
    final prefs = await SharedPreferences.getInstance();
    final userDataStr = prefs.getString('user_data');
    if (userDataStr != null && userDataStr.isNotEmpty) {
      try {
        final userData = json.decode(userDataStr);
        final personaId = userData['user']?['persona']?['id'];
        final parsed = personaId is int
            ? personaId
            : int.tryParse(personaId?.toString() ?? '');
        if (parsed != null && parsed > 0) return parsed;
      } catch (_) {}
    }
    return ids.first;
  }

  /// IDs de sesión posibles (`user.id`, `persona.id`, prefs) para canales privados.
  static Future<Set<int>> obtenerIdsConductorSesion() async {
    final prefs = await SharedPreferences.getInstance();
    final ids = <int>{};

    for (final raw in [
      prefs.getInt('conductor_id'),
      prefs.getInt('user_id'),
    ]) {
      if (raw != null && raw > 0) ids.add(raw);
    }

    final userDataStr = prefs.getString('user_data');
    if (userDataStr == null || userDataStr.isEmpty) return ids;

    try {
      final userData = json.decode(userDataStr);
      for (final value in [
        userData['user']?['id'],
        userData['user']?['persona']?['id'],
        userData['id'],
      ]) {
        final parsed = value is int
            ? value
            : int.tryParse(value?.toString() ?? '');
        if (parsed != null && parsed > 0) ids.add(parsed);
      }
    } catch (_) {}

    return ids;
  }

  /// Canales privados: `private-conductor.{personaId}` (+ alias legacy por otros IDs de sesión).
  static Set<String> canalesOfertaDirecta(Set<int> idsConductor) {
    final channels = <String>{};
    for (final id in idsConductor) {
      if (id <= 0) continue;
      channels.add('private-conductor.$id');
      channels.add('conductor.$id');
    }
    return channels;
  }
}
