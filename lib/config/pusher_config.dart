// lib/services/pusher_service.dart
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:pusher_channels_flutter/pusher_channels_flutter.dart';
import 'package:intellitaxi/core/services/app_logger.dart';
import 'package:intellitaxi/core/dio_client.dart';
import '../config/app_config.dart';

class PusherService {
  static PusherChannelsFlutter? _pusherPrimary;
  static PusherChannelsFlutter? _pusherSecondary;
  static final Map<String, Function(dynamic)> _eventHandlers = {};
  static final Map<String, Function(dynamic)> _eventHandlersSecondary = {};

  /// Inicializa ambas conexiones de Pusher
  static Future<void> initialize() async {
    await _initializePrimary();
    await _initializeSecondary();
  }

  /// Inicializa la conexión principal de Pusher
  static Future<void> _initializePrimary() async {
    _pusherPrimary = PusherChannelsFlutter.getInstance();

    try {
      AppLogger.d('🔧 Inicializando Pusher Primary...');
      AppLogger.d('   App Key: ${AppConfig.pusherAppKey}');
      AppLogger.d('   Cluster: ${AppConfig.pusherCluster}');

      await _pusherPrimary!.init(
        apiKey: AppConfig.pusherAppKey,
        cluster: AppConfig.pusherCluster,
        onEvent: _onEventPrimary,
        onSubscriptionSucceeded: _onSubscriptionSucceededPrimary,
        onError: _onErrorPrimary,
        onConnectionStateChange: _onConnectionStateChangePrimary,
      );

      await _pusherPrimary!.connect();
      AppLogger.d(
        '✅ Pusher Primary conectado (Key: ${AppConfig.pusherAppKey})',
      );
      AppLogger.d('   Esperando eventos...');
    } catch (e) {
      AppLogger.d('❌ Error inicializando Pusher Primary: $e');
    }
  }

  /// Inicializa la conexión secundaria de Pusher
  static Future<void> _initializeSecondary() async {
    try {
      // Crear segunda instancia de Pusher
      _pusherSecondary = PusherChannelsFlutter.getInstance();

      await _pusherSecondary!.init(
        apiKey: AppConfig.pusherSecondaryAppKey,
        cluster: AppConfig.pusherSecondaryCluster,
        authEndpoint: '${AppConfig.baseUrl}auth/pusher-secondary',
        onAuthorizer: _onAuthorizerSecondary,
        onEvent: _onEventSecondary,
        onSubscriptionSucceeded: _onSubscriptionSucceededSecondary,
        onSubscriptionError: _onSubscriptionErrorSecondary,
        onError: _onErrorSecondary,
        onConnectionStateChange: _onConnectionStateChangeSecondary,
      );

      await _pusherSecondary!.connect();
      AppLogger.d(
        '✅ Pusher Secondary conectado (Key: ${AppConfig.pusherSecondaryAppKey})',
      );
    } catch (e) {
      AppLogger.d('❌ Error inicializando Pusher Secondary: $e');
    }
  }

  // ========== MÉTODOS PARA CONEXIÓN PRINCIPAL ==========

  static Future<void> subscribe(String channelName) async {
    try {
      AppLogger.d('📡 Intentando suscribirse a: $channelName');
      await _pusherPrimary?.subscribe(channelName: channelName);
      AppLogger.d('✅ Suscrito exitosamente a canal principal: $channelName');
      AppLogger.d('   Handlers registrados: ${_eventHandlers.keys.toList()}');
    } catch (e) {
      AppLogger.d('❌ Error suscribiéndose al canal principal $channelName: $e');
      rethrow;
    }
  }

  static Future<void> unsubscribe(String channelName) async {
    try {
      await _pusherPrimary?.unsubscribe(channelName: channelName);
      AppLogger.d('🔕 Desuscrito del canal principal: $channelName');
    } catch (e) {
      AppLogger.d(
        '❌ Error desuscribiéndose del canal principal $channelName: $e',
      );
    }
  }

  static void registerEventHandler(String eventKey, Function(dynamic) handler) {
    _eventHandlers[eventKey] = handler;
    AppLogger.d('📝 Handler registrado para evento principal: $eventKey');
  }

  static void unregisterEventHandler(String eventKey) {
    _eventHandlers.remove(eventKey);
    AppLogger.d('🗑️ Handler eliminado para evento principal: $eventKey');
  }

  static void _onEventPrimary(PusherEvent event) {
    AppLogger.d('\n========================================');
    AppLogger.d('🔵 [PRIMARY] ¡EVENTO PUSHER RECIBIDO!');
    AppLogger.d('========================================');
    AppLogger.d('   Canal: ${event.channelName}');
    AppLogger.d('   Evento: ${event.eventName}');
    AppLogger.d('   Data: ${event.data}');

    final key = '${event.channelName}:${event.eventName}';
    AppLogger.d('   Key buscada: $key');
    AppLogger.d('   Handlers disponibles: ${_eventHandlers.keys.toList()}');

    if (_eventHandlers.containsKey(key)) {
      AppLogger.d('   ✅ Handler encontrado, ejecutando...');
      _eventHandlers[key]!(event.data);
    } else {
      AppLogger.d('   ⚠️ NO hay handler registrado para este evento');
    }
    AppLogger.d('========================================\n');
  }

  static void _onSubscriptionSucceededPrimary(
    String channelName,
    dynamic data,
  ) {
    AppLogger.d('✅ [PRIMARY] Suscripción exitosa a: $channelName');
  }

