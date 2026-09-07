import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intellitaxi/features/conductor/utils/conductor_servicio_estado_helper.dart';
import 'package:intellitaxi/features/conductor/utils/solicitud_display_helper.dart';

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
  /// WhatsApp / sin destino: siempre el punto donde pidieron el servicio.
  static LatLng? resolveDestinoNavegacion({
    required Map<String, dynamic> servicio,
    required String estadoUi,
  }) {
    final n = SolicitudDisplayHelper.normalizeSolicitudMap(servicio);
    final tieneDestino =
        ConductorServicioEstadoHelper.tieneDestinoDefinido(n);

    if (estadoUi == 'llegue' || estadoUi == 'en_curso') {
      if (!tieneDestino) return null;
      return LatLng(
        ConductorServicioEstadoHelper.parseDouble(n['destino_lat']),
        ConductorServicioEstadoHelper.parseDouble(n['destino_lng']),
      );
    }

    final origenLat = SolicitudDisplayHelper.parseCoordinate(n['origen_lat']);
    final origenLng = SolicitudDisplayHelper.parseCoordinate(n['origen_lng']);
    if (origenLat != null &&
        origenLng != null &&
        (origenLat.abs() > 1e-6 || origenLng.abs() > 1e-6)) {
      return LatLng(origenLat, origenLng);
    }

    return null;
  }
}
