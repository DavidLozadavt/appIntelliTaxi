import 'package:shared_preferences/shared_preferences.dart';

/// Preferencia del conductor: mantener pantalla encendida durante el turno.
abstract final class KeepScreenOnPrefs {
  static const _key = 'conductor_keep_screen_on';

  static Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_key) ?? true;
  }

  static Future<void> setEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, value);
  }
}
