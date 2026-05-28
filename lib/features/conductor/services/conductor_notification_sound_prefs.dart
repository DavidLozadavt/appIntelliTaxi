import 'package:shared_preferences/shared_preferences.dart';
import 'package:intellitaxi/features/conductor/data/conductor_notification_sound_catalog.dart';
import 'package:intellitaxi/features/conductor/data/conductor_notification_sound_option.dart';

/// Preferencia local del tono de nuevo servicio por conductor/dispositivo.
class ConductorNotificationSoundPrefs {
  ConductorNotificationSoundPrefs._();

  static const String _keySoundId = 'conductor_notification_sound_id';

  static Future<String> getSelectedSoundId() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_keySoundId);
    if (ConductorNotificationSoundCatalog.byId(stored) != null) {
      return stored!;
    }
    return ConductorNotificationSoundCatalog.defaultSoundId;
  }

  static Future<ConductorNotificationSoundOption> getSelectedOption() async {
    final id = await getSelectedSoundId();
    return ConductorNotificationSoundCatalog.byId(id) ??
        ConductorNotificationSoundCatalog.defaultOption;
  }

  static Future<void> setSelectedSoundId(String id) async {
    if (ConductorNotificationSoundCatalog.byId(id) == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keySoundId, id);
  }
}
