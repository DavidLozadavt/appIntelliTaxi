// lib/features/chat/services/chat_taxi_service.dart

import 'dart:convert';
import 'package:dio/dio.dart';
import '../data/mensaje_taxi_model.dart';
import '../../../config/pusher_config.dart';
import '../../../core/dio_client.dart';
import 'package:intellitaxi/core/services/app_logger.dart';

class ChatTaxiService {
  final Dio _dio = DioClient.getInstance();
  String? _currentChannel;

  // ============================================
  // MÉTODOS HTTP
  // ============================================

  /// Enviar un mensaje
  Future<MensajeTaxi?> enviarMensaje({
    required int servicioId,
    required String mensaje,
    String tipo = 'texto',
  }) async {
    try {
      final response = await _dio.post(
        '/chat-taxi/enviar',
        data: {'servicio_id': servicioId, 'mensaje': mensaje, 'tipo': tipo},
      );

      if (response.statusCode == 201 && response.data['success'] == true) {
        final data = response.data['data'];
        final payload = data is Map<String, dynamic>
            ? data
            : Map<String, dynamic>.from(data as Map);
        return MensajeTaxi.fromJson(payload);
      }

      AppLogger.d('Error enviando mensaje: ${response.data['message']}');
      return null;
    } on DioException catch (e) {
      AppLogger.d('DioException: ${e.message}');
      if (e.response != null) {
        AppLogger.d('Response data: ${e.response?.data}');
      }
      return null;
    } catch (e) {
      AppLogger.d('Error: $e');
      return null;
    }
  }

  /// Obtener mensajes del chat
  Future<List<MensajeTaxi>> obtenerMensajes(int servicioId) async {
    try {
      final response = await _dio.get('/chat-taxi/mensajes/$servicioId');

      if (response.statusCode == 200 && response.data['success'] == true) {
        return (response.data['data'] as List)
            .map((m) => MensajeTaxi.fromJson(Map<String, dynamic>.from(m)))
            .toList();
      }

      return [];
    } on DioException catch (e) {
      AppLogger.d('DioException: ${e.message}');
      return [];
    } catch (e) {
      AppLogger.d('Error: $e');
      return [];
    }
  }

  /// Marcar mensajes como leídos
  Future<bool> marcarComoLeido(int servicioId, {int? mensajeId}) async {
    try {
      final data = {'servicio_id': servicioId};
      if (mensajeId != null) {
        data['mensaje_id'] = mensajeId;
      }

      final response = await _dio.post('/chat-taxi/marcar-leido', data: data);

      return response.data['success'] == true;
    } on DioException catch (e) {
      AppLogger.d('DioException: ${e.message}');
      return false;
    } catch (e) {
      AppLogger.d('Error: $e');
      return false;
    }
  }

  /// Obtener cantidad de no leídos
  Future<int> obtenerNoLeidos(int servicioId) async {
    try {
      final response = await _dio.get('/chat-taxi/no-leidos/$servicioId');

      if (response.statusCode == 200 && response.data['success'] == true) {
        return response.data['no_leidos'] ?? 0;
      }

      return 0;
    } on DioException catch (e) {
      AppLogger.d('DioException: ${e.message}');
      return 0;
    } catch (e) {
      AppLogger.d('Error: $e');
      return 0;
    }
  }

  /// Obtener información del chat
  Future<Map<String, dynamic>?> obtenerInfoChat(int servicioId) async {
    try {
      final response = await _dio.get('/chat-taxi/info/$servicioId');

      if (response.statusCode == 200 && response.data['success'] == true) {
        return response.data['data'];
      }

      return null;
    } on DioException catch (e) {
      AppLogger.d('DioException: ${e.message}');
      if (e.response != null) {
        AppLogger.d('Response data: ${e.response?.data}');
      }
      return null;
    } catch (e) {
      AppLogger.d('Error: $e');
      return null;
    }
  }

  // ============================================
  // PUSHER - TIEMPO REAL (usando PusherService global)
  // ============================================

  /// Suscribirse al canal del chat usando el Pusher secundario
  Future<void> suscribirseAlChat({
    required int servicioId,
    required Function(MensajeTaxi) onNuevoMensaje,
    Function(int mensajeId, int leidoPor)? onMensajeLeido,
  }) async {
    try {
      final channelName = 'chat.servicio.$servicioId';
      _currentChannel = channelName;

      // Registrar handler para nuevos mensajes
      final keyNuevoMensaje = '$channelName:nuevo.mensaje';
      PusherService.registerEventHandlerSecondary(keyNuevoMensaje, (data) {
        try {
          final decoded = data is String ? jsonDecode(data) : data;
          final jsonData = decoded is Map<String, dynamic>
              ? decoded
              : Map<String, dynamic>.from(decoded as Map);
          final mensaje = MensajeTaxi.fromPusher(jsonData);
          onNuevoMensaje(mensaje);
        } catch (e, st) {
          AppLogger.d('Error parseando mensaje: $e');
          AppLogger.d('Payload tipo: ${data.runtimeType}');
          AppLogger.d('Payload valor: $data');
          AppLogger.d('Stack: $st');
        }
      });

      // Registrar handler para mensajes leídos
      if (onMensajeLeido != null) {
        final keyMensajeLeido = '$channelName:mensaje.leido';
        PusherService.registerEventHandlerSecondary(keyMensajeLeido, (data) {
          try {
            final decoded = data is String ? jsonDecode(data) : data;
            final jsonData = decoded is Map<String, dynamic>
                ? decoded
                : Map<String, dynamic>.from(decoded as Map);
            onMensajeLeido(
              _toInt(jsonData['mensaje_id']),
              _toInt(jsonData['leido_por']),
            );
          } catch (e) {
            AppLogger.d('Error parseando mensaje leído: $e');
          }
        });
      }

      // Suscribirse al canal usando PusherService secundario
      await PusherService.subscribeSecondary(channelName);

      AppLogger.d('✅ Chat Taxi: Suscrito al canal $channelName');
    } catch (e) {
      AppLogger.d('❌ Error suscribiéndose al canal: $e');
    }
  }

  /// Desuscribirse del canal
  Future<void> desuscribirse(int servicioId) async {
    try {
      if (_currentChannel != null) {
        // Desregistrar handlers
        final keyNuevoMensaje = '$_currentChannel:nuevo.mensaje';
        final keyMensajeLeido = '$_currentChannel:mensaje.leido';

        PusherService.unregisterEventHandlerSecondary(keyNuevoMensaje);
        PusherService.unregisterEventHandlerSecondary(keyMensajeLeido);

        // Desuscribirse del canal
        await PusherService.unsubscribeSecondary(_currentChannel!);

        AppLogger.d('❌ Chat Taxi: Desuscrito del canal $_currentChannel');
        _currentChannel = null;
      }
    } catch (e) {
      AppLogger.d('Error desuscribiendo: $e');
    }
  }

  /// Dispose (no cerramos el Dio porque es singleton compartido)
  void dispose() {
    // No cerrar _dio porque es una instancia compartida
  }
}

int _toInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}
