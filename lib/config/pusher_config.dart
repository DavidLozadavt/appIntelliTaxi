// lib/services/pusher_service.dart
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:pusher_channels_flutter/pusher_channels_flutter.dart';
import 'package:intellitaxi/core/dio_client.dart';
import 'package:intellitaxi/core/perf/runtime_perf_flags.dart';
import 'package:intellitaxi/core/services/app_logger.dart';
import '../config/app_config.dart';
import '../config/pusher_native_init.dart';

class PusherService {
  static PusherChannelsFlutter? _pusherPrimary;
  static PusherChannelsFlutter? _pusherSecondary;
  static bool _secondaryReady = false;
  static final Map<String, Function(dynamic)> _eventHandlers = {};
  static final Map<String, Function(dynamic)> _eventHandlersSecondary = {};
  static final Set<String> _subscribedPrimary = {};
  static final Set<String> _subscribedSecondary = {};
  static final Map<String, Future<void>> _pendingSecondarySubscribe = {};

  /// Evita llamar `subscribe` nativo si Dart ya registró el canal (p. ej. tras hot reload).
  static bool isSecondarySubscribed(String channelName) =>
      _subscribedSecondary.contains(channelName);

  static bool _isAlreadySubscribedError(Object e) {
    final text = e.toString();
    if (text.contains('Already subscribed')) return true;
    if (e is PlatformException) {
      return (e.message?.contains('Already subscribed') ?? false) ||
          (e.details?.toString().contains('Already subscribed') ?? false);
    }
    return false;
  }

  /// Inicializa ambas conexiones de Pusher
  static Future<void> initialize() async {
    final primaryKey = AppConfig.pusherAppKey;
    final secondaryKey = AppConfig.pusherSecondaryAppKey;
    final sameKey =
        primaryKey.isNotEmpty &&
        secondaryKey.isNotEmpty &&
        primaryKey == secondaryKey;

    if (sameKey) {
      AppLogger.d(
        'Pusher: misma API key en primary y secondary — solo conexión secondary',
        tag: 'Pusher',
      );
      if (!_secondaryReady) {
        await _initializeSecondary();
      }
      _pusherPrimary = _pusherSecondary;
      return;
    }

    await _initializePrimary();
    await _initializeSecondary();
  }

  /// Inicializa la conexión principal de Pusher
  static Future<void> _initializePrimary() async {
    final apiKey = AppConfig.pusherAppKey;
    if (apiKey.isEmpty) {
      AppLogger.w('Pusher Primary omitido: sin API key en .env', tag: 'Pusher');
      return;
    }

    _pusherPrimary = PusherChannelsFlutter.getInstance();

    try {
      AppLogger.d('🔧 Inicializando Pusher Primary...');
      AppLogger.d('   App Key: $apiKey');
      if (AppConfig.pusherPrimaryUsesSecondaryFallback) {
        AppLogger.d('   (fallback desde PUSHER_SECONDARY_APP_KEY)');
      }
      AppLogger.d('   Cluster: ${AppConfig.pusherCluster}');

      await _pusherPrimary!.init(
        apiKey: apiKey,
        cluster: AppConfig.pusherCluster,
        onEvent: _onEventPrimary,
        onSubscriptionSucceeded: _onSubscriptionSucceededPrimary,
        onError: _onErrorPrimary,
        onConnectionStateChange: _onConnectionStateChangePrimary,
      );

      if (PusherNativeInit.hasCustomEndpoint) {
        await _applyCustomPusherEndpoint(
          _pusherPrimary!,
          apiKey: AppConfig.pusherAppKey,
          cluster: AppConfig.pusherCluster,
        );
      } else {
        await _pusherPrimary!.connect();
      }
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
    if (_secondaryReady && _pusherSecondary != null) {
      AppLogger.d('Pusher Secondary ya listo, omitiendo re-init', tag: 'Pusher');
      return;
    }
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

      if (PusherNativeInit.hasCustomEndpoint) {
        await _applyCustomPusherEndpoint(
          _pusherSecondary!,
          apiKey: AppConfig.pusherSecondaryAppKey,
          cluster: AppConfig.pusherSecondaryCluster,
          authEndpoint: '${AppConfig.baseUrl}auth/pusher-secondary',
          authorizer: true,
        );
      } else {
        await _pusherSecondary!.connect();
      }
      _secondaryReady = true;
      _ensureDefaultSecondaryHandlers();
      AppLogger.d(
        '✅ Pusher Secondary conectado (Key: ${AppConfig.pusherSecondaryAppKey}'
        '${PusherNativeInit.hasCustomEndpoint ? ", host: ${AppConfig.pusherHost}:${AppConfig.pusherPort}" : ""})',
      );
    } catch (e) {
      _secondaryReady = false;
      AppLogger.d('❌ Error inicializando Pusher Secondary: $e');
    }
  }

  // ========== MÉTODOS PARA CONEXIÓN PRINCIPAL ==========

  static Future<void> subscribe(String channelName) async {
    if (_subscribedPrimary.contains(channelName)) {
      return;
    }
    try {
      AppLogger.d('📡 Intentando suscribirse a: $channelName');
      await _pusherPrimary?.subscribe(channelName: channelName);
      _subscribedPrimary.add(channelName);
      AppLogger.d('✅ Suscrito exitosamente a canal principal: $channelName');
      AppLogger.d('   Handlers registrados: ${_eventHandlers.keys.toList()}');
    } catch (e) {
      AppLogger.d('❌ Error suscribiéndose al canal principal $channelName: $e');
      rethrow;
    }
  }

