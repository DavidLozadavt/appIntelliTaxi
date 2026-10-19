import 'dart:async';

import 'package:intellitaxi/core/services/app_logger.dart';
import 'package:intellitaxi/core/services/reverse_geocoding_service.dart';
import 'package:intellitaxi/features/conductor/utils/conductor_solicitud_payload_helper.dart';
import 'package:intellitaxi/features/conductor/utils/solicitud_display_helper.dart';
import 'package:intellitaxi/features/pasajero/model/place_details_model.dart';
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

    if (!SolicitudDisplayHelper.origenTieneMapa(solicitud)) return false;
    final lat = SolicitudDisplayHelper.parseCoordinate(solicitud['origen_lat']);
    final lng = SolicitudDisplayHelper.parseCoordinate(solicitud['origen_lng']);
    if (lat == null || lng == null) return false;

    final PlaceResult? nearby;
    try {
      nearby = await _placesService
          .findNearestPlaceAt(
            lat,
            lng,
            maxDistanceMeters: 110,
          )
          .timeout(const Duration(seconds: 4));
    } catch (_) {
      // Timeout/red: opcional; no debe llegar a Crashlytics.
      return false;
    }
    if (nearby == null || nearby.name.trim().isEmpty) return false;

    final nearbyName = nearby.name.trim();
    // Un nombre de calle ("Cra. 5") es menos útil que el título de calle con
    // número que resuelve el geocoder después: solo se usa como nombre si es
    // un comercio real.
    final esComercio = !SolicitudDisplayHelper.looksLikeStreetAddress(
      nearbyName,
    );

    var changed = false;
    if (esComercio) {
      solicitud['origen_name'] = nearbyName;
      changed = true;
    }

    if (!ConductorSolicitudPayloadHelper.hasMeaningfulAddress(
      solicitud['origen_address']?.toString(),
    )) {
      solicitud['origen_address'] = nearby.address.trim().isNotEmpty
          ? nearby.address
          : nearbyName;
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
    try {
      return await _enrichImpl(
        solicitud,
        forzarBarrio: forzarBarrio,
      ).timeout(
        const Duration(seconds: 7),
        onTimeout: () => false,
      );
    } catch (_) {
      return false;
    }
  }

  /// ¿La dirección del payload concuerda con el barrio que trae?
  ///
  /// Si la dirección menciona el barrio ("Cra 5 #12-34, Las Palmas, ...") es
  /// consistente. Si no lo menciona puede ser una calle sintetizada por
  /// Google, y hay que verificarla contra las coordenadas.
  static bool _payloadEsCoherente(
    Map<String, dynamic> solicitud, {
    required bool esOrigen,
  }) {
    return SolicitudDisplayHelper.direccionCoincideConBarrio(
      solicitud,
      esOrigen: esOrigen,
    );
  }

  /// Descarta una dirección de calle que el geocoder no respalda.
  ///
  /// Google sintetiza calles y numeración donde no hay cobertura y las
  /// devuelve como `ROOFTOP` (ej. "Cl. 15 # 37-222" para un punto de Los
  /// Alamos de Occidente, cuyo barrio real es "Los Alamos de Occidente").
  /// Cuando el punto no cae sobre una calle mapeada, la dirección del
  /// payload es una invención: se reemplaza por el barrio, que sí es real.
  ///
  /// Devuelve `true` si se modificó la solicitud.
  bool _descartarDireccionFabricada(
    Map<String, dynamic> solicitud,
    CurrentLocationData label, {
    required bool esOrigen,
  }) {
    final calleReal = label.streetLine?.trim() ?? '';
    if (calleReal.isNotEmpty) return false;

    final barrio = label.area?.trim() ?? '';
    if (barrio.isEmpty) return false;

    final claveDir = esOrigen ? 'origen_address' : 'destino_address';
    final claveNombre = esOrigen ? 'origen_name' : 'destino_name';
    final direccionActual = solicitud[claveDir]?.toString().trim() ?? '';
    if (direccionActual.isEmpty) return false;
    if (!SolicitudDisplayHelper.looksLikeStreetAddress(direccionActual)) {
      return false;
    }

    final direccionLimpia = label.address.trim().isNotEmpty
        ? label.address.trim()
        : barrio;
    solicitud[claveDir] = direccionLimpia;
    solicitud[claveNombre] = barrio;

    AppLogger.d(
      '🧭 Dirección de calle descartada (sin calle mapeada) → barrio "$barrio"',
      tag: 'SolicitudEnrich',
    );
    return true;
  }

  Future<bool> _enrichImpl(
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
      try {
      if (isDestino) {
        if (SolicitudDisplayHelper.tieneDestinoCompletoParaMapa(solicitud) &&
            _payloadEsCoherente(solicitud, esOrigen: false) &&
            !forzarBarrio) {
          return;
        }
      } else {
        final origenCompleto =
            SolicitudDisplayHelper.tieneOrigenCompletoParaMapa(solicitud);
        final barrio = SolicitudDisplayHelper.barrioFromPayload(
          SolicitudDisplayHelper.normalizeSolicitudMap(solicitud),
        );
        final barrioOk = barrio != null && barrio.isNotEmpty;
        // Solo se salta la geocodificación si el payload es coherente: la
        // dirección menciona el barrio. Si no lo menciona puede ser una
        // calle inventada, y hay que verificarla contra el punto.
        if (origenCompleto &&
            barrioOk &&
            _payloadEsCoherente(solicitud, esOrigen: true) &&
            !forzarBarrio) {
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
        if (_descartarDireccionFabricada(solicitud, label, esOrigen: false)) {
          changed = true;
        }
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

        // La dirección del payload puede ser una calle que Google inventó en
        // una zona sin cobertura ("Cl. 15 # 37-222" en Los Alamos de
        // Occidente, marcada como ROOFTOP). Si el geocoder dice que el punto
        // NO está sobre una calle real, esa dirección no existe: se
        // descarta y se muestra el barrio.
        if (_descartarDireccionFabricada(solicitud, label, esOrigen: true)) {
          changed = true;
        }

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
          final barrio = label.area?.trim().isNotEmpty == true
              ? label.area!.trim()
              : await _reverseGeocoding.resolveAreaName(
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
      } catch (_) {
        // Geocoding/Places opcional; no fatal.
      }
    }

    final oLat = SolicitudDisplayHelper.parseCoordinate(solicitud['origen_lat']);
    final oLng = SolicitudDisplayHelper.parseCoordinate(solicitud['origen_lng']);
    if (oLat != null &&
        oLng != null &&
        SolicitudDisplayHelper.origenTieneMapa(solicitud)) {
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
