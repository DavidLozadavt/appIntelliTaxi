// lib/services/pusher_service.dart
import 'package:pusher_channels_flutter/pusher_channels_flutter.dart';
import '../config/app_config.dart';

class PusherService {
  static PusherChannelsFlutter? _pusher;
  static final Map<String, Function(dynamic)> _eventHandlers = {};

  static Future<void> initialize() async {
    _pusher = PusherChannelsFlutter.getInstance();

    try {
      await _pusher!.init(
        apiKey: AppConfig.pusherAppKey,
        cluster: AppConfig.pusherCluster,
        onEvent: _onEvent,
        onSubscriptionSucceeded: _onSubscriptionSucceeded,
        onError: _onError,
        onConnectionStateChange: _onConnectionStateChange,
      );

      await _pusher!.connect();
    } catch (e) {
      print('Error inicializando Pusher: $e');
    }
  }

  static Future<void> subscribe(String channelName) async {
    try {
      await _pusher?.subscribe(channelName: channelName);
    } catch (e) {
      print('Error suscribiéndose al canal $channelName: $e');
    }
  }

  static Future<void> unsubscribe(String channelName) async {
    try {
      await _pusher?.unsubscribe(channelName: channelName);
    } catch (e) {
      print('Error desuscribiéndose del canal $channelName: $e');
    }
  }

  static void registerEventHandler(String eventKey, Function(dynamic) handler) {
    _eventHandlers[eventKey] = handler;
  }

  static void unregisterEventHandler(String eventKey) {
    _eventHandlers.remove(eventKey);
  }

  static void _onEvent(PusherEvent event) {
    print('Pusher evento recibido: ${event.eventName} en ${event.channelName}');
    
    // Llamar handlers registrados
    final key = '${event.channelName}:${event.eventName}';
    if (_eventHandlers.containsKey(key)) {
      _eventHandlers[key]!(event.data);
    }
  }

  static void _onSubscriptionSucceeded(String channelName, dynamic data) {
    print('Suscripción exitosa a: $channelName');
  }

  static void _onError(String message, int? code, dynamic e) {
    print('Pusher error: $message (código: $code)');
  }

  static void _onConnectionStateChange(dynamic currentState, dynamic previousState) {
    print('Estado de conexión cambió de $previousState a $currentState');
  }

  static Future<void> disconnect() async {
    await _pusher?.disconnect();
  }
}