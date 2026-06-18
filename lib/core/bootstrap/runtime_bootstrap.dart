import 'package:intellitaxi/core/diagnostics/app_diagnostics.dart';
import 'package:intellitaxi/core/services/app_foreground_service.dart';
import 'package:intellitaxi/core/services/app_logger.dart';
import 'package:intellitaxi/core/services/background_location_service.dart';
import 'package:intellitaxi/core/services/driver_overlay_service.dart';
import 'package:intellitaxi/core/services/incoming_service_notification_service.dart';
import 'package:intellitaxi/config/socket_service.dart';
import 'package:intellitaxi/features/conductor/providers/conductor_home_provider.dart';
import 'package:intellitaxi/features/rides/services/servicio_notificacion_foreground.dart';
import 'package:intellitaxi/firebase_msg.dart';
import 'package:intellitaxi/main.dart';
import 'package:provider/provider.dart';
import 'dart:async';

/// Servicios pesados tras el primer frame; esperan primer plano si hay diálogos.
class RuntimeBootstrap {
  RuntimeBootstrap._();

  static final Completer<void> _done = Completer<void>();

  /// Termina cuando FCM, permisos y ubicación en background están listos.
  static Future<void> get whenComplete => _done.future;

  static bool get isComplete => _done.isCompleted;

  static Future<void> run() async {
    if (_done.isCompleted) return;

    try {
      await _runInternal();
    } finally {
      if (!_done.isCompleted) {
        _done.complete();
      }
    }
  }

  static Future<void> _runInternal() async {
    await AppDiagnostics.waitForForeground(
      reason: 'permisos / usuario en otra pantalla',
    );

    AppDiagnostics.phase('bootstrap_services_start');

    await _step(
      'incoming_channel',
      () => IncomingServiceNotificationService.instance
          .ensureInitialized()
          .timeout(const Duration(seconds: 15)),
    );

    await _step(
      'fcm',
      () => FirebaseMsg().initFCM().timeout(const Duration(seconds: 60)),
    );

    await _step(
      'socket',
      () => SocketService.initialize().timeout(const Duration(seconds: 60)),
    );

    await _step(
      'notificacion_foreground',
      () => ServicioNotificacionForeground().inicializar().timeout(
        const Duration(seconds: 30),
      ),
    );

    try {
      DriverOverlayService.instance.ensureReturnListener();
      AppDiagnostics.record('bootstrap', 'overlay_listener_ok');
    } catch (e, st) {
      AppLogger.e(
        'No se pudo registrar listener del overlay',
        tag: 'Bootstrap',
        error: e,
        stackTrace: st,
      );
      AppDiagnostics.recordError('overlay_listener', error: e);
    }

    await _step(
      'incoming_permissions',
      () => IncomingServiceNotificationService.instance
          .requestAndroidAlertPermissions()
          .timeout(const Duration(seconds: 30)),
    );

    await AppDiagnostics.waitForForeground(
      reason: 'tras diálogos de notificación / pantalla completa',
    );

    await _step(
      'background_location',
      () => BackgroundLocationService.initialize().timeout(
        const Duration(seconds: 30),
      ),
    );

    await AppDiagnostics.waitForForeground(
      reason: 'tras permisos de ubicación',
    );

    AppDiagnostics.phase('bootstrap_services_done');
    await _syncOverlayIfTurnoActivo();
  }

  static Future<void> _syncOverlayIfTurnoActivo() async {
    try {
      await AppForegroundService.instance.ensureOverlayNativeChannel();
    } catch (_) {}

    final ctx = navigatorKey.currentContext;
    if (ctx == null || !ctx.mounted) return;
    try {
      final home = ctx.read<ConductorHomeProvider>();
      if (home.tieneTurnoActivo && home.isOnline) {
        AppLogger.i(
          '🔵 Bootstrap listo → sync overlay (turno=${home.turnoActivo?.id})',
          tag: 'DriverOverlay',
        );
        home.scheduleOverlaySyncWithRetries(reason: 'bootstrap_done');
      }
    } catch (e) {
      AppLogger.d('⚠️ sync overlay post-bootstrap: $e', tag: 'Bootstrap');
    }
  }

  static Future<void> _step(
    String name,
    Future<void> Function() action,
  ) async {
    AppDiagnostics.record('bootstrap', 'inicio $name');
    try {
      await action();
      AppDiagnostics.record('bootstrap', 'ok $name');
    } catch (e, st) {
      AppLogger.e(
        'Bootstrap falló: $name',
        tag: 'Bootstrap',
        error: e,
        stackTrace: st,
      );
      AppDiagnostics.recordError('bootstrap_$name', error: e, stackTrace: st);
    }
  }
}
