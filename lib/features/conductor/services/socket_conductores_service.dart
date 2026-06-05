import 'dart:convert';
import 'package:intellitaxi/config/socket_service.dart';
import 'package:intellitaxi/features/conductor/data/conductor_model.dart';
import 'package:intellitaxi/core/perf/runtime_perf_flags.dart';
import 'package:intellitaxi/core/services/app_logger.dart';

class SocketConductoresService {
  final int idEmpresa;
  Function(Conductor)? onDriverUpdate;
  Function(int conductorId)? onDriverOffline;
  bool _isConnected = false;

  SocketConductoresService({required this.idEmpresa});

  String get channelName => 'conductores-disponibles';

  Future<void> connect() async {
    if (_isConnected) {
      AppLogger.d('⚠️ Ya está conectado al canal de conductores');
      return;
    }

    try {
      if (RuntimePerfFlags.verboseSocketLogs) {
        AppLogger.d('Conectando canal: $channelName', tag: 'Socket');
      }

      await SocketService.subscribeSecondary(channelName);

      SocketService.registerEventHandlerSecondary(
        '$channelName:conductor.actualizado',
        _handleDriverUpdate,
      );

      _isConnected = true;
      AppLogger.d('✅ Socket conductores en $channelName', tag: 'Socket');
    } catch (e) {
      AppLogger.d('❌ Error conectando a canal de conductores: $e');
    }
  }

  static DateTime? _lastVerboseLogAt;
  static int _updateCount = 0;

  void _handleDriverUpdate(dynamic data) {
    try {
      _updateCount++;
      final now = DateTime.now();
      final verbose = _lastVerboseLogAt == null ||
          now.difference(_lastVerboseLogAt!) > const Duration(seconds: 8);
      if (verbose) {
        _lastVerboseLogAt = now;
        AppLogger.d('📍 conductor.actualizado (#$_updateCount)');
      }

      Map<String, dynamic> eventData;

      if (data is String) {
        eventData = jsonDecode(data);
      } else if (data is Map) {
        eventData = Map<String, dynamic>.from(data);
      } else {
        AppLogger.d('⚠️ Tipo de datos no soportado: ${data.runtimeType}');
        return;
      }

      final driverData = eventData['data'] ?? eventData;

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

      if (verbose) {
        AppLogger.d(
          '   🚗 ${conductor.nombre} (${conductor.lat}, ${conductor.lng}) '
          '${conductor.estado}',
        );
      }

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

      await SocketService.unsubscribeSecondary(channelName);

      SocketService.unregisterEventHandlerSecondary(
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
