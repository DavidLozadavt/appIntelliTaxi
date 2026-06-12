import 'package:shared_preferences/shared_preferences.dart';

/// Comprueba si hay sesión activa antes de procesar o mostrar push.
class FcmSessionGuard {
  FcmSessionGuard._();

  static const _tokenKey = 'token';
  static const _activeRoleKey = 'active_role';

  static Future<bool> hasActiveSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(_tokenKey)?.trim() ?? '';
      return token.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> isActiveConductorRole() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final role = prefs.getString(_activeRoleKey)?.toUpperCase() ?? '';
      return _isConductorRole(role);
    } catch (_) {
      return false;
    }
  }

  static bool _isConductorRole(String role) {
    return role == 'CONDUCTOR-INTELLITAXI' ||
        role == 'CONDUCTOR' ||
        role == 'MOTORISTA' ||
        role == 'DRIVER';
  }

  /// Push de cola / solicitud entrante: sesión + rol conductor activo.
  static Future<bool> shouldProcessConductorIncomingPush() async {
    if (!await hasActiveSession()) return false;
    return await isActiveConductorRole();
  }
}
