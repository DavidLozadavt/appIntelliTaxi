// lib/features/chat/services/chat_taxi_service.dart

import 'dart:io';

import 'package:dio/dio.dart';
import '../data/mensaje_taxi_model.dart';
import '../../../core/dio_client.dart';
import 'package:intellitaxi/core/services/app_logger.dart';
import 'package:intellitaxi/features/chat/services/chat_taxi_realtime_hub.dart';
import 'package:intellitaxi/features/taxi/utils/taxi_socket_channels.dart';

class ChatTaxiService {
  final Dio _dio = DioClient.getInstance();
  int? _listeningServicioId;
  void Function(MensajeTaxi)? _onMensajeCallback;
  void Function(int mensajeId, int leidoPor)? _onLeidoCallback;

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

  /// Subir imagen al chat (multipart)
  Future<MensajeTaxi?> enviarImagen({
    required int servicioId,
    required File imageFile,
    String? caption,
  }) async {
    try {
      final formData = FormData.fromMap({
        'servicio_id': servicioId,
        if (caption != null && caption.trim().isNotEmpty)
          'mensaje': caption.trim(),
        'imagen': await MultipartFile.fromFile(
          imageFile.path,
          filename: imageFile.path.split(Platform.pathSeparator).last,
        ),
      });

      final response = await _dio.post(
        '/chat-taxi/enviar-imagen',
        data: formData,
      );

      if (response.statusCode == 201 && response.data['success'] == true) {
        final data = response.data['data'];
        final payload = data is Map<String, dynamic>
            ? data
            : Map<String, dynamic>.from(data as Map);
        return MensajeTaxi.fromJson(payload);
      }

      AppLogger.d('Error enviando imagen: ${response.data['message']}');
      return null;
    } on DioException catch (e) {
      AppLogger.d('DioException imagen: ${e.message}');
      if (e.response != null) {
        AppLogger.d('Response data: ${e.response?.data}');
      }
      rethrow;
    } catch (e) {
      AppLogger.d('Error enviando imagen: $e');
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
  // WebSocket — ChatTaxiRealtimeHub (socket VPS)
  // ============================================

  /// Suscribe al canal del servicio (socket VPS) y registra callbacks.
  Future<void> suscribirseAlChat({
    required int servicioId,
    required Function(MensajeTaxi) onNuevoMensaje,
    Function(int mensajeId, int leidoPor)? onMensajeLeido,
  }) async {
    try {
      await desuscribirse(servicioId, quitarCanal: false);

      _listeningServicioId = servicioId;
      _onMensajeCallback = (m) {
        AppLogger.d('📨 Chat socket: ${m.textoVista}');
        onNuevoMensaje(m);
      };
      ChatTaxiRealtimeHub.addMensajeListener(servicioId, _onMensajeCallback!);

      if (onMensajeLeido != null) {
        _onLeidoCallback = onMensajeLeido;
        ChatTaxiRealtimeHub.addLeidoListener(servicioId, _onLeidoCallback!);
      }

      await ChatTaxiRealtimeHub.ensureSubscribed(servicioId);

      AppLogger.d(
        '✅ Chat Taxi: socket en ${TaxiSocketChannels.chatServicio(servicioId)}',
      );
    } catch (e) {
      AppLogger.d('❌ Error suscribiéndose al chat socket: $e');
    }
  }

  /// Mantener el canal activo durante el viaje (badge / mapa).
  Future<void> mantenerCanalActivo(int servicioId) async {
    if (servicioId <= 0) return;
    await ChatTaxiRealtimeHub.ensureSubscribed(servicioId);
  }

  /// Quita los listeners de esta pantalla (el canal sigue si el badge u otro listener activo).
  Future<void> desuscribirse(
    int servicioId, {
    bool quitarCanal = true,
  }) async {
    try {
      if (_onMensajeCallback != null) {
        ChatTaxiRealtimeHub.removeMensajeListener(
          servicioId,
          _onMensajeCallback!,
        );
        _onMensajeCallback = null;
      }
      if (_onLeidoCallback != null) {
        ChatTaxiRealtimeHub.removeLeidoListener(servicioId, _onLeidoCallback!);
        _onLeidoCallback = null;
      }
      _listeningServicioId = null;
    } catch (e) {
      AppLogger.d('Error desuscribiendo chat: $e');
    }
  }

  /// Dispose (no cerramos el Dio porque es singleton compartido)
  void dispose() {
    // No cerrar _dio porque es una instancia compartida
  }
}
