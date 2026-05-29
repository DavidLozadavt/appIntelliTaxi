import 'package:flutter/foundation.dart';
import 'package:intellitaxi/core/services/app_logger.dart';
import 'package:intellitaxi/core/services/keep_screen_on_prefs.dart';
import 'package:intellitaxi/core/utils/device_screen_helper.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// Mantiene la pantalla encendida mientras haya al menos un [hold] activo
/// y la preferencia del conductor esté activada.
class KeepScreenOnService {
  KeepScreenOnService._();

  static final Set<String> _holds = {};
  static bool _userEnabled = true;
  static bool _applied = false;

  static bool get userEnabled => _userEnabled;

  static Future<void> loadPreference() async {
    _userEnabled = await KeepScreenOnPrefs.isEnabled();
    await _sync();
  }

  static Future<void> setUserEnabled(bool enabled) async {
    _userEnabled = enabled;
    await KeepScreenOnPrefs.setEnabled(enabled);
    await _sync();
  }

  static Future<void> acquire(String reason) async {
    if (_holds.add(reason)) {
      await _sync();
    }
  }

  static Future<void> release(String reason) async {
    if (_holds.remove(reason)) {
      await _sync();
    }
  }

  static Future<void> releaseAll() async {
    if (_holds.isEmpty) return;
    _holds.clear();
    await _sync();
  }

  static Future<void> _sync() async {
    final shouldEnable = _userEnabled && _holds.isNotEmpty;

    if (shouldEnable == _applied) return;

    try {
      if (shouldEnable) {
        await WakelockPlus.enable();
        await DeviceScreenHelper.setKeepScreenOn(true);
        _applied = true;
        if (kDebugMode) {
          AppLogger.d(
            'Pantalla siempre activa ON (${_holds.join(', ')})',
            tag: 'KeepScreenOn',
          );
        }
      } else {
        await WakelockPlus.disable();
        await DeviceScreenHelper.setKeepScreenOn(false);
        _applied = false;
        if (kDebugMode) {
          AppLogger.d('Pantalla siempre activa OFF', tag: 'KeepScreenOn');
        }
      }
    } catch (e) {
      AppLogger.w('KeepScreenOn sync: $e', tag: 'KeepScreenOn');
    }
  }
}
