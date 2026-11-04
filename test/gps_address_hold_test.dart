import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intellitaxi/core/services/gps_address_hold.dart';
import 'package:intellitaxi/core/services/precise_gps.dart';
import 'package:intellitaxi/core/services/reverse_geocoding_service.dart';

Position _fix({
  required double lat,
  required double lng,
  required double accuracy,
  required DateTime timestamp,
}) {
  return Position(
    latitude: lat,
    longitude: lng,
    timestamp: timestamp,
    accuracy: accuracy,
    altitude: 0,
    altitudeAccuracy: 0,
    heading: 0,
    headingAccuracy: 0,
    speed: 0,
    speedAccuracy: 0,
  );
}

void main() {
  test('un fix burdo no pisa uno fino si el teléfono no se movió', () {
    final t = DateTime.utc(2026, 11, 4, 12);
    final fine = _fix(
      lat: 2.4448,
      lng: -76.6147,
      accuracy: 8,
      timestamp: t,
    );
    final coarse = _fix(
      lat: 2.4450,
      lng: -76.6147,
      accuracy: 45,
      timestamp: t.add(const Duration(seconds: 1)),
    );

    expect(PreciseGps.shouldAccept(coarse, fine), isFalse);
    expect(
      PreciseGps.shouldAccept(
        _fix(
          lat: 2.44481,
          lng: -76.6147,
          accuracy: 6,
          timestamp: t.add(const Duration(seconds: 1)),
        ),
        fine,
      ),
      isTrue,
    );
  });

  test('el pin usa la puerta del geocoder y se suelta lejos', () {
    final hold = GpsAddressHold();
    final raw = _fix(
      lat: 2.4448,
      lng: -76.6147,
      accuracy: 30,
      timestamp: DateTime.utc(2026, 11, 4, 12),
    );
    final doorLat = 2.4448 + (28 / 111320);

    expect(
      hold.absorb(raw.latitude, raw.longitude, doorLat, raw.longitude),
      isTrue,
    );

    final shown = hold.apply(raw);
    expect(shown.latitude, closeTo(doorLat, 1e-8));
    expect(
      Geolocator.distanceBetween(
        raw.latitude,
        raw.longitude,
        shown.latitude,
        shown.longitude,
      ),
      closeTo(28, 1),
    );

    final far = _fix(
      lat: raw.latitude + (120 / 111320),
      lng: raw.longitude,
      accuracy: 12,
      timestamp: raw.timestamp.add(const Duration(seconds: 20)),
    );
    expect(hold.apply(far).latitude, closeTo(far.latitude, 1e-8));
  });

  test('no mueve el pin si el geocoder respondió otro sector', () {
    final snap = ReverseGeocodingService.snapIfClose(
      fromLat: 2.4448,
      fromLng: -76.6147,
      toLat: 2.4448 + (150 / 111320),
      toLng: -76.6147,
    );
    expect(snap, isNull);

    final close = ReverseGeocodingService.snapIfClose(
      fromLat: 2.4448,
      fromLng: -76.6147,
      toLat: 2.4448 + (25 / 111320),
      toLng: -76.6147,
    );
    expect(close, isNotNull);
  });
}