  static Future<void> unsubscribe(String channelName) async {
    if (!_subscribedPrimary.contains(channelName)) {
      return;
    }
    try {
      await _pusherPrimary?.unsubscribe(channelName: channelName);
      _subscribedPrimary.remove(channelName);
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
    if (_subscribedSecondary.contains(channelName)) {
      return;
    }

    final inFlight = _pendingSecondarySubscribe[channelName];
    if (inFlight != null) {
      await inFlight;
      return;
    }

    final task = _subscribeSecondaryOnce(channelName);
    _pendingSecondarySubscribe[channelName] = task;
    try {
      await task;
    } finally {
      _pendingSecondarySubscribe.remove(channelName);
    }
  }

  static Future<void> _subscribeSecondaryOnce(String channelName) async {
    if (_subscribedSecondary.contains(channelName)) return;

    try {
      await _pusherSecondary?.subscribe(channelName: channelName);
      _subscribedSecondary.add(channelName);
      if (RuntimePerfFlags.verbosePusherLogs) {
        AppLogger.d('Suscrito secondary: $channelName', tag: 'Pusher');
      }
    } catch (e) {
      if (_isAlreadySubscribedError(e)) {
        _subscribedSecondary.add(channelName);
        return;
      }
      AppLogger.d(
        '❌ Error suscribiéndose al canal secundario $channelName: $e',
      );
    }
  }

  /// Re-suscribe aunque Dart crea que ya está unido (p. ej. tras reconectar el socket).
  static Future<void> forceSubscribeSecondary(String channelName) async {
    _subscribedSecondary.remove(channelName);
    _pendingSecondarySubscribe.remove(channelName);

    try {
      await _pusherSecondary?.unsubscribe(channelName: channelName);
    } catch (_) {
      // Tras disconnect el canal puede no existir en el cliente nativo.
    }

    final task = _subscribeSecondaryOnce(channelName);
    _pendingSecondarySubscribe[channelName] = task;
    try {
      await task;
    } finally {
      _pendingSecondarySubscribe.remove(channelName);
    }
  }

  static Future<void> unsubscribeSecondary(String channelName) async {
    if (!_subscribedSecondary.contains(channelName)) {
      return;
    }
    try {
      await _pusherSecondary?.unsubscribe(channelName: channelName);
      _subscribedSecondary.remove(channelName);
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
    if (RuntimePerfFlags.verbosePusherLogs) {
      AppLogger.d('Handler secondary: $eventKey', tag: 'Pusher');
    }
  }

  static void unregisterEventHandlerSecondary(String eventKey) {
    _eventHandlersSecondary.remove(eventKey);
    AppLogger.d('🗑️ Handler eliminado para evento secundario: $eventKey');
  }

  /// Handlers vacíos para no perder eventos entre el init de Pusher y el home.
  static void _ensureDefaultSecondaryHandlers() {
    const keys = [
      'conductores-disponibles:conductor.actualizado',
      'solicitudes-servicio:nueva-solicitud',
      'solicitudes-servicio:nueva_solicitud',
    ];
    for (final key in keys) {
      _eventHandlersSecondary.putIfAbsent(key, () => (_) {});
    }
  }

  static void _onEventSecondary(PusherEvent event) {
    if (event.eventName.startsWith('pusher:')) return;

    final key = '${event.channelName}:${event.eventName}';
    if (kDebugMode && event.channelName.contains('chat.servicio')) {
      AppLogger.d(
        '💬 [SECONDARY] $key handler=${_eventHandlersSecondary.containsKey(key)}',
      );
    }
    final handler = _eventHandlersSecondary[key];
    if (handler == null) {
      if (kDebugMode &&
          (event.channelName.contains('chat.servicio') ||
              event.eventName.toLowerCase().contains('mensaje'))) {
        AppLogger.d(
          '⚠️ [SECONDARY] Chat sin handler: $key (evento=${event.eventName})',
        );
      }
      return;
    }
    handler(event.data);
  }

  /// Re-inicializa el socket nativo con host/puerto del `.env` (Soketi en VPS).
  static Future<void> _applyCustomPusherEndpoint(
    PusherChannelsFlutter pusher, {
    required String apiKey,
    required String cluster,
    String? authEndpoint,
    bool authorizer = false,
  }) async {
    if (!PusherNativeInit.hasCustomEndpoint) return;

    try {
      await pusher.disconnect();
      _subscribedPrimary.clear();
      _subscribedSecondary.clear();
      await pusher.methodChannel.invokeMethod(
        'init',
        PusherNativeInit.customEndpointOverrides(
          apiKey: apiKey,
          cluster: cluster,
          authEndpoint: authEndpoint,
          authorizer: authorizer,
        ),
      );
      await pusher.methodChannel.invokeMethod('connect');
      AppLogger.d(
        '🔌 Pusher Secondary reconfigurado → ${AppConfig.pusherHost}:${AppConfig.pusherPort} '
        '(TLS=${AppConfig.pusherUseTls})',
        tag: 'Pusher',
      );
    } catch (e) {
      AppLogger.d('❌ Pusher custom endpoint: $e', tag: 'Pusher');
    }
  }

  static void _onSubscriptionSucceededSecondary(
    String channelName,
    dynamic data,
  ) {
    if (RuntimePerfFlags.verbosePusherLogs) {
      AppLogger.d('OK secondary: $channelName', tag: 'Pusher');
    }
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
    if (!RuntimePerfFlags.verbosePusherLogs) return;
    AppLogger.d(
      '[SECONDARY] $previousState → $currentState',
      tag: 'Pusher',
    );
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
    _subscribedPrimary.clear();
    _subscribedSecondary.clear();
    AppLogger.d('🔌 Ambas conexiones Pusher desconectadas');
  }
}
