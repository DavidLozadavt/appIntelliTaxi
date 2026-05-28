import 'package:intellitaxi/core/services/reverse_geocoding_service.dart';
import 'package:intellitaxi/features/conductor/utils/conductor_solicitud_payload_helper.dart';
import 'package:intellitaxi/features/conductor/utils/solicitud_display_helper.dart';

/// Completa nombre/dirección/barrio de origen y destino vía geocoding inverso.
class ConductorSolicitudEnrichmentService {
  ConductorSolicitudEnrichmentService({
    ReverseGeocodingService? reverseGeocoding,
  }) : _reverseGeocoding = reverseGeocoding ?? ReverseGeocodingService();

  final ReverseGeocodingService _reverseGeocoding;

  Future<bool> enrich(
    Map<String, dynamic> solicitud, {
    bool forzarBarrio = false,
  }) async {
    var changed = false;

    Future<void> enrichPoint({
      required bool isDestino,
      required double lat,
      required double lng,
    }) async {
      final label = isDestino
          ? await _reverseGeocoding.resolveCurrentLocationLabel(
              lat: lat,
              lng: lng,
            )
          : await _reverseGeocoding.resolveDriverPickupLabel(
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
        final driverTitle = label.driverTitle;
        final driverSub = label.driverSubtitle;
        if (!ConductorSolicitudPayloadHelper.hasMeaningfulPlaceName(
              solicitud['origen_name']?.toString(),
            ) &&
            driverTitle.isNotEmpty &&
            !SolicitudDisplayHelper.isPlaceholderPickup(driverTitle)) {
          solicitud['origen_name'] = driverTitle;
          changed = true;
        } else if (SolicitudDisplayHelper.looksLikeStreetAddress(
              solicitud['origen_name']?.toString() ?? '',
            ) ==
            false &&
            label.streetLine != null &&
            label.streetLine!.trim().isNotEmpty) {
          solicitud['origen_name'] = label.streetLine!.trim();
          changed = true;
        }
        if (!ConductorSolicitudPayloadHelper.hasMeaningfulAddress(
              solicitud['origen_address']?.toString(),
            ) &&
            label.address.trim().isNotEmpty &&
            !SolicitudDisplayHelper.isPlaceholderPickup(label.address)) {
          solicitud['origen_address'] = label.address;
          changed = true;
        } else if (driverSub.isNotEmpty &&
            (solicitud['origen_address']?.toString().trim().isEmpty ?? true)) {
          solicitud['origen_address'] = driverSub;
          changed = true;
        }
        final sinBarrio =
            solicitud['origen_barrio']?.toString().trim().isEmpty ?? true;
        if (forzarBarrio || sinBarrio) {
          final barrio = await _reverseGeocoding.resolveAreaName(
            lat: lat,
            lng: lng,
          );
          if (barrio != null && barrio.isNotEmpty) {
            final compacto = SolicitudDisplayHelper.compactBarrio(barrio);
            if (forzarBarrio ||
                sinBarrio ||
                solicitud['origen_barrio']?.toString() != compacto) {
              solicitud['origen_barrio'] = compacto;
              changed = true;
            }
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
