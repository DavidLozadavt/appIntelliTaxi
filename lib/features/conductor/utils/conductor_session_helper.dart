import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// IDs de sesión del conductor (user / persona) para canales Pusher privados.
class ConductorSessionHelper {
  ConductorSessionHelper._();

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
