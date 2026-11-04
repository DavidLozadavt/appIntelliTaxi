import 'package:geolocator/geolocator.dart';
import 'package:intellitaxi/core/services/reverse_geocoding_service.dart';

/// Corre el GPS del teléfono hasta el punto de dirección que usa WhatsApp.
///
/// El chip (o el wifi) queda sistemáticamente a unos metros de la puerta.
/// El geocoder devuelve esa puerta. Se guarda el desfase y se aplica a los
/// fixes siguientes, así el pin se mueve con la persona pero cae en la vía
/// y no en la cuadra de al lado. A los 90 m se suelta y hay que recalcular.
class GpsAddressHold {
  static const double releaseMeters = 90;
  static const Duration _retryWithoutFix = Duration(seconds: 25);

  double? _dLat;
  double? _dLng;
  double? _originLat;
  double? _originLng;
  DateTime? _fetchedAt;
  bool _pending = false;

  bool get hasBias => _dLat != null && _dLng != null;

  bool shouldRefresh(double lat, double lng) {
    if (_pending) return false;
    if (_fetchedAt == null) return true;
    final age = DateTime.now().difference(_fetchedAt!);
    if (!hasBias) return age >= _retryWithoutFix;
    if (_originLat == null || _originLng == null) return true;
    final moved = Geolocator.distanceBetween(lat, lng, _originLat!, _originLng!);
    return moved >= releaseMeters;
  }

  void markPending() {
    _pending = true;
  }

  /// true si el desfase cambió y el pin debe redibujarse.
  bool absorb(
    double gpsLat,
    double gpsLng,
    double? anchorLat,
    double? anchorLng,
  ) {
    _pending = false;
    _fetchedAt = DateTime.now();

    // Sin respuesta del geocoder se conserva el desfase anterior.
    if (anchorLat == null || anchorLng == null) return false;

    _originLat = gpsLat;
    _originLng = gpsLng;

    final snap = ReverseGeocodingService.snapIfClose(
      fromLat: gpsLat,
      fromLng: gpsLng,
      toLat: anchorLat,
      toLng: anchorLng,
    );
    if (snap == null) {
      final had = hasBias;
      _dLat = null;
      _dLng = null;
      return had;
    }

    final dLat = snap.lat - gpsLat;
    final dLng = snap.lng - gpsLng;
    final changed = _dLat == null ||
        (dLat - _dLat!).abs() > 1e-6 ||
        (dLng - _dLng!).abs() > 1e-6;
    _dLat = dLat;
    _dLng = dLng;
    return changed;
  }

  Future<bool> refresh(ReverseGeocodingService geo, Position raw) async {
    if (!shouldRefresh(raw.latitude, raw.longitude)) return false;
    markPending();
    try {
      final data = await geo.resolveDriverPickupLabel(
        lat: raw.latitude,
        lng: raw.longitude,
      );
      return absorb(
        raw.latitude,
        raw.longitude,
        data.anchorLat,
        data.anchorLng,
      );
    } catch (_) {
      _pending = false;
      _fetchedAt ??= DateTime.now();
      return false;
    }
  }

  Position apply(Position raw) {
    if (!hasBias || _originLat == null || _originLng == null) return raw;
    final moved = Geolocator.distanceBetween(
      raw.latitude,
      raw.longitude,
      _originLat!,
      _originLng!,
    );
    if (moved > releaseMeters) {
      _dLat = null;
      _dLng = null;
      return raw;
    }
    return Position(
      latitude: raw.latitude + _dLat!,
      longitude: raw.longitude + _dLng!,
      timestamp: raw.timestamp,
      accuracy: raw.accuracy,
      altitude: raw.altitude,
      altitudeAccuracy: raw.altitudeAccuracy,
      heading: raw.heading,
      headingAccuracy: raw.headingAccuracy,
      speed: raw.speed,
      speedAccuracy: raw.speedAccuracy,
    );
  }
}
