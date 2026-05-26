import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:intellitaxi/core/services/app_logger.dart';
import 'package:intellitaxi/main.dart';

/// Trae la actividad principal al frente (Android) y restaura la ruta home.
class AppForegroundService {
  AppForegroundService._();
  static final AppForegroundService instance = AppForegroundService._();

  static const MethodChannel _channel =
      MethodChannel('com.virtualt.intellitaxi/app');

  /// Solo abre la Activity (válido desde el isolate del overlay).
  Future<void> launchNativeApp() async {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      try {
        await _channel.invokeMethod<void>('bringToForeground');
      } catch (e, st) {
        AppLogger.e(
          'No se pudo abrir la app nativamente',
          tag: 'AppForeground',
          error: e,
          stackTrace: st,
        );
      }
    }
  }

  /// Registra el canal en el motor Flutter del overlay (isolate secundario).
  Future<void> ensureOverlayNativeChannel() async {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      try {
        await _channel.invokeMethod<void>('ensureOverlayChannel');
      } catch (e, st) {
        AppLogger.e(
          'No se pudo registrar canal del overlay',
          tag: 'AppForeground',
          error: e,
          stackTrace: st,
        );
      }
    }
  }

  /// Abre la app y navega al home (solo desde el isolate principal).
  Future<void> bringAppToForeground() async {
    await launchNativeApp();

    final nav = navigatorKey.currentState;
    if (nav == null) return;
    nav.pushNamedAndRemoveUntil('/home', (route) => false);
  }
}
