import 'dart:convert';
import 'package:intellitaxi/config/pusher_config.dart';
import 'package:intellitaxi/features/conductor/data/conductor_model.dart';
import 'package:intellitaxi/core/services/app_logger.dart';

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
      AppLogger.d('⚠️ Ya está conectado al canal de conductores');
      return;
    }

    try {
      AppLogger.d('📡 Conectando al canal: $channelName');

      // Suscribirse al canal usando la conexión secundaria
      await PusherService.subscribeSecondary(channelName);

      // Registrar handler para el evento conductor.actualizado
      PusherService.registerEventHandlerSecondary(
        '$channelName:conductor.actualizado',
        _handleDriverUpdate,
      );

      _isConnected = true;
      AppLogger.d('✅ Conectado al canal de conductores');
      AppLogger.d('   Escuchando evento: conductor.actualizado');
    } catch (e) {
      AppLogger.d('❌ Error conectando a canal de conductores: $e');
    }
  }

  void _handleDriverUpdate(dynamic data) {
    try {
      AppLogger.d('📍 Evento conductor.actualizado recibido');

      Map<String, dynamic> eventData;

      if (data is String) {
        eventData = jsonDecode(data);
      } else if (data is Map) {
        eventData = Map<String, dynamic>.from(data);
      } else {
        AppLogger.d('⚠️ Tipo de datos no soportado: ${data.runtimeType}');
        return;
      }

      // El evento puede venir con estructura anidada
      final driverData = eventData['data'] ?? eventData;

      // Verificar si el conductor se desconectó o está en descanso
      final estado = driverData['estado']?.toString().toLowerCase();
      final visibleEnMapa = driverData['visible_en_mapa'] != false;
      final modoDescanso =
          driverData['modo_descanso'] == true ||
          driverData['en_descanso'] == true ||
          estado == 'descanso';

      if (estado == 'desconectado' ||
          modoDescanso ||
          visibleEnMapa == false) {
        final conductorId = _asInt(
          driverData['conductor_id'] ?? driverData['id'],
        );
        AppLogger.d(
          '🔴 Conductor oculto del mapa: $conductorId ($estado)',
        );
        if (conductorId != null) {
          onDriverOffline?.call(conductorId);
        }
        return;
      }

      final conductor = Conductor.fromJson(driverData);

      AppLogger.d('   🚗 Conductor: ${conductor.nombre}');
      AppLogger.d('   📍 Ubicación: (${conductor.lat}, ${conductor.lng})');
      AppLogger.d('   ⭐ Calificación: ${conductor.calificacion}');
      AppLogger.d('   📊 Estado: ${conductor.estado}');

      // Llamar callback si está definido
      if (onDriverUpdate != null) {
        onDriverUpdate!(conductor);
      }
    } catch (e, stackTrace) {
      AppLogger.d('❌ Error procesando actualización de conductor: $e');
      AppLogger.d('📍 Stack trace: $stackTrace');
    }
  }

  Future<void> disconnect() async {
    if (!_isConnected) return;

    try {
      AppLogger.d('🔌 Desconectando del canal de conductores');

      // Desuscribirse del canal
      await PusherService.unsubscribeSecondary(channelName);

      // Eliminar handler
      PusherService.unregisterEventHandlerSecondary(
        '$channelName:conductor.actualizado',
      );

      _isConnected = false;
      AppLogger.d('✅ Desconectado del canal de conductores');
    } catch (e) {
      AppLogger.d('❌ Error desconectando del canal: $e');
    }
  }

  bool get isConnected => _isConnected;
}

int? _asInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}
