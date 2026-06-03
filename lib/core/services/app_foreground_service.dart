import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intellitaxi/core/diagnostics/app_diagnostics.dart';
import 'package:intellitaxi/core/services/app_logger.dart';
import 'package:intellitaxi/features/auth/providers/auth_provider.dart';
import 'package:intellitaxi/features/conductor/utils/conductor_pending_fcm.dart';
import 'package:intellitaxi/main.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Trae la actividad principal al frente (Android) y restaura la ruta home.
class AppForegroundService {
  AppForegroundService._();
  static final AppForegroundService instance = AppForegroundService._();

  static const MethodChannel _channel =
      MethodChannel('com.virtualt.intellitaxi/app');

  static const _pendingNativeLaunchKey = 'pending_native_launch_app';

  /// Solo abre la Activity (válido desde el isolate del overlay).
  Future<void> launchNativeApp() async {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      AppDiagnostics.record('native', 'bringToForeground');
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

  /// Marca que MainActivity debe abrirse al volver al proceso (FCM en background).
  static Future<void> markPendingNativeLaunch() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_pendingNativeLaunchKey, true);
  }

  /// Si FCM pidió abrir la app y el canal falló en background, reintenta al resume.
  static Future<void> flushPendingNativeLaunch() async {
    final prefs = await SharedPreferences.getInstance();
    if (!(prefs.getBool(_pendingNativeLaunchKey) ?? false)) return;
    await prefs.remove(_pendingNativeLaunchKey);
    await AppForegroundService.instance.launchNativeApp();
    await ConductorPendingFcm.ensureLoaded();
    final ctx = navigatorKey.currentContext;
    if (ctx != null && ctx.mounted) {
      await ConductorPendingFcm.flush(ctx);
    }
    AppForegroundService.instance._navigateHomeIfSessionReady();
  }

  /// Abre la app. No fuerza `/home` si la sesión aún no está hidratada (evita
  /// spinner infinito al abrir desde FCM en cold start o hot restart).
  Future<void> bringAppToForeground() async {
    await launchNativeApp();
    _navigateHomeIfSessionReady();
  }

  /// Varios intentos: canal nativo, overlay y bandera para reintentar al resume.
  Future<void> openAppAggressively() async {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      await markPendingNativeLaunch();
    }
    await launchNativeApp();
    _scheduleNativeLaunchRetries();
    _navigateHomeIfSessionReady();
  }

  void _scheduleNativeLaunchRetries() {
    if (!kIsWeb && defaultTargetPlatform != TargetPlatform.android) return;
    for (final ms in const [400, 1000, 2000]) {
      Future<void>.delayed(Duration(milliseconds: ms), () async {
        await launchNativeApp();
        _navigateHomeIfSessionReady();
      });
    }
  }

  void _navigateHomeIfSessionReady() {
    final nav = navigatorKey.currentState;
    final context = navigatorKey.currentContext;
    if (nav == null || context == null || !context.mounted) return;

    final auth = context.read<AuthProvider>();
    if (auth.user == null) {
      AppLogger.d(
        'bringAppToForeground: sin usuario, solo Activity al frente',
      );
      return;
    }

    final routeName = ModalRoute.of(context)?.settings.name;
    if (routeName == '/home') return;

    nav.pushNamedAndRemoveUntil('/home', (route) => false);
  }
}
