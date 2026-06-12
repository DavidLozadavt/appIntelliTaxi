import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intellitaxi/core/services/app_logger.dart';
import 'package:intellitaxi/core/services/driver_overlay_service.dart';
import 'package:intellitaxi/core/services/fleet_emergency_alert_service.dart';
import 'package:intellitaxi/core/services/incoming_service_notification_service.dart';
import 'package:intellitaxi/features/conductor/utils/conductor_overlay_badge_store.dart';
import 'package:intellitaxi/features/conductor/utils/conductor_pending_fcm.dart';

/// Limpia alertas locales y colas FCM al cerrar sesión.
class FcmLogoutCleanup {
  FcmLogoutCleanup._();

  static Future<void> run() async {
    try {
      await DriverOverlayService.instance.hide();
      await IncomingServiceNotificationService.instance.dismiss();
      await FleetEmergencyAlertService.instance.dismiss();
      await ConductorPendingFcm.clear();
      await ConductorOverlayBadgeStore.clearPendingFlag();
      await FlutterLocalNotificationsPlugin().cancelAll();
      AppLogger.i('Alertas push locales limpiadas tras cerrar sesión', tag: 'FCM');
    } catch (e) {
      AppLogger.d('⚠️ FcmLogoutCleanup: $e', tag: 'FCM');
    }
  }
}
