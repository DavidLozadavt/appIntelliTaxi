import 'package:flutter/widgets.dart';
import 'package:intellitaxi/core/utils/device_screen_helper.dart';
import 'package:intellitaxi/core/utils/fcm_isolate_context.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Estado de primer plano de la app.
class AppLifecycleHelper {
  AppLifecycleHelper._();

  static const _foregroundKey = 'app_lifecycle_is_foreground';
  static const _mainActivityResumedKey = 'main_activity_resumed';

  /// Persiste el estado para isolates sin binding fiable (FCM background).
  static Future<void> persistLifecycleState(AppLifecycleState state) async {
    final inForeground = state == AppLifecycleState.resumed ||
        state == AppLifecycleState.inactive;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_foregroundKey, inForeground);
    } catch (_) {}
  }

  static Future<bool> _readPersistedForeground() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_foregroundKey) ?? false;
    } catch (_) {
      return false;
    }
  }

  static bool isInForeground() {
    if (FcmIsolateContext.isBackgroundHandler) {
      return false;
    }
    final state = WidgetsBinding.instance.lifecycleState;
    if (state == AppLifecycleState.resumed) return true;
    if (state == AppLifecycleState.inactive) return true;
    return false;
  }

  static Future<bool> isInForegroundReliable() async {
    if (FcmIsolateContext.isBackgroundHandler) {
      return _readPersistedForeground();
    }
    if (isInForeground()) return true;
    return _readPersistedForeground();
  }

  /// MainActivity visible (no confundir con burbuja: el proceso puede seguir FOREGROUND).
  static Future<bool> isMainActivityVisible() async {
    if (FcmIsolateContext.isBackgroundHandler) {
      return _readMainActivityResumed();
    }
    if (isInForeground()) return true;
    return _readMainActivityResumed();
  }

  static Future<bool> _readMainActivityResumed() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_mainActivityResumedKey) ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Alerta full-screen / heads-up: app en background O pantalla apagada (aunque lifecycle sea resumed).
  static Future<bool> shouldShowIncomingServiceAlert() async {
    if (!isInForeground()) return true;
    final screenOn = await DeviceScreenHelper.isScreenOn();
    return !screenOn;
  }
}
