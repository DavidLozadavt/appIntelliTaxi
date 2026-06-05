import 'dart:async' show unawaited;
import 'dart:convert';
import 'package:intellitaxi/config/socket_service.dart';
import 'package:intellitaxi/core/services/app_logger.dart';
import 'package:intellitaxi/core/services/incoming_service_notification_service.dart';

/// Servicio para que el pasajero reciba actualizaciones en tiempo real del servicio.
class ServicioSocketService {
  String? _channelName;
  bool _isConnected = false;

  Future<void> suscribirServicio({
    required int servicioId,
    required Function(Map<String, dynamic>) onServicioAceptado,
    required Function(Map<String, dynamic>) onUbicacionActualizada,
    required Function(Map<String, dynamic>) onEstadoCambiado,
  }) async {
    try {
      _channelName = 'servicio.$servicioId';

      AppLogger.d('\n${'=' * 80}');
      AppLogger.d('🔌 PASAJERO: INICIANDO SUSCRIPCIÓN A SOCKET');
      AppLogger.d('=' * 80);
      AppLogger.d('   Canal: $_channelName');
      AppLogger.d('   Eventos esperados:');
      AppLogger.d('     1. servicio.aceptado');
      AppLogger.d('     2. conductor.ubicacion.actualizada');
      AppLogger.d('     3. servicio.estado.cambiado');
      AppLogger.d('=' * 80);

      AppLogger.d('📝 Registrando handlers...');

      SocketService.registerEventHandlerSecondary(
        '$_channelName:servicio.aceptado',
        (event) {
          AppLogger.d('\n⭐ PASAJERO: Evento servicio.aceptado recibido!');
          _handleEvent(event, onServicioAceptado);
        },
      );

      SocketService.registerEventHandlerSecondary(
        '$_channelName:conductor.ubicacion.actualizada',
        (event) {
          AppLogger.d(
            '\n📍 PASAJERO: Evento conductor.ubicacion.actualizada recibido!',
          );
          _handleEvent(event, onUbicacionActualizada);
        },
      );

      SocketService.registerEventHandlerSecondary(
        '$_channelName:servicio.estado.cambiado',
        (event) {
          AppLogger.d(
            '\n🔄 PASAJERO: Evento servicio.estado.cambiado recibido!',
          );
          unawaited(IncomingServiceNotificationService.instance.dismiss());
          _handleEvent(event, onEstadoCambiado);
        },
      );

      AppLogger.d('✅ Handlers registrados');

      AppLogger.d('🔌 Suscribiendo al canal...');
      await SocketService.subscribeSecondary(_channelName!);
      AppLogger.d('✅ Canal suscrito exitosamente');

      _isConnected = true;
      AppLogger.d('\n${'=' * 80}');
      AppLogger.d('✅ PASAJERO: SUSCRIPCIÓN COMPLETADA');
      AppLogger.d('=' * 80);
      AppLogger.d('   Esperando eventos en servicio.$servicioId...');
      AppLogger.d('=' * 80 + '\n');
    } catch (e) {
      AppLogger.d('\n❌ Error suscribiendo al canal: $e');
      AppLogger.d('   Stack trace: ${StackTrace.current}');
    }
  }

  void _handleEvent(dynamic event, Function(Map<String, dynamic>) callback) {
    try {
      Map<String, dynamic> data;

      if (event is String) {
        data = jsonDecode(event);
      } else if (event is Map) {
        data = Map<String, dynamic>.from(event);
      } else {
        AppLogger.d('⚠️ Tipo de evento no soportado: ${event.runtimeType}');
        return;
      }

      if (data.containsKey('data') && data['data'] is Map) {
        data = Map<String, dynamic>.from(data['data']);
      }

      callback(data);
    } catch (e) {
      AppLogger.d('⚠️ Error procesando evento: $e');
    }
  }

  Future<void> desconectar() async {
    if (_channelName != null && _isConnected) {
      try {
        await SocketService.unsubscribeSecondary(_channelName!);

        SocketService.unregisterEventHandlerSecondary(
          '$_channelName:servicio.aceptado',
        );
        SocketService.unregisterEventHandlerSecondary(
          '$_channelName:conductor.ubicacion.actualizada',
        );
        SocketService.unregisterEventHandlerSecondary(
          '$_channelName:servicio.estado.cambiado',
        );

        _isConnected = false;
        AppLogger.d('🔌 Desconectado del canal: $_channelName');
      } catch (e) {
        AppLogger.d('⚠️ Error desconectando: $e');
      }
    }
  }

  bool get isConnected => _isConnected;

  void dispose() {
    desconectar();
  }
}
