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

  static Future<Set<int>> obtenerIdsConductorSesion() async {
    final prefs = await SharedPreferences.getInstance();
    final userDataStr = prefs.getString('user_data');
    if (userDataStr == null || userDataStr.isEmpty) return {};

    try {
      final userData = json.decode(userDataStr);
      final ids = <int>{};

      final userId = userData['user']?['id'];
      final personaId = userData['user']?['persona']?['id'];

      final parsedUserId = userId is int
          ? userId
          : int.tryParse(userId?.toString() ?? '');
      final parsedPersonaId = personaId is int
          ? personaId
          : int.tryParse(personaId?.toString() ?? '');

      if (parsedUserId != null && parsedUserId > 0) ids.add(parsedUserId);
      if (parsedPersonaId != null && parsedPersonaId > 0) {
        ids.add(parsedPersonaId);
      }

      return ids;
    } catch (_) {
      return {};
    }
  }

  /// Canales candidatos para ofertas directas (`private-conductor.{id}` y fallback).
  static Set<String> canalesOfertaDirecta(Set<int> idsConductor) {
    final channels = <String>{};
    for (final id in idsConductor) {
      channels.add('private-conductor.$id');
      channels.add('conductor.$id');
    }
    return channels;
  }
}
