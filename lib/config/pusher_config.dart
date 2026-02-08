// lib/services/pusher_service.dart
import 'package:pusher_channels_flutter/pusher_channels_flutter.dart';
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
      print('🔧 Inicializando Pusher Primary...');
      print('   App Key: ${AppConfig.pusherAppKey}');
      print('   Cluster: ${AppConfig.pusherCluster}');

      await _pusherPrimary!.init(
        apiKey: AppConfig.pusherAppKey,
        cluster: AppConfig.pusherCluster,
        onEvent: _onEventPrimary,
        onSubscriptionSucceeded: _onSubscriptionSucceededPrimary,
        onError: _onErrorPrimary,
        onConnectionStateChange: _onConnectionStateChangePrimary,
      );

      await _pusherPrimary!.connect();
      print('✅ Pusher Primary conectado (Key: ${AppConfig.pusherAppKey})');
      print('   Esperando eventos...');
    } catch (e) {
      print('❌ Error inicializando Pusher Primary: $e');
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
        onEvent: _onEventSecondary,
        onSubscriptionSucceeded: _onSubscriptionSucceededSecondary,
        onError: _onErrorSecondary,
        onConnectionStateChange: _onConnectionStateChangeSecondary,
      );

      await _pusherSecondary!.connect();
      print(
        '✅ Pusher Secondary conectado (Key: ${AppConfig.pusherSecondaryAppKey})',
      );
    } catch (e) {
      print('❌ Error inicializando Pusher Secondary: $e');
    }
  }

  // ========== MÉTODOS PARA CONEXIÓN PRINCIPAL ==========

  static Future<void> subscribe(String channelName) async {
    try {
      print('📡 Intentando suscribirse a: $channelName');
      await _pusherPrimary?.subscribe(channelName: channelName);
      print('✅ Suscrito exitosamente a canal principal: $channelName');
      print('   Handlers registrados: ${_eventHandlers.keys.toList()}');
    } catch (e) {
      print('❌ Error suscribiéndose al canal principal $channelName: $e');
      rethrow;
    }
  }

  static Future<void> unsubscribe(String channelName) async {
    try {
      await _pusherPrimary?.unsubscribe(channelName: channelName);
      print('🔕 Desuscrito del canal principal: $channelName');
    } catch (e) {
      print('❌ Error desuscribiéndose del canal principal $channelName: $e');
    }
  }

  static void registerEventHandler(String eventKey, Function(dynamic) handler) {
    _eventHandlers[eventKey] = handler;
    print('📝 Handler registrado para evento principal: $eventKey');
  }

  static void unregisterEventHandler(String eventKey) {
    _eventHandlers.remove(eventKey);
    print('🗑️ Handler eliminado para evento principal: $eventKey');
  }

  static void _onEventPrimary(PusherEvent event) {
    print('\n========================================');
    print('🔵 [PRIMARY] ¡EVENTO PUSHER RECIBIDO!');
    print('========================================');
    print('   Canal: ${event.channelName}');
    print('   Evento: ${event.eventName}');
    print('   Data: ${event.data}');

    final key = '${event.channelName}:${event.eventName}';
    print('   Key buscada: $key');
    print('   Handlers disponibles: ${_eventHandlers.keys.toList()}');

    if (_eventHandlers.containsKey(key)) {
      print('   ✅ Handler encontrado, ejecutando...');
      _eventHandlers[key]!(event.data);
    } else {
      print('   ⚠️ NO hay handler registrado para este evento');
    }
    print('========================================\n');
  }

  static void _onSubscriptionSucceededPrimary(
    String channelName,
    dynamic data,
  ) {
    print('✅ [PRIMARY] Suscripción exitosa a: $channelName');
  }

  static void _onErrorPrimary(String message, int? code, dynamic e) {
    print('❌ [PRIMARY] Error: $message (código: $code)');
  }

  static void _onConnectionStateChangePrimary(
    dynamic currentState,
    dynamic previousState,
  ) {
    print('🔄 [PRIMARY] Estado: $previousState → $currentState');
  }

  // ========== MÉTODOS PARA CONEXIÓN SECUNDARIA ==========

  static Future<void> subscribeSecondary(String channelName) async {
    try {
      await _pusherSecondary?.subscribe(channelName: channelName);
      print('📡 Suscrito a canal secundario: $channelName');
    } catch (e) {
      print('❌ Error suscribiéndose al canal secundario $channelName: $e');
    }
  }

  static Future<void> unsubscribeSecondary(String channelName) async {
    try {
      await _pusherSecondary?.unsubscribe(channelName: channelName);
      print('🔕 Desuscrito del canal secundario: $channelName');
    } catch (e) {
      print('❌ Error desuscribiéndose del canal secundario $channelName: $e');
    }
  }

  static void registerEventHandlerSecondary(
    String eventKey,
    Function(dynamic) handler,
  ) {
    _eventHandlersSecondary[eventKey] = handler;
    print('📝 Handler registrado para evento secundario: $eventKey');
    print(
      '📋 Total handlers secundarios registrados: ${_eventHandlersSecondary.length}',
    );
    print('📋 Lista completa: ${_eventHandlersSecondary.keys.toList()}');
  }

  static void unregisterEventHandlerSecondary(String eventKey) {
    _eventHandlersSecondary.remove(eventKey);
    print('🗑️ Handler eliminado para evento secundario: $eventKey');
  }

  static void _onEventSecondary(PusherEvent event) {
    print(
      '🟢 [SECONDARY] Evento recibido: ${event.eventName} en ${event.channelName}',
    );
    print('📦 [SECONDARY] Data: ${event.data}');

    // Log de todos los handlers registrados para debug
    if (!event.eventName.startsWith('pusher:')) {
      print(
        '🔍 [SECONDARY] Buscando handler para: ${event.channelName}:${event.eventName}',
      );
      print(
        '📝 [SECONDARY] Handlers registrados: ${_eventHandlersSecondary.keys.toList()}',
      );
    }

    final key = '${event.channelName}:${event.eventName}';
    if (_eventHandlersSecondary.containsKey(key)) {
      print('✅ [SECONDARY] Ejecutando handler para: $key');
      _eventHandlersSecondary[key]!(event.data);
    } else if (!event.eventName.startsWith('pusher:')) {
      print('⚠️ [SECONDARY] No hay handler registrado para: $key');
    }
  }

  static void _onSubscriptionSucceededSecondary(
    String channelName,
    dynamic data,
  ) {
    print('✅ [SECONDARY] Suscripción exitosa a: $channelName');
  }

  static void _onErrorSecondary(String message, int? code, dynamic e) {
    print('❌ [SECONDARY] Error: $message (código: $code)');
  }

  static void _onConnectionStateChangeSecondary(
    dynamic currentState,
    dynamic previousState,
  ) {
    print('🔄 [SECONDARY] Estado: $previousState → $currentState');
  }

  // ========== MÉTODOS GENERALES ==========

  static Future<void> disconnect() async {
    await _pusherPrimary?.disconnect();
    await _pusherSecondary?.disconnect();
    print('🔌 Ambas conexiones Pusher desconectadas');
  }
}
