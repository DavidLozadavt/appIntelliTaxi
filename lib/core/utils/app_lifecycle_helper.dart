import 'package:flutter/widgets.dart';
import 'package:intellitaxi/core/utils/device_screen_helper.dart';

/// Estado de primer plano de la app.
class AppLifecycleHelper {
  AppLifecycleHelper._();

  static bool isInForeground() {
    final state = WidgetsBinding.instance.lifecycleState;
    return state == null || state == AppLifecycleState.resumed;
  }

  /// Alerta full-screen / heads-up: app en background O pantalla apagada (aunque lifecycle sea resumed).
  static Future<bool> shouldShowIncomingServiceAlert() async {
    if (!isInForeground()) return true;
    final screenOn = await DeviceScreenHelper.isScreenOn();
    return !screenOn;
  }
}
