import 'package:intellitaxi/config/pusher_config.dart';
import 'package:intellitaxi/core/utils/json_payload_helper.dart';
import 'package:intellitaxi/features/conductor/utils/conductor_servicio_estado_helper.dart';

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
  String? _eventKey;

  String? get eventKey => _eventKey;

  Future<void> subscribe({
    required int servicioId,
    required void Function(ConductorServicioEstadoPusherEvent event) onEstado,
  }) async {
    final channelName = 'servicio.$servicioId';
    final eventKey = '$channelName:servicio.estado.cambiado';
    _eventKey = eventKey;

    PusherService.registerEventHandlerSecondary(eventKey, (event) {
      final parsed = parseEstadoEvent(event);
      if (parsed != null) onEstado(parsed);
    });

    await PusherService.subscribeSecondary(channelName);
  }

  void unsubscribe(int servicioId) {
    final eventKey = _eventKey;
    if (eventKey != null) {
      PusherService.unregisterEventHandlerSecondary(eventKey);
      _eventKey = null;
    }
    PusherService.unsubscribeSecondary('servicio.$servicioId');
  }

  static ConductorServicioEstadoPusherEvent? parseEstadoEvent(dynamic event) {
    try {
      final data = JsonPayloadHelper.parseAndMerge(event);

      final estadoNombre = data['estado']?.toString();
      final estadoIdRaw = data['estado_id'];
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
