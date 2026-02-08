import 'dart:convert';
import 'package:intellitaxi/config/pusher_config.dart';

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

      print('\n' + '=' * 80);
      print('🔌 PASAJERO: INICIANDO SUSCRIPCIÓN A PUSHER SECONDARY');
      print('=' * 80);
      print('   Canal: $_channelName');
      print('   Eventos esperados:');
      print('     1. servicio.aceptado');
      print('     2. conductor.ubicacion.actualizada');
      print('     3. servicio.estado.cambiado');
      print('   🔸 TRANSPORTE usa SECONDARY, NO PRIMARY');
      print('=' * 80);

      // Registrar handlers en SECONDARY (eventos de transporte vienen por ahí)
      print('📝 Registrando handlers en SECONDARY...');

      PusherService.registerEventHandlerSecondary(
        '$_channelName:servicio.aceptado',
        (event) {
          print('\n⭐ PASAJERO: Evento servicio.aceptado recibido!');
          _handleEvent(event, onServicioAceptado);
        },
      );

      PusherService.registerEventHandlerSecondary(
        '$_channelName:conductor.ubicacion.actualizada',
        (event) {
          print(
            '\n📍 PASAJERO: Evento conductor.ubicacion.actualizada recibido!',
          );
          _handleEvent(event, onUbicacionActualizada);
        },
      );

      PusherService.registerEventHandlerSecondary(
        '$_channelName:servicio.estado.cambiado',
        (event) {
          print('\n🔄 PASAJERO: Evento servicio.estado.cambiado recibido!');
          _handleEvent(event, onEstadoCambiado);
        },
      );

      print('✅ Handlers registrados en SECONDARY');

      // Suscribirse solo al canal SECONDARY (sin bloquear)
      print('🔌 Suscribiendo al canal SECONDARY...');
      PusherService.subscribeSecondary(_channelName!)
          .then((_) {
            print('✅ Canal SECONDARY suscrito exitosamente');
          })
          .catchError((error) {
            print('❌ Error al suscribir SECONDARY: $error');
          });

      _isConnected = true;
      print('\n' + '=' * 80);
      print('✅ PASAJERO: SUSCRIPCIÓN COMPLETADA (SECONDARY)');
      print('=' * 80);
      print('   Esperando eventos en servicio.$servicioId...');
      print('=' * 80 + '\n');
    } catch (e) {
      print('\n❌ Error suscribiendo al canal: $e');
      print('   Stack trace: ${StackTrace.current}');
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
        print('⚠️ Tipo de evento no soportado: ${event.runtimeType}');
        return;
      }

      // Si el evento tiene un campo 'data' anidado, usarlo
      if (data.containsKey('data') && data['data'] is Map) {
        data = Map<String, dynamic>.from(data['data']);
      }

      callback(data);
    } catch (e) {
      print('⚠️ Error procesando evento: $e');
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
        print('🔌 Desconectado del canal: $_channelName');
      } catch (e) {
        print('⚠️ Error desconectando: $e');
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
