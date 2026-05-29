import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:intellitaxi/core/diagnostics/app_diagnostics.dart';
import 'package:intellitaxi/core/services/app_logger.dart';

/// Pantalla encendida / desbloqueo (Android).
class DeviceScreenHelper {
  DeviceScreenHelper._();

  static const MethodChannel _channel =
      MethodChannel('com.virtualt.intellitaxi/app');

  static bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// `true` si la pantalla está encendida e interactiva.
  static Future<bool> isScreenOn() async {
    if (!_isAndroid) return true;
    try {
      final on = await _channel.invokeMethod<bool>('isScreenOn');
      return on ?? true;
    } catch (e) {
      AppLogger.d('⚠️ isScreenOn: $e');
      return true;
    }
  }

  /// Enciende pantalla y prepara la Activity para mostrarse sobre bloqueo.
  static Future<void> wakeForIncomingService() async {
    if (!_isAndroid) return;
    AppDiagnostics.record('native', 'wakeForIncomingService');
    try {
      await _channel.invokeMethod<void>('wakeForIncomingService');
    } catch (e) {
      AppLogger.d('⚠️ wakeForIncomingService: $e');
    }
  }

  /// `FLAG_KEEP_SCREEN_ON` en la Activity (refuerzo junto a wakelock_plus).
  static Future<void> setKeepScreenOn(bool enable) async {
    if (!_isAndroid) return;
    try {
      await _channel.invokeMethod<void>('setKeepScreenOn', {'enable': enable});
    } catch (e) {
      AppLogger.d('⚠️ setKeepScreenOn: $e');
    }
  }
}
