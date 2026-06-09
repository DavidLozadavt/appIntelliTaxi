import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:pusher_channels_flutter/pusher_channels_flutter.dart';
import 'package:intellitaxi/core/dio_client.dart';
import 'package:intellitaxi/core/perf/runtime_perf_flags.dart';
import 'package:intellitaxi/core/services/app_logger.dart';
import '../config/app_config.dart';
import '../config/socket_native_init.dart';

/// Cliente WebSocket taxi (protocolo Pusher-compatible vía Soketi en VPS).
class SocketService {
  static PusherChannelsFlutter? _clientPrimary;
  static PusherChannelsFlutter? _clientSecondary;
  static bool _secondaryReady = false;
  static bool _isConnected = false;
  static bool _isDisconnecting = false;
  static bool _reconfiguringEndpoint = false;
  static Future<void>? _initFuture;
  static Completer<void>? _connectedCompleter;
  static bool _hasConnectedOnce = false;
  static bool _wasDisconnected = true;
  static final List<VoidCallback> _reconnectListeners = [];
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

  /// Inicializa la conexión WebSocket al VPS.
  static Future<void> initialize() {
    _initFuture ??= _doInitialize();
    return _initFuture!;
  }

  static Future<void> _ensureReady() async {
    if (_secondaryReady) return;
    await initialize();
  }

  static Future<void> _doInitialize() async {
    final apiKey = AppConfig.socketAppKey;
    if (apiKey.isEmpty) {
      AppLogger.w('Socket omitido: sin SOCKET_APP_KEY en .env', tag: 'Socket');
      return;
    }

    if (_secondaryReady && _clientSecondary != null) {
      _clientPrimary = _clientSecondary;
      return;
    }

    await _initializeSecondary();
    _clientPrimary = _clientSecondary;
  }

  static Future<void> _initializeSecondary() async {
    try {
      _clientSecondary = PusherChannelsFlutter.getInstance();

      await _clientSecondary!.init(
        apiKey: AppConfig.socketAppKeySecondary,
        cluster: AppConfig.socketCluster,
        authEndpoint: '${AppConfig.baseUrl}auth/pusher',
        onAuthorizer: _onAuthorizerSecondary,
        onEvent: _onEventSecondary,
        onSubscriptionSucceeded: _onSubscriptionSucceededSecondary,
        onSubscriptionError: _onSubscriptionErrorSecondary,
        onError: _onErrorSecondary,
        onConnectionStateChange: _onConnectionStateChangeSecondary,
      );

      if (SocketNativeInit.hasCustomEndpoint) {
        await _applyCustomEndpoint(
          _clientSecondary!,
          apiKey: AppConfig.socketAppKeySecondary,
          cluster: AppConfig.socketCluster,
          authEndpoint: '${AppConfig.baseUrl}auth/pusher',
          authorizer: true,
          isFirstSetup: true,
        );
      } else {
        await _clientSecondary!.connect();
        await _waitForConnected(fallbackAfterConnect: true);
      }

      _secondaryReady = true;
      _ensureDefaultSecondaryHandlers();
      AppLogger.d(
        '✅ Socket conectado (Key: ${AppConfig.socketAppKeySecondary}'
        '${SocketNativeInit.hasCustomEndpoint ? ", host: ${AppConfig.socketHost}:${AppConfig.socketPort}" : ""})',
        tag: 'Socket',
      );
    } catch (e) {
      _secondaryReady = false;
      _initFuture = null;
      AppLogger.d('❌ Error inicializando Socket: $e', tag: 'Socket');
      rethrow;
    }
  }

