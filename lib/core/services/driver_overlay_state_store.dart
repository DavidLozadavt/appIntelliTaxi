import 'package:shared_preferences/shared_preferences.dart';

/// Estado persistente de la burbuja (sobrevive a minimizar / isolate FCM).
class DriverOverlayStateStore {
  DriverOverlayStateStore._();

  static const _armedKey = 'driver_overlay_armed_v1';

  static Future<void> setArmed(bool armed) async {
    final prefs = await SharedPreferences.getInstance();
    if (armed) {
      await prefs.setBool(_armedKey, true);
    } else {
      await prefs.remove(_armedKey);
    }
  }

  /// Turno activo listo para burbuja al minimizar.
  static Future<bool> isArmed() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_armedKey) == true) return true;
      final turnoId = prefs.getInt('turno_activo_id');
      return turnoId != null && turnoId > 0;
    } catch (_) {
      return false;
    }
  }
}
