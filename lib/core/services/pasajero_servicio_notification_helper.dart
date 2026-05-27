import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intellitaxi/core/services/incoming_service_notification_service.dart';
import 'package:intellitaxi/features/rides/services/servicio_notificacion_foreground.dart';

/// Limpia alertas locales al entrar o terminar la búsqueda de conductor (pasajero).
class PasajeroServicioNotificationHelper {
  PasajeroServicioNotificationHelper._();

  static const int _fcmTripNotificationBase = 920000;

  /// Id estable para reemplazar / cancelar notificaciones FCM del mismo viaje.
  static int fcmNotificationIdForServicio(int servicioId) =>
      _fcmTripNotificationBase + (servicioId.abs() % 100000);

  static Future<void> clearForServicio(int servicioId) async {
    await IncomingServiceNotificationService.instance.dismiss();
    await ServicioNotificacionForeground().cancelarNotificacion(
      servicioId,
      tipo: 'pasajero',
    );
    final plugin = FlutterLocalNotificationsPlugin();
    await plugin.cancel(id: fcmNotificationIdForServicio(servicioId));
  }
}
