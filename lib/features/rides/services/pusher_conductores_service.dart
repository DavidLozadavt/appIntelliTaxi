import 'dart:convert';
import 'package:intellitaxi/config/pusher_config.dart';
import 'package:intellitaxi/features/rides/data/conductor_model.dart';

class PusherConductoresService {
  final int idEmpresa;
  Function(Conductor)? onDriverUpdate;
  Function(int conductorId)? onDriverOffline;
  bool _isConnected = false;

  PusherConductoresService({required this.idEmpresa});

  // Canal genérico de conductores disponibles
  String get channelName => 'conductores-disponibles';

  Future<void> connect() async {
    if (_isConnected) {
      print('⚠️ Ya está conectado al canal de conductores');
      return;
    }

    try {
      print('📡 Conectando al canal: $channelName');

      // Suscribirse al canal usando la conexión secundaria
      await PusherService.subscribeSecondary(channelName);

      // Registrar handler para el evento conductor.actualizado
      PusherService.registerEventHandlerSecondary(
        '$channelName:conductor.actualizado',
        _handleDriverUpdate,
      );

      _isConnected = true;
      print('✅ Conectado al canal de conductores');
      print('   Escuchando evento: conductor.actualizado');
    } catch (e) {
      print('❌ Error conectando a canal de conductores: $e');
    }
  }

  void _handleDriverUpdate(dynamic data) {
    try {
      print('📍 Evento conductor.actualizado recibido');

      Map<String, dynamic> eventData;

      if (data is String) {
        eventData = jsonDecode(data);
      } else if (data is Map) {
        eventData = Map<String, dynamic>.from(data);
      } else {
        print('⚠️ Tipo de datos no soportado: ${data.runtimeType}');
        return;
      }

      // El evento puede venir con estructura anidada
      final driverData = eventData['data'] ?? eventData;

      // Verificar si el conductor se desconectó
      final estado = driverData['estado'] as String?;
      if (estado == 'desconectado') {
        final conductorId = driverData['conductor_id'] as int;
        print('🔴 Conductor desconectado: $conductorId');

        if (onDriverOffline != null) {
          onDriverOffline!(conductorId);
        }
        return;
      }

      final conductor = Conductor.fromJson(driverData);

      print('   🚗 Conductor: ${conductor.nombre}');
      print('   📍 Ubicación: (${conductor.lat}, ${conductor.lng})');
      print('   ⭐ Calificación: ${conductor.calificacion}');
      print('   📊 Estado: ${conductor.estado}');

      // Llamar callback si está definido
      if (onDriverUpdate != null) {
        onDriverUpdate!(conductor);
      }
    } catch (e, stackTrace) {
      print('❌ Error procesando actualización de conductor: $e');
      print('📍 Stack trace: $stackTrace');
    }
  }

  Future<void> disconnect() async {
    if (!_isConnected) return;

    try {
      print('🔌 Desconectando del canal de conductores');

      // Desuscribirse del canal
      await PusherService.unsubscribeSecondary(channelName);

      // Eliminar handler
      PusherService.unregisterEventHandlerSecondary(
        '$channelName:conductor.actualizado',
      );

      _isConnected = false;
      print('✅ Desconectado del canal de conductores');
    } catch (e) {
      print('❌ Error desconectando del canal: $e');
    }
  }

  bool get isConnected => _isConnected;
}
