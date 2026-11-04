import 'package:intellitaxi/core/geo/place_precision.dart';
import 'package:intellitaxi/core/services/precise_gps.dart';
import 'package:intellitaxi/core/services/reverse_geocoding_service.dart';
import 'package:intellitaxi/features/conductor/utils/solicitud_display_helper.dart';
import 'package:intellitaxi/features/pasajero/model/place_details_model.dart';
import 'package:intellitaxi/features/pasajero/services/places_service.dart';
import 'package:intellitaxi/features/rides/data/trip_location.dart';

/// Arma origen con la misma precisión que WhatsApp/central:
/// geocodifica la calle (no el GPS del teléfono) y un POI solo si está
/// a metros del punto.
class PrecisePickupBuilder {
  /// El GPS suele quedar a una cuadra. WhatsApp no usa ese punto: geocodifica
  /// la calle. Hasta esto se acepta el candidato de la dirección.
  static const double pickupSnapMeters = 120;

  PrecisePickupBuilder({
    ReverseGeocodingService? geocoding,
    PlacesService? places,
  })  : _geocoding = geocoding ?? ReverseGeocodingService.shared,
        _places = places ?? PlacesService();

  final ReverseGeocodingService _geocoding;
  final PlacesService _places;

  Future<TripLocation> build({
    required double lat,
    required double lng,
    String? placeId,
    bool isCurrentLocation = true,
    String? existingName,
    String? existingAddress,
    bool keepExistingName = false,
  }) async {
    final label = await _geocoding.resolveDriverPickupLabel(
      lat: lat,
      lng: lng,
    );

    PlaceResult? nearby;
    try {
      nearby = await _places.findNearestPlaceAt(
        lat,
        lng,
        maxDistanceMeters: PreciseGps.maxPickupAccuracyMeters,
      );
    } catch (_) {
      nearby = null;
    }

    final poiName = nearby?.name.trim();
    final usePoi = poiName != null &&
        poiName.isNotEmpty &&
        !SolicitudDisplayHelper.looksLikeStreetAddress(poiName);

    final keptName = existingName?.trim();
    final keepName = keepExistingName &&
        keptName != null &&
        keptName.isNotEmpty &&
        !SolicitudDisplayHelper.isPlaceholderPickup(keptName);

    // El punto escrito a mano ya es la dirección (como WhatsApp).
    // El GPS del teléfono se sustituye por el punto de esa misma calle.
    var outLat = lat;
    var outLng = lng;
    if (!keepExistingName) {
      final door = await _doorFromStreet(
        query: streetSearchQuery(
          street: label.streetLine,
          barrio: label.area,
          address: label.address,
        ),
        nearLat: lat,
        nearLng: lng,
      );
      final snapped = door ??
          ReverseGeocodingService.snapIfClose(
            fromLat: lat,
            fromLng: lng,
            toLat: label.anchorLat,
            toLng: label.anchorLng,
            maxMeters: pickupSnapMeters,
          );
      if (snapped != null) {
        outLat = snapped.lat;
        outLng = snapped.lng;
      }
    }

    final street = label.streetLine?.trim();
    final name = keepName
        ? keptName
        : usePoi
            ? poiName
            : (street != null && street.isNotEmpty
                ? street
                : (label.driverTitle.isNotEmpty
                    ? label.driverTitle
                    : (keptName ?? 'Punto de recogida')));

    final addressFromNearby = nearby?.address.trim();
    final address = (addressFromNearby != null && addressFromNearby.isNotEmpty)
        ? addressFromNearby
        : (label.address.trim().isNotEmpty
            ? label.address.trim()
            : (existingAddress?.trim().isNotEmpty == true
                ? existingAddress!.trim()
                : name));

    return TripLocation(
      placeId: nearby?.placeId.isNotEmpty == true ? nearby!.placeId : placeId,
      name: name,
      address: address,
      lat: outLat,
      lng: outLng,
      isCurrentLocation: isCurrentLocation,
      barrio: label.area?.trim().isNotEmpty == true ? label.area!.trim() : null,
    );
  }

  /// Texto que WhatsApp/central mandan al geocoder: calle + barrio + Popayán.
  static String? streetSearchQuery({
    String? street,
    String? barrio,
    String? address,
  }) {
    final s = street?.trim();
    final b = barrio?.trim();
    if (s != null &&
        s.isNotEmpty &&
        (PlacePrecision.looksLikeStreetLabel(s) ||
            SolicitudDisplayHelper.looksLikeStreetAddress(s))) {
      final q = (b != null &&
              b.isNotEmpty &&
              !s.toLowerCase().contains(b.toLowerCase()))
          ? '$s, $b'
          : s;
      return PlacePrecision.withAreaContext(q);
    }

    final addr = address?.trim();
    if (addr == null || addr.isEmpty) return null;
    final first = addr.split(',').first.trim();
    if (!SolicitudDisplayHelper.looksLikeStreetAddress(first) &&
        !PlacePrecision.looksLikeStreetLabel(first)) {
      return null;
    }
    final parts = addr.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty);
    return PlacePrecision.withAreaContext(parts.take(2).join(', '));
  }

  Future<({double lat, double lng})?> _doorFromStreet({
    required String? query,
    required double nearLat,
    required double nearLng,
  }) async {
    if (query == null || query.isEmpty) return null;
    try {
      final place = await _places.geocodeNearestAddress(
        query,
        nearLat: nearLat,
        nearLng: nearLng,
        maxDistanceMeters: pickupSnapMeters,
      );
      if (place == null) return null;
      return (lat: place.lat, lng: place.lng);
    } catch (_) {
      return null;
    }
  }
}
