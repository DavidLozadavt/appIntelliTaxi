import 'package:intellitaxi/core/services/reverse_geocoding_service.dart';
import 'package:intellitaxi/features/conductor/utils/conductor_solicitud_payload_helper.dart';
import 'package:intellitaxi/features/conductor/utils/solicitud_display_helper.dart';

/// Completa nombre/dirección/barrio de origen y destino vía geocoding inverso.
class ConductorSolicitudEnrichmentService {
  ConductorSolicitudEnrichmentService({
    ReverseGeocodingService? reverseGeocoding,
  }) : _reverseGeocoding = reverseGeocoding ?? ReverseGeocodingService();

  final ReverseGeocodingService _reverseGeocoding;

  Future<bool> enrich(Map<String, dynamic> solicitud) async {
    var changed = false;

    Future<void> enrichPoint({
      required bool isDestino,
      required double lat,
      required double lng,
    }) async {
      final label = await _reverseGeocoding.resolveCurrentLocationLabel(
        lat: lat,
        lng: lng,
      );

      if (isDestino) {
        if (!ConductorSolicitudPayloadHelper.hasMeaningfulPlaceName(
              solicitud['destino_name']?.toString(),
            ) &&
            label.name.trim().isNotEmpty &&
            !SolicitudDisplayHelper.isPlaceholderDestino(label.name)) {
          solicitud['destino_name'] = label.name;
          changed = true;
        }
        if (!ConductorSolicitudPayloadHelper.hasMeaningfulAddress(
              solicitud['destino_address']?.toString(),
            ) &&
            label.address.trim().isNotEmpty &&
            !SolicitudDisplayHelper.isPlaceholderDestino(label.address)) {
          solicitud['destino_address'] = label.address;
          changed = true;
        }
      } else {
        if (!ConductorSolicitudPayloadHelper.hasMeaningfulPlaceName(
              solicitud['origen_name']?.toString(),
            ) &&
            label.name.trim().isNotEmpty &&
            !SolicitudDisplayHelper.isPlaceholderPickup(label.name)) {
          solicitud['origen_name'] = label.name;
          changed = true;
        }
        if (!ConductorSolicitudPayloadHelper.hasMeaningfulAddress(
              solicitud['origen_address']?.toString(),
            ) &&
            label.address.trim().isNotEmpty &&
            !SolicitudDisplayHelper.isPlaceholderPickup(label.address)) {
          solicitud['origen_address'] = label.address;
          changed = true;
        }
        if ((solicitud['origen_barrio']?.toString().trim().isEmpty ?? true)) {
          final barrio = await _reverseGeocoding.resolveAreaName(
            lat: lat,
            lng: lng,
          );
          if (barrio != null && barrio.isNotEmpty) {
            solicitud['origen_barrio'] =
                SolicitudDisplayHelper.compactBarrio(barrio);
            changed = true;
          }
        }
      }
    }

    final oLat = SolicitudDisplayHelper.parseCoordinate(solicitud['origen_lat']);
    final oLng = SolicitudDisplayHelper.parseCoordinate(solicitud['origen_lng']);
    if (oLat != null && oLng != null) {
      await enrichPoint(isDestino: false, lat: oLat, lng: oLng);
    }

    final dLat = SolicitudDisplayHelper.parseCoordinate(solicitud['destino_lat']);
    final dLng = SolicitudDisplayHelper.parseCoordinate(solicitud['destino_lng']);
    if (dLat != null &&
        dLng != null &&
        (dLat.abs() > 0.0001 || dLng.abs() > 0.0001)) {
      await enrichPoint(isDestino: true, lat: dLat, lng: dLng);
    }

    return changed;
  }
}
