import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intellitaxi/features/conductor/utils/conductor_servicio_estado_helper.dart';

/// Actualiza el payload local del servicio tras un cambio de estado UI.
class ConductorServicioStateTransitions {
  ConductorServicioStateTransitions._();

  static void applyIdEstadoForUi(
    Map<String, dynamic> servicio,
    String estadoUi,
  ) {
    switch (estadoUi) {
      case 'llegue':
        servicio['idEstado'] = 20;
        break;
      case 'en_camino':
        servicio['idEstado'] = 19;
        break;
      case 'en_curso':
        servicio['idEstado'] = 21;
        break;
      case 'finalizado':
        servicio['idEstado'] = 22;
        servicio['estado'] = 'finalizado';
        break;
      case 'cancelado':
        servicio['idEstado'] = 6;
        servicio['estado'] = 'cancelado';
        break;
    }
  }

  static void applyDestinoFinalOnMap({
    required Map<String, dynamic> servicio,
    required double lat,
    required double lng,
    String? address,
  }) {
    servicio['destino_lat'] = lat;
    servicio['destino_lng'] = lng;
    if (address != null && address.trim().isNotEmpty) {
      servicio['destino_address'] = address;
    }
  }

  /// Destino de navegación según el estado del viaje.
  static LatLng? resolveDestinoNavegacion({
    required Map<String, dynamic> servicio,
    required String estadoUi,
  }) {
    final tieneDestino =
        ConductorServicioEstadoHelper.tieneDestinoDefinido(servicio);

    if ((estadoUi == 'llegue' || estadoUi == 'en_curso') && tieneDestino) {
      return LatLng(
        ConductorServicioEstadoHelper.parseDouble(servicio['destino_lat']),
        ConductorServicioEstadoHelper.parseDouble(servicio['destino_lng']),
      );
    }

    if (estadoUi == 'en_camino' || estadoUi == 'aceptado') {
      final oLa =
          ConductorServicioEstadoHelper.parseDouble(servicio['origen_lat']);
      final oLng =
          ConductorServicioEstadoHelper.parseDouble(servicio['origen_lng']);
      if (oLa != 0 && oLng != 0) return LatLng(oLa, oLng);
    }

    return null;
  }
}
