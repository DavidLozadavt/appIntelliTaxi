import 'package:intellitaxi/core/diagnostics/app_diagnostics.dart';
import 'package:intellitaxi/core/services/app_logger.dart';
import 'package:intellitaxi/core/services/background_location_service.dart';
import 'package:intellitaxi/core/services/driver_overlay_service.dart';
import 'package:intellitaxi/core/services/incoming_service_notification_service.dart';
import 'package:intellitaxi/config/pusher_config.dart';
import 'package:intellitaxi/features/rides/services/servicio_notificacion_foreground.dart';
import 'package:intellitaxi/firebase_msg.dart';

/// Servicios pesados tras el primer frame; esperan primer plano si hay diálogos.
class RuntimeBootstrap {
  RuntimeBootstrap._();

  static Future<void> run() async {
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
      'pusher',
      () => PusherService.initialize().timeout(const Duration(seconds: 60)),
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
