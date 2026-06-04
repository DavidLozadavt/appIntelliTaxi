import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intellitaxi/core/diagnostics/app_diagnostics.dart';
import 'package:intellitaxi/core/services/app_logger.dart';
import 'package:intellitaxi/core/utils/app_lifecycle_helper.dart';
import 'package:intellitaxi/features/auth/providers/auth_provider.dart';
import 'package:intellitaxi/features/conductor/utils/conductor_pending_fcm.dart';
import 'package:intellitaxi/main.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Trae la actividad principal al frente (Android) sin reiniciar la UI en caliente.
class AppForegroundService {
  AppForegroundService._();
  static final AppForegroundService instance = AppForegroundService._();

  static const MethodChannel _channel =
      MethodChannel('com.virtualt.intellitaxi/app');

  static const _pendingNativeLaunchKey = 'pending_native_launch_app';

  DateTime? _lastNativeLaunchAt;
  bool _nativeLaunchInFlight = false;
  bool _nativeRetryScheduled = false;

  /// Solo abre la Activity (válido desde el isolate del overlay).
  Future<void> launchNativeApp({bool force = false}) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;

    final now = DateTime.now();
    if (!force &&
        _lastNativeLaunchAt != null &&
        now.difference(_lastNativeLaunchAt!) <
            const Duration(milliseconds: 1400)) {
      return;
    }
    if (_nativeLaunchInFlight) return;

    _nativeLaunchInFlight = true;
    _lastNativeLaunchAt = now;
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
    } finally {
      _nativeLaunchInFlight = false;
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
    await AppForegroundService.instance.launchNativeApp(force: true);
    await ConductorPendingFcm.ensureLoaded();
    final ctx = navigatorKey.currentContext;
    if (ctx != null && ctx.mounted) {
      await ConductorPendingFcm.flush(ctx);
    }
  }

  /// Abre la app sin resetear la pila de navegación si ya hay sesión activa.
  Future<void> bringAppToForeground() async {
    await launchNativeApp(force: true);
    _navigateHomeIfSessionReady(onlyFromLogin: true);
  }

  /// FCM / solicitud entrante: una apertura suave + un reintento nativo (sin parpadeos).
  Future<void> openAppAggressively() async {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      await markPendingNativeLaunch();
    }
    await launchNativeApp(force: true);
    _scheduleSingleNativeRetry();
  }

  void _scheduleSingleNativeRetry() {
    if (!kIsWeb && defaultTargetPlatform != TargetPlatform.android) return;
    if (_nativeRetryScheduled) return;
    _nativeRetryScheduled = true;
    Future<void>.delayed(const Duration(milliseconds: 900), () async {
      _nativeRetryScheduled = false;
      if (AppLifecycleHelper.isInForeground()) return;
      await launchNativeApp(force: true);
    });
  }

  /// Solo navega en arranque frío post-login; nunca destruye `/home` en caliente.
  void _navigateHomeIfSessionReady({bool onlyFromLogin = false}) {
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

    // App ya en uso (otra pantalla del stack): no resetear navegación.
    if (nav.canPop() || AppLifecycleHelper.isInForeground()) return;

    if (onlyFromLogin && routeName != '/login') return;

    nav.pushNamedAndRemoveUntil('/home', (route) => false);
  }
}
