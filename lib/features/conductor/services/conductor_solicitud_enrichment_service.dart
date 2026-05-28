import 'package:intellitaxi/core/services/reverse_geocoding_service.dart';
import 'package:intellitaxi/features/conductor/utils/conductor_solicitud_payload_helper.dart';
import 'package:intellitaxi/features/conductor/utils/solicitud_display_helper.dart';
import 'package:intellitaxi/features/pasajero/services/places_service.dart';

/// Completa nombre/dirección/barrio solo cuando faltan datos (evita Geocoding redundante).
class ConductorSolicitudEnrichmentService {
  ConductorSolicitudEnrichmentService({
    ReverseGeocodingService? reverseGeocoding,
    PlacesService? placesService,
  })  : _reverseGeocoding = reverseGeocoding ?? ReverseGeocodingService.shared,
        _placesService = placesService ?? PlacesService();

  final ReverseGeocodingService _reverseGeocoding;
  final PlacesService _placesService;

  /// Comercio cercano al GPS (ej. Galería las Palmas) antes de mostrar la alerta.
  Future<bool> enrichPickupPoiIfNeeded(Map<String, dynamic> solicitud) async {
    if (SolicitudDisplayHelper.tieneNombreLugarRecogida(solicitud)) {
      return false;
    }

    final lat = SolicitudDisplayHelper.parseCoordinate(solicitud['origen_lat']);
    final lng = SolicitudDisplayHelper.parseCoordinate(solicitud['origen_lng']);
    if (lat == null || lng == null) return false;

    final nearby = await _placesService.findNearestPlaceAt(
      lat,
      lng,
      maxDistanceMeters: 110,
    );
    if (nearby == null || nearby.name.trim().isEmpty) return false;

    var changed = false;
    solicitud['origen_name'] = nearby.name.trim();
    changed = true;

    if (!ConductorSolicitudPayloadHelper.hasMeaningfulAddress(
      solicitud['origen_address']?.toString(),
    )) {
      solicitud['origen_address'] = nearby.address.trim().isNotEmpty
          ? nearby.address
          : nearby.name;
      changed = true;
    }
    if (nearby.placeId.isNotEmpty) {
      solicitud['origen_place_id'] ??= nearby.placeId;
    }
    return changed;
  }

  Future<bool> enrich(
    Map<String, dynamic> solicitud, {
    bool forzarBarrio = false,
  }) async {
    if (!SolicitudDisplayHelper.necesitaEnriquecimientoGeocode(
      solicitud,
      forzarBarrio: forzarBarrio,
    )) {
      return false;
    }

    var changed = false;

    Future<void> enrichPoint({
      required bool isDestino,
      required double lat,
      required double lng,
    }) async {
      if (isDestino) {
        if (SolicitudDisplayHelper.tieneDestinoCompletoParaMapa(solicitud)) {
          return;
        }
      } else {
        final origenCompleto =
            SolicitudDisplayHelper.tieneOrigenCompletoParaMapa(solicitud);
        final barrio = SolicitudDisplayHelper.barrioFromPayload(
          SolicitudDisplayHelper.normalizeSolicitudMap(solicitud),
        );
        final barrioOk = barrio != null && barrio.isNotEmpty;
        if (origenCompleto && barrioOk && !forzarBarrio) {
          return;
        }
      }

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
        } else if (!ConductorSolicitudPayloadHelper.hasMeaningfulPlaceName(
              solicitud['origen_name']?.toString(),
            ) &&
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
      await enrichPickupPoiIfNeeded(solicitud);
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
