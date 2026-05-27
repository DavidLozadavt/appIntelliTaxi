import 'package:intellitaxi/core/geo/haversine_helper.dart';
import 'package:intellitaxi/features/conductor/utils/solicitud_display_helper.dart';
import 'package:intellitaxi/features/taxi/data/taxi_radio_accion.dart';

/// Filtra solicitudes Pusher según radio de acción (broadcast global).
class TaxiRadioAccionFilter {
  TaxiRadioAccionFilter._();

  static bool matches(
    Map<String, dynamic> event,
    double? miLat,
    double? miLng,
    TaxiRadioAccion config,
  ) {
    if (config.sinLimite || !config.activo) return true;
    if (miLat == null || miLng == null) return true;

    final normalized = SolicitudDisplayHelper.normalizeSolicitudMap(event);
    final oLat = SolicitudDisplayHelper.parseCoordinate(normalized['origen_lat']);
    final oLng = SolicitudDisplayHelper.parseCoordinate(normalized['origen_lng']);
    if (oLat == null || oLng == null) return false;

    final km = HaversineHelper.distanceKm(miLat, miLng, oLat, oLng);
    return km <= config.radioEfectivoKm;
  }
}
