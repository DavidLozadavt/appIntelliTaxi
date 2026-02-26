import 'dart:convert';
import 'package:intellitaxi/config/pusher_config.dart';
import 'package:intellitaxi/core/services/app_logger.dart';

/// Servicio para que el pasajero reciba actualizaciones en tiempo real del servicio
class ServicioPusherService {
  String? _channelName;
  bool _isConnected = false;

  /// Suscribirse al canal del servicio para recibir actualizaciones
  Future<void> suscribirServicio({
    required int servicioId,
    required Function(Map<String, dynamic>) onServicioAceptado,
    required Function(Map<String, dynamic>) onUbicacionActualizada,
    required Function(Map<String, dynamic>) onEstadoCambiado,
  }) async {
    try {
      _channelName = 'servicio.$servicioId';

      AppLogger.d('\n${'=' * 80}');
      AppLogger.d('🔌 PASAJERO: INICIANDO SUSCRIPCIÓN A PUSHER SECONDARY');
      AppLogger.d('=' * 80);
      AppLogger.d('   Canal: $_channelName');
      AppLogger.d('   Eventos esperados:');
      AppLogger.d('     1. servicio.aceptado');
      AppLogger.d('     2. conductor.ubicacion.actualizada');
      AppLogger.d('     3. servicio.estado.cambiado');
      AppLogger.d('   🔸 TRANSPORTE usa SECONDARY, NO PRIMARY');
      AppLogger.d('=' * 80);

      // Registrar handlers en SECONDARY (eventos de transporte vienen por ahí)
      AppLogger.d('📝 Registrando handlers en SECONDARY...');

      PusherService.registerEventHandlerSecondary(
        '$_channelName:servicio.aceptado',
        (event) {
          AppLogger.d('\n⭐ PASAJERO: Evento servicio.aceptado recibido!');
          _handleEvent(event, onServicioAceptado);
        },
      );

      PusherService.registerEventHandlerSecondary(
        '$_channelName:conductor.ubicacion.actualizada',
        (event) {
          AppLogger.d(
            '\n📍 PASAJERO: Evento conductor.ubicacion.actualizada recibido!',
          );
          _handleEvent(event, onUbicacionActualizada);
        },
      );

      PusherService.registerEventHandlerSecondary(
        '$_channelName:servicio.estado.cambiado',
        (event) {
          AppLogger.d(
            '\n🔄 PASAJERO: Evento servicio.estado.cambiado recibido!',
          );
          _handleEvent(event, onEstadoCambiado);
        },
      );

      AppLogger.d('✅ Handlers registrados en SECONDARY');

      // Suscribirse solo al canal SECONDARY (sin bloquear)
      AppLogger.d('🔌 Suscribiendo al canal SECONDARY...');
      PusherService.subscribeSecondary(_channelName!)
          .then((_) {
            AppLogger.d('✅ Canal SECONDARY suscrito exitosamente');
          })
          .catchError((error) {
            AppLogger.d('❌ Error al suscribir SECONDARY: $error');
          });

      _isConnected = true;
      AppLogger.d('\n${'=' * 80}');
      AppLogger.d('✅ PASAJERO: SUSCRIPCIÓN COMPLETADA (SECONDARY)');
      AppLogger.d('=' * 80);
      AppLogger.d('   Esperando eventos en servicio.$servicioId...');
      AppLogger.d('=' * 80 + '\n');
    } catch (e) {
      AppLogger.d('\n❌ Error suscribiendo al canal: $e');
      AppLogger.d('   Stack trace: ${StackTrace.current}');
    }
  }

  /// Procesar eventos de Pusher
  void _handleEvent(dynamic event, Function(Map<String, dynamic>) callback) {
    try {
      Map<String, dynamic> data;

      if (event is String) {
        // Si es String, parsear JSON
        data = jsonDecode(event);
      } else if (event is Map) {
        data = Map<String, dynamic>.from(event);
      } else {
        AppLogger.d('⚠️ Tipo de evento no soportado: ${event.runtimeType}');
        return;
      }

      // Si el evento tiene un campo 'data' anidado, usarlo
      if (data.containsKey('data') && data['data'] is Map) {
        data = Map<String, dynamic>.from(data['data']);
      }

      callback(data);
    } catch (e) {
      AppLogger.d('⚠️ Error procesando evento: $e');
    }
  }

  /// Desuscribirse del canal
  Future<void> desconectar() async {
    if (_channelName != null && _isConnected) {
      try {
        await PusherService.unsubscribe(_channelName!);

        // Desregistrar eventos
        PusherService.unregisterEventHandler('$_channelName:servicio.aceptado');
        PusherService.unregisterEventHandler(
          '$_channelName:conductor.ubicacion.actualizada',
        );
        PusherService.unregisterEventHandler(
          '$_channelName:servicio.estado.cambiado',
        );

        _isConnected = false;
        AppLogger.d('🔌 Desconectado del canal: $_channelName');
      } catch (e) {
        AppLogger.d('⚠️ Error desconectando: $e');
      }
    }
  }

  /// Verificar si está conectado
  bool get isConnected => _isConnected;

  /// Limpiar recursos
  void dispose() {
    desconectar();
  }
}
