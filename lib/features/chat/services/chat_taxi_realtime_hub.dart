import 'package:intellitaxi/config/socket_service.dart';
import 'package:intellitaxi/core/services/app_logger.dart';
import 'package:intellitaxi/core/utils/json_payload_helper.dart';
import 'package:intellitaxi/features/chat/data/mensaje_taxi_model.dart';
import 'package:intellitaxi/features/taxi/utils/taxi_socket_channels.dart';

/// Suscripción única a `chat.servicio.{id}` (varios listeners: pantalla chat, badge).
class ChatTaxiRealtimeHub {
  ChatTaxiRealtimeHub._();

  static final Map<int, Set<void Function(MensajeTaxi)>> _mensajeListeners = {};
  static final Map<int, Set<void Function(int mensajeId, int leidoPor)>>
      _leidoListeners = {};
  static final Set<int> _serviciosConCanal = {};

  static final RegExp _chatChannelPattern =
      RegExp(r'^chat\.servicio\.(\d+)$');

  static int? servicioIdFromChannel(String channelName) {
    final normalized = _normalizeChannel(channelName);
    final match = _chatChannelPattern.firstMatch(normalized);
    if (match == null) return null;
    return int.tryParse(match.group(1)!);
  }

  static String _normalizeChannel(String channelName) {
    if (channelName.startsWith('private-')) {
      return channelName.substring(8);
    }
    return channelName;
  }

  static MensajeTaxi? parseMensaje(dynamic data) {
    try {
      final merged = JsonPayloadHelper.parseAndMerge(data);
      final payload = merged['mensaje'] is Map
          ? Map<String, dynamic>.from(merged['mensaje'] as Map)
          : merged;
      return MensajeTaxi.fromSocket(payload);
    } catch (e) {
      AppLogger.d('💬 Hub: error parseando mensaje: $e');
      return null;
    }
  }

  static Future<void> ensureSubscribed(int servicioId) async {
    if (servicioId <= 0) return;

    final channelName = TaxiSocketChannels.chatServicio(servicioId);
    _registrarHandlersCanal(channelName, servicioId);
    _serviciosConCanal.add(servicioId);

    await SocketService.forceSubscribeSecondary(channelName);

    AppLogger.d(
      '💬 Hub: canal $channelName (listeners=${_mensajeListeners[servicioId]?.length ?? 0})',
    );
  }

  /// Tras reconectar el socket (Soketi VPS), volver a unirse a los canales activos.
  static Future<void> resubscribeAllChannels() async {
    for (final servicioId in List.of(_serviciosConCanal)) {
      final channelName = TaxiSocketChannels.chatServicio(servicioId);
      _registrarHandlersCanal(channelName, servicioId);
      await SocketService.forceSubscribeSecondary(channelName);
      AppLogger.d('💬 Hub: re-suscrito $channelName');
    }
  }

  /// Enrutado directo desde Pusher (no depende de handler pre-registrado).
  static void dispatchRawEvent({
    required String channelName,
    required String eventName,
    required dynamic data,
  }) {
    final servicioId = servicioIdFromChannel(channelName);
    if (servicioId == null) return;

    if (TaxiSocketEvents.nuevoMensajeAliases.contains(eventName)) {
      dispatchMensaje(servicioId, data);
      return;
    }
    if (TaxiSocketEvents.mensajeLeidoAliases.contains(eventName)) {
      dispatchLeido(servicioId, data);
    }
  }

  static void dispatchMensaje(int servicioId, dynamic data) {
    final mensaje = parseMensaje(data);
    if (mensaje == null) {
      AppLogger.d('💬 Hub: payload mensaje no parseable: $data');
      return;
    }
    final listeners = _mensajeListeners[servicioId];
    if (listeners == null || listeners.isEmpty) {
      AppLogger.d(
        '💬 Hub: mensaje recibido sin listeners (servicio $servicioId)',
      );
      return;
    }
    AppLogger.d('💬 Hub → UI: ${mensaje.textoVista}');
    for (final listener in List.of(listeners)) {
      listener(mensaje);
    }
  }

  static void dispatchLeido(int servicioId, dynamic data) {
    try {
      final merged = JsonPayloadHelper.parseAndMerge(data);
      final mensajeId = _toInt(merged['mensaje_id'] ?? merged['mensajeId']);
      final leidoPor = _toInt(merged['leido_por'] ?? merged['leidoPor']);
      final listeners = _leidoListeners[servicioId];
      if (listeners == null || listeners.isEmpty) return;
      for (final listener in List.of(listeners)) {
        listener(mensajeId, leidoPor);
      }
    } catch (e) {
      AppLogger.d('💬 Hub: error mensaje leído: $e');
    }
  }

  static void _registrarHandlersCanal(String channelName, int servicioId) {
    for (final eventName in TaxiSocketEvents.nuevoMensajeAliases) {
      final key = '$channelName:$eventName';
      SocketService.registerEventHandlerSecondary(
        key,
        (data) => dispatchMensaje(servicioId, data),
      );
    }

    for (final eventName in TaxiSocketEvents.mensajeLeidoAliases) {
      final key = '$channelName:$eventName';
      SocketService.registerEventHandlerSecondary(
        key,
        (data) => dispatchLeido(servicioId, data),
      );
    }
  }

  static void addMensajeListener(
    int servicioId,
    void Function(MensajeTaxi) listener,
  ) {
    _mensajeListeners.putIfAbsent(servicioId, () => {}).add(listener);
  }

  static void removeMensajeListener(
    int servicioId,
    void Function(MensajeTaxi) listener,
  ) {
    _mensajeListeners[servicioId]?.remove(listener);
    _maybeUnsubscribe(servicioId);
  }

  static void addLeidoListener(
    int servicioId,
    void Function(int mensajeId, int leidoPor) listener,
  ) {
    _leidoListeners.putIfAbsent(servicioId, () => {}).add(listener);
  }

  static void removeLeidoListener(
    int servicioId,
    void Function(int mensajeId, int leidoPor) listener,
  ) {
    _leidoListeners[servicioId]?.remove(listener);
    _maybeUnsubscribe(servicioId);
  }

  static void _maybeUnsubscribe(int servicioId) {
    final hayMensaje = (_mensajeListeners[servicioId]?.isNotEmpty ?? false);
    final hayLeido = (_leidoListeners[servicioId]?.isNotEmpty ?? false);
    if (hayMensaje || hayLeido) return;

    _mensajeListeners.remove(servicioId);
    _leidoListeners.remove(servicioId);

    if (!_serviciosConCanal.contains(servicioId)) return;

    final channel = TaxiSocketChannels.chatServicio(servicioId);
    SocketService.unsubscribeSecondary(channel);
    _serviciosConCanal.remove(servicioId);

    for (final eventName in TaxiSocketEvents.nuevoMensajeAliases) {
      SocketService.unregisterEventHandlerSecondary('$channel:$eventName');
    }
    for (final eventName in TaxiSocketEvents.mensajeLeidoAliases) {
      SocketService.unregisterEventHandlerSecondary('$channel:$eventName');
    }

    AppLogger.d('💬 Hub: desuscrito $channel');
  }

  static int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }
}
