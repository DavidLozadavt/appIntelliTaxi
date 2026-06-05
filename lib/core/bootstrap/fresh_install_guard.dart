import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';
import 'package:intellitaxi/core/bootstrap/session_preload.dart';
import 'package:intellitaxi/core/services/app_logger.dart';
import 'package:intellitaxi/core/services/geocode_memory_cache.dart';
import 'package:intellitaxi/features/auth/services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Detecta reinstalación y limpia prefs/caché heredada (p. ej. backup Android).
class FreshInstallGuard {
  FreshInstallGuard._();

  static const MethodChannel _channel = MethodChannel(
    'com.virtualt.intellitaxi/app',
  );

  static const String _installEpochKey = '_app_install_epoch_ms';

  /// Debe ejecutarse antes de [SessionPreload.start].
  static Future<void> ensureCleanStateIfNeeded() async {
    if (kIsWeb) return;

    final firstInstallMs = await _readFirstInstallEpochMs();
    if (firstInstallMs == null) return;

    final prefs = await SharedPreferences.getInstance();
    final storedEpoch = prefs.getInt(_installEpochKey);

    if (storedEpoch != null && storedEpoch != firstInstallMs) {
      AppLogger.i(
        'Reinstalación detectada ($storedEpoch → $firstInstallMs): limpiando caché local',
        tag: 'FreshInstall',
      );
      await _wipeLocalCaches();
    }

    final prefsAfter = await SharedPreferences.getInstance();
    await prefsAfter.setInt(_installEpochKey, firstInstallMs);
  }

  static Future<int?> _readFirstInstallEpochMs() async {
    try {
      final result = await _channel.invokeMethod<Object>('checkFreshInstall');
      if (result is Map) {
        final raw = result['firstInstallMs'];
        if (raw is int) return raw;
        if (raw is num) return raw.toInt();
      }
    } catch (e) {
      AppLogger.d(
        'checkFreshInstall no disponible: $e',
        tag: 'FreshInstall',
      );
    }
    return null;
  }

  static Future<void> _wipeLocalCaches() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
    } catch (e) {
      AppLogger.w(
        'No se pudo limpiar SharedPreferences: $e',
        tag: 'FreshInstall',
      );
    }

    AuthService.invalidatePrefsCache();
    SessionPreload.invalidate();
    GeocodeMemoryCache.instance.clear();

    final imageCache = PaintingBinding.instance.imageCache;
    imageCache.clear();
    imageCache.clearLiveImages();
  }
}