  static Future<void> subscribe(String channelName) async {
    if (_subscribedPrimary.contains(channelName)) {
      return;
    }
    try {
      AppLogger.d('📡 Intentando suscribirse a: $channelName');
      await _clientPrimary?.subscribe(channelName: channelName);
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
      await _clientPrimary?.unsubscribe(channelName: channelName);
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

    await _ensureReady();
    await _waitForConnected();

    for (var attempt = 0; attempt < 4; attempt++) {
      if (_isDisconnecting || _reconfiguringEndpoint) {
        await _waitForConnected();
      }

      try {
        await _clientSecondary?.subscribe(channelName: channelName);
        _subscribedSecondary.add(channelName);
        if (RuntimePerfFlags.verboseSocketLogs) {
          AppLogger.d('Suscrito: $channelName', tag: 'Socket');
        }
        return;
      } catch (e) {
        if (_isAlreadySubscribedError(e)) {
          _subscribedSecondary.add(channelName);
          return;
        }
        if (_isDisconnectingError(e) && attempt < 3) {
          await Future<void>.delayed(
            Duration(milliseconds: 250 * (attempt + 1)),
          );
          await _waitForConnected();
          continue;
        }
        AppLogger.d(
          '❌ Error suscribiéndose al canal $channelName: $e',
        );
        return;
      }
    }
  }

  static Future<void> forceSubscribeSecondary(String channelName) async {
    _subscribedSecondary.remove(channelName);
    _pendingSecondarySubscribe.remove(channelName);

    try {
      await _clientSecondary?.unsubscribe(channelName: channelName);
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
      await _clientSecondary?.unsubscribe(channelName: channelName);
      _subscribedSecondary.remove(channelName);
      AppLogger.d('🔕 Desuscrito del canal: $channelName');
    } catch (e) {
      AppLogger.d(
        '❌ Error desuscribiéndose del canal $channelName: $e',
      );
    }
  }

  static void registerEventHandlerSecondary(
    String eventKey,
    Function(dynamic) handler,
  ) {
    _eventHandlersSecondary[eventKey] = handler;
    if (RuntimePerfFlags.verboseSocketLogs) {
      AppLogger.d('Handler: $eventKey', tag: 'Socket');
    }
  }

  static void unregisterEventHandlerSecondary(String eventKey) {
    _eventHandlersSecondary.remove(eventKey);
    AppLogger.d('🗑️ Handler eliminado para evento: $eventKey');
  }

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
        '💬 [SOCKET] $key handler=${_eventHandlersSecondary.containsKey(key)}',
      );
    }
    final handler = _eventHandlersSecondary[key];
    if (handler == null) {
      if (kDebugMode &&
          (event.channelName.contains('chat.servicio') ||
              event.eventName.toLowerCase().contains('mensaje'))) {
        AppLogger.d(
          '⚠️ [SOCKET] Chat sin handler: $key (evento=${event.eventName})',
        );
      }
      return;
    }
    handler(event.data);
  }

  static Future<void> _applyCustomEndpoint(
    PusherChannelsFlutter client, {
    required String apiKey,
    required String cluster,
    String? authEndpoint,
    bool authorizer = false,
    bool isFirstSetup = false,
  }) async {
    if (!SocketNativeInit.hasCustomEndpoint) return;

    _reconfiguringEndpoint = true;
    try {
      if (!isFirstSetup && (_isConnected || _isDisconnecting)) {
        await client.disconnect();
        _subscribedPrimary.clear();
        _subscribedSecondary.clear();
        await Future<void>.delayed(const Duration(milliseconds: 350));
      }

      await client.methodChannel.invokeMethod(
        'init',
        SocketNativeInit.customEndpointOverrides(
          apiKey: apiKey,
          cluster: cluster,
          authEndpoint: authEndpoint,
          authorizer: authorizer,
        ),
      );
      await client.methodChannel.invokeMethod('connect');
      await _waitForConnected(fallbackAfterConnect: true);
      AppLogger.d(
        '🔌 Socket reconfigurado → ${AppConfig.socketHost}:${AppConfig.socketPort} '
        '(TLS=${AppConfig.socketUseTls})',
        tag: 'Socket',
      );
    } catch (e) {
      AppLogger.d('❌ Socket custom endpoint: $e', tag: 'Socket');
      rethrow;
    } finally {
      _reconfiguringEndpoint = false;
    }
  }

  static Future<void> _waitForConnected({
    Duration timeout = const Duration(seconds: 15),
    bool fallbackAfterConnect = false,
  }) async {
    if (_isConnected && !_isDisconnecting && !_reconfiguringEndpoint) {
      return;
    }

    _connectedCompleter ??= Completer<void>();
    try {
      await _connectedCompleter!.future.timeout(timeout);
    } on TimeoutException {
      if (!_isConnected && fallbackAfterConnect) {
        await Future<void>.delayed(const Duration(milliseconds: 400));
        _markConnected();
      } else if (!_isConnected) {
        AppLogger.w(
          'Socket: timeout esperando CONNECTED (${timeout.inSeconds}s)',
          tag: 'Socket',
        );
      }
    } finally {
      if (_connectedCompleter?.isCompleted ?? true) {
        _connectedCompleter = null;
      }
    }
  }

  static bool _isDisconnectingError(Object e) {
    final text = e.toString().toUpperCase();
    return text.contains('DISCONNECTING');
  }

  static void _markConnected() {
    _isConnected = true;
    _isDisconnecting = false;
    final pending = _connectedCompleter;
    if (pending != null && !pending.isCompleted) {
      pending.complete();
    }
  }

  static void _markDisconnected({bool disconnecting = false}) {
    _isConnected = false;
    _isDisconnecting = disconnecting;
    if (!disconnecting) {
      _connectedCompleter = null;
    }
  }

  static void _onSubscriptionSucceededSecondary(
    String channelName,
    dynamic data,
  ) {
    if (RuntimePerfFlags.verboseSocketLogs) {
      AppLogger.d('OK: $channelName', tag: 'Socket');
    }
  }

  static void _onErrorSecondary(String message, int? code, dynamic e) {
    if (_reconfiguringEndpoint &&
        message.toUpperCase().contains('DISCONNECTING')) {
      return;
    }
    AppLogger.d('❌ [SOCKET] Error: $message (código: $code)');
  }

  static void _onSubscriptionErrorSecondary(String message, dynamic e) {
    AppLogger.d('❌ [SOCKET] Error de suscripción: $message | details=$e');
  }

  static void addReconnectListener(VoidCallback listener) {
    if (!_reconnectListeners.contains(listener)) {
      _reconnectListeners.add(listener);
    }
  }

  static void removeReconnectListener(VoidCallback listener) {
    _reconnectListeners.remove(listener);
  }

  static void _notifyReconnectListeners() {
    for (final listener in List<VoidCallback>.from(_reconnectListeners)) {
      listener();
    }
  }

  static void _onConnectionStateChangeSecondary(
    dynamic currentState,
    dynamic previousState,
  ) {
    final state = currentState.toString().toUpperCase();
    if (state.contains('CONNECTED') && !state.contains('DISCONNECTED')) {
      if (_hasConnectedOnce && _wasDisconnected) {
        _notifyReconnectListeners();
      }
      _hasConnectedOnce = true;
      _wasDisconnected = false;
      _markConnected();
    } else if (state.contains('DISCONNECTING')) {
      _markDisconnected(disconnecting: true);
    } else if (state.contains('DISCONNECTED')) {
      _wasDisconnected = true;
      _markDisconnected();
    }

    if (!RuntimePerfFlags.verboseSocketLogs) return;
    AppLogger.d(
      '[SOCKET] $previousState → $currentState',
      tag: 'Socket',
    );
  }

  static Future<dynamic> _onAuthorizerSecondary(
    String channelName,
    String socketId,
    dynamic options,
  ) async {
    try {
      AppLogger.d(
        '🔐 [SOCKET] Auth private channel: channel=$channelName socket=$socketId',
      );

      final dio = DioClient.getInstance();
      Response response;
      try {
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
      } on DioException catch (e) {
        AppLogger.d(
          '⚠️ [SOCKET] auth/pusher falló (${e.response?.statusCode}), probando auth/pusher',
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
        '✅ [SOCKET] Auth response ${response.statusCode}: ${response.data}',
      );

      if (response.data is String) {
        return jsonDecode(response.data);
      }
      return response.data;
    } catch (e) {
      AppLogger.d('❌ [SOCKET] Error auth private channel $channelName: $e');
      return {};
    }
  }

  static Future<void> disconnect() async {
    await _clientPrimary?.disconnect();
    await _clientSecondary?.disconnect();
    _subscribedPrimary.clear();
    _subscribedSecondary.clear();
    _secondaryReady = false;
    _initFuture = null;
    _markDisconnected();
    AppLogger.d('🔌 Socket desconectado', tag: 'Socket');
  }
}
