import 'package:intellitaxi/config/pusher_config.dart';
import 'package:intellitaxi/core/services/app_logger.dart';
import 'package:intellitaxi/core/utils/json_payload_helper.dart';
import 'package:intellitaxi/features/conductor/utils/conductor_servicio_estado_helper.dart';
import 'package:intellitaxi/features/taxi/utils/taxi_pusher_channels.dart';

/// Resultado de un evento `servicio.estado.cambiado` en Pusher.
class ConductorServicioEstadoPusherEvent {
  const ConductorServicioEstadoPusherEvent({
    this.estadoUi,
    this.estadoId,
    this.estadoNombre,
    this.cancelado = false,
    this.finalizado = false,
  });

  final String? estadoUi;
  final int? estadoId;
  final String? estadoNombre;
  final bool cancelado;
  final bool finalizado;
}

/// Suscripción y parseo de eventos de estado del servicio activo.
class ConductorServicioPusherController {
  final List<String> _eventKeys = [];

  Future<void> subscribe({
    required int servicioId,
    required void Function(ConductorServicioEstadoPusherEvent event) onEstado,
  }) async {
    final channelName = TaxiPusherChannels.servicio(servicioId);

    void onRawEvent(dynamic event, String eventName) {
      final parsed = parseEstadoEvent(event);
      if (parsed == null) return;
      AppLogger.d(
        '🔄 Conductor servicio.$servicioId ← $eventName '
        '(ui=${parsed.estadoUi}, id=${parsed.estadoId}, cancel=${parsed.cancelado})',
      );
      onEstado(parsed);
    }

    for (final eventName in const [
      TaxiPusherEvents.servicioEstadoCambiado,
      'servicio.estado.cambiado',
      'ServicioEstadoCambiado',
      'servicio_estado_cambiado',
    ]) {
      final key = '$channelName:$eventName';
      _eventKeys.add(key);
      PusherService.registerEventHandlerSecondary(key, (event) {
        onRawEvent(event, eventName);
      });
    }

    await PusherService.subscribeSecondary(channelName);
  }

  void unsubscribe(int servicioId) {
    for (final key in _eventKeys) {
      PusherService.unregisterEventHandlerSecondary(key);
    }
    _eventKeys.clear();
    PusherService.unsubscribeSecondary(TaxiPusherChannels.servicio(servicioId));
  }

  static ConductorServicioEstadoPusherEvent? parseEstadoEvent(dynamic event) {
    try {
      final data = JsonPayloadHelper.parseAndMerge(event);

      final estadoNombre = data['estado'] is Map
          ? (data['estado'] as Map)['estado']?.toString() ??
              (data['estado'] as Map)['nombre']?.toString()
          : data['estado']?.toString();
      final estadoIdRaw = data['estado_id'] ??
          data['idEstado'] ??
          data['id_estado'] ??
          (data['estado'] is Map
              ? (data['estado'] as Map)['id'] ?? (data['estado'] as Map)['idEstado']
              : null);
      final estadoId = estadoIdRaw is int
          ? estadoIdRaw
          : int.tryParse(estadoIdRaw?.toString() ?? '');

      final estadoUi = ConductorServicioEstadoHelper.normalizarEstadoBackend(
            estadoNombre,
          ) ??
          ConductorServicioEstadoHelper.estadoDesdeId(estadoId);

      final cancelado = estadoUi == 'cancelado' || estadoId == 6;
      final finalizado = estadoUi == 'finalizado' || estadoId == 22;

      return ConductorServicioEstadoPusherEvent(
        estadoUi: estadoUi,
        estadoId: estadoId,
        estadoNombre: estadoNombre,
        cancelado: cancelado,
        finalizado: finalizado,
      );
    } catch (_) {
      return null;
    }
  }
}
