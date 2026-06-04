import 'package:intellitaxi/core/services/app_logger.dart';
import 'package:intellitaxi/core/utils/json_payload_helper.dart';
import 'package:intellitaxi/features/chat/data/mensaje_taxi_model.dart';
import 'package:intellitaxi/features/chat/services/chat_taxi_realtime_hub.dart';
import 'package:intellitaxi/features/chat/utils/chat_notification_navigation.dart';

/// Puente FCM → pantalla de chat cuando Pusher no entrega el evento en vivo.
class ChatRealtimeBridge {
  ChatRealtimeBridge._();

  static int? _activeServicioId;
  static void Function(MensajeTaxi)? _onMensaje;

  static void register({
    required int servicioId,
    required void Function(MensajeTaxi) onMensaje,
  }) {
    _activeServicioId = servicioId;
    _onMensaje = onMensaje;
  }

  static void unregister(int servicioId) {
    if (_activeServicioId != servicioId) return;
    _activeServicioId = null;
    _onMensaje = null;
  }

  /// Si hay chat abierto para ese servicio, inyecta el mensaje desde el push.
  static bool tryDeliverFromPush(Map<String, dynamic> data) {
    if (!ChatNotificationNavigation.isChatTaxiNotification(data)) {
      return false;
    }
    final servicioId = ChatNotificationNavigation.parseServicioId(data);
    if (servicioId == null ||
        servicioId <= 0 ||
        servicioId != _activeServicioId ||
        _onMensaje == null) {
      return false;
    }

    try {
      final merged = JsonPayloadHelper.parseAndMerge(data);
      final payload = merged['mensaje'] is Map
          ? Map<String, dynamic>.from(merged['mensaje'] as Map)
          : merged;
      final mensaje = ChatTaxiRealtimeHub.parseMensaje(payload) ??
          MensajeTaxi.fromPusher(payload);
      if (mensaje.mensaje.isEmpty && !mensaje.esImagen) {
        return false;
      }
      _onMensaje!(mensaje);
      AppLogger.d(
        '💬 Chat: mensaje inyectado desde FCM (servicio $servicioId)',
      );
      return true;
    } catch (e) {
      AppLogger.d('💬 Chat: no se pudo parsear FCM para tiempo real: $e');
      return false;
    }
  }
}
