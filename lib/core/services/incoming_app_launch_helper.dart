import 'package:intellitaxi/core/perf/runtime_perf_flags.dart';
import 'package:intellitaxi/core/services/app_foreground_service.dart';
import 'package:intellitaxi/core/services/app_logger.dart';
import 'package:intellitaxi/core/services/incoming_service_notification_service.dart';
import 'package:intellitaxi/core/utils/app_lifecycle_helper.dart';
import 'package:intellitaxi/core/utils/device_screen_helper.dart';
import 'package:intellitaxi/core/utils/fcm_isolate_context.dart';
import 'package:intellitaxi/features/conductor/utils/conductor_solicitud_payload_helper.dart';
import 'package:intellitaxi/features/conductor/utils/solicitud_display_helper.dart';

/// Apertura automática al recibir solicitud (misma lógica exclusiva + cola Llegando).
abstract final class IncomingAppLaunchHelper {
  /// Igual que oferta exclusiva: app no visible al usuario (segundo plano o pantalla apagada).
  static Future<bool> shouldAutoOpen() async {
    if (!RuntimePerfFlags.autoOpenAppOnIncomingService) return false;
    if (!AppLifecycleHelper.isInForeground()) return true;
    return AppLifecycleHelper.shouldShowIncomingServiceAlert();
  }

  static Future<void> openForIncoming({
    Map<String, dynamic>? data,
    Map<String, dynamic>? solicitud,
    bool showHeadsUp = true,
    bool skipNativeWake = false,
  }) async {
    if (!await shouldAutoOpen()) return;

    AppLogger.d('🚕 Abriendo IntelliTaxi (solicitud entrante)');

    if (!skipNativeWake && !FcmIsolateContext.isBackgroundHandler) {
      await DeviceScreenHelper.wakeForIncomingService();
    }

    Map<String, dynamic>? map = solicitud;
    if (map == null && data != null && data.isNotEmpty) {
      map = SolicitudDisplayHelper.normalizeSolicitudMap(
        ConductorSolicitudPayloadHelper.normalizarSolicitud(
          ConductorSolicitudPayloadHelper.parsePayload(data),
        ),
      );
    }

    if (showHeadsUp && map != null) {
      await IncomingServiceNotificationService.instance.showIncomingService(
        map,
        skipNativeWake: skipNativeWake || FcmIsolateContext.isBackgroundHandler,
      );
    }

    // Con app cerrada el isolate FCM no tiene MethodChannel; el receiver nativo abre MainActivity.
    if (FcmIsolateContext.isBackgroundHandler) return;

    await AppForegroundService.instance.openAppAggressively();
  }
}