  static void _onErrorPrimary(String message, int? code, dynamic e) {
    AppLogger.d('❌ [PRIMARY] Error: $message (código: $code)');
  }

  static void _onConnectionStateChangePrimary(
    dynamic currentState,
    dynamic previousState,
  ) {
    AppLogger.d('🔄 [PRIMARY] Estado: $previousState → $currentState');
  }

  // ========== MÉTODOS PARA CONEXIÓN SECUNDARIA ==========

  static Future<void> subscribeSecondary(String channelName) async {
    try {
      await _pusherSecondary?.subscribe(channelName: channelName);
      AppLogger.d('📡 Suscrito a canal secundario: $channelName');
    } catch (e) {
      AppLogger.d(
        '❌ Error suscribiéndose al canal secundario $channelName: $e',
      );
    }
  }

  static Future<void> unsubscribeSecondary(String channelName) async {
    try {
      await _pusherSecondary?.unsubscribe(channelName: channelName);
      AppLogger.d('🔕 Desuscrito del canal secundario: $channelName');
    } catch (e) {
      AppLogger.d(
        '❌ Error desuscribiéndose del canal secundario $channelName: $e',
      );
    }
  }

  static void registerEventHandlerSecondary(
    String eventKey,
    Function(dynamic) handler,
  ) {
    _eventHandlersSecondary[eventKey] = handler;
    AppLogger.d('📝 Handler registrado para evento secundario: $eventKey');
    AppLogger.d(
      '📋 Total handlers secundarios registrados: ${_eventHandlersSecondary.length}',
    );
    AppLogger.d('📋 Lista completa: ${_eventHandlersSecondary.keys.toList()}');
  }

  static void unregisterEventHandlerSecondary(String eventKey) {
    _eventHandlersSecondary.remove(eventKey);
    AppLogger.d('🗑️ Handler eliminado para evento secundario: $eventKey');
  }

  static void _onEventSecondary(PusherEvent event) {
    AppLogger.d(
      '🟢 [SECONDARY] Evento recibido: ${event.eventName} en ${event.channelName}',
    );
    AppLogger.d('📦 [SECONDARY] Data: ${event.data}');

    // Log de todos los handlers registrados para debug
    if (!event.eventName.startsWith('pusher:')) {
      AppLogger.d(
        '🔍 [SECONDARY] Buscando handler para: ${event.channelName}:${event.eventName}',
      );
      AppLogger.d(
        '📝 [SECONDARY] Handlers registrados: ${_eventHandlersSecondary.keys.toList()}',
      );
    }

    final key = '${event.channelName}:${event.eventName}';
    if (_eventHandlersSecondary.containsKey(key)) {
      AppLogger.d('✅ [SECONDARY] Ejecutando handler para: $key');
      _eventHandlersSecondary[key]!(event.data);
    } else if (!event.eventName.startsWith('pusher:')) {
      AppLogger.d('⚠️ [SECONDARY] No hay handler registrado para: $key');
    }
  }

  static void _onSubscriptionSucceededSecondary(
    String channelName,
    dynamic data,
  ) {
    AppLogger.d('✅ [SECONDARY] Suscripción exitosa a: $channelName');
  }

  static void _onErrorSecondary(String message, int? code, dynamic e) {
    AppLogger.d('❌ [SECONDARY] Error: $message (código: $code)');
  }

  static void _onSubscriptionErrorSecondary(String message, dynamic e) {
    AppLogger.d('❌ [SECONDARY] Error de suscripción: $message | details=$e');
  }

  static void _onConnectionStateChangeSecondary(
    dynamic currentState,
    dynamic previousState,
  ) {
    AppLogger.d('🔄 [SECONDARY] Estado: $previousState → $currentState');
  }

  static Future<dynamic> _onAuthorizerSecondary(
    String channelName,
    String socketId,
    dynamic options,
  ) async {
    try {
      AppLogger.d(
        '🔐 [SECONDARY] Auth private channel: channel=$channelName socket=$socketId',
      );

      final dio = DioClient.getInstance();
      Response response;
      try {
        response = await dio.post(
          'auth/pusher-secondary',
          data: FormData.fromMap({
            'channel_name': channelName,
            'socket_id': socketId,
          }),
          options: Options(
            headers: {'Content-Type': 'application/x-www-form-urlencoded'},
          ),
        );
      } on DioException catch (e) {
        AppLogger.d(
          '⚠️ [SECONDARY] auth/pusher-secondary falló (${e.response?.statusCode}), probando auth/pusher',
        );
        response = await dio.post(
          'auth/pusher',
          data: FormData.fromMap({
            'channel_name': channelName,
            'socket_id': socketId,
          }),
          options: Options(
            headers: {'Content-Type': 'application/x-www-form-urlencoded'},
          ),
        );
      }

      AppLogger.d(
        '✅ [SECONDARY] Auth response ${response.statusCode}: ${response.data}',
      );

      if (response.data is String) {
        return jsonDecode(response.data);
      }
      return response.data;
    } catch (e) {
      AppLogger.d('❌ [SECONDARY] Error auth private channel $channelName: $e');
      return {};
    }
  }

  // ========== MÉTODOS GENERALES ==========

  static Future<void> disconnect() async {
    await _pusherPrimary?.disconnect();
    await _pusherSecondary?.disconnect();
    AppLogger.d('🔌 Ambas conexiones Pusher desconectadas');
  }
}
