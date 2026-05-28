import 'package:geolocator/geolocator.dart';
import 'package:intellitaxi/core/utils/json_payload_helper.dart';
import 'package:intellitaxi/features/conductor/utils/solicitud_display_helper.dart';

/// Distancia del conductor al punto de recogida (GPS local o API).
class ConductorSolicitudDistanceHelper {
  ConductorSolicitudDistanceHelper._();

  static double? metersToPickup(
    Map<String, dynamic> solicitud, {
    required double driverLat,
    required double driverLng,
  }) {
    final lat = SolicitudDisplayHelper.parseCoordinate(solicitud['origen_lat']);
    final lng = SolicitudDisplayHelper.parseCoordinate(solicitud['origen_lng']);
    if (lat == null || lng == null) return null;
    if (lat.abs() < 0.0001 && lng.abs() < 0.0001) return null;

    final meters = Geolocator.distanceBetween(driverLat, driverLng, lat, lng);
    if (!meters.isFinite || meters < 0) return null;
    return meters;
  }

  static String formatMeters(double meters) {
    if (meters < 1000) {
      final m = meters.round();
      return m <= 1 ? '1 m' : '$m m';
    }
    final km = meters / 1000;
    if (km < 10) return '${km.toStringAsFixed(1)} km';
    return '${km.round()} km';
  }

  static String labelDesdeConductor(double meters) =>
      'A ${formatMeters(meters)} de ti';

  /// Texto para tarjeta: «A 450 m de ti». Prioriza API; si falta, calcula con GPS.
  static String? resolveLabel(
    Map<String, dynamic> solicitud, {
    double? driverLat,
    double? driverLng,
  }) {
    final kmApi = solicitud['distancia_desde_mi_km'] ??
        solicitud['distanciaDesdeMiKm'];
    if (kmApi != null) {
      final km = JsonPayloadHelper.parseDouble(kmApi);
      if (km > 0) return labelDesdeConductor(km * 1000);
    }

    final metrosApi = solicitud['distancia_metros'] ??
        solicitud['distanciaMetros'] ??
        solicitud['distance_value'];
    if (metrosApi != null) {
      final m = JsonPayloadHelper.parseDouble(metrosApi);
      if (m > 0 && m < 500_000) return labelDesdeConductor(m);
    }

    final distLegacy = solicitud['distancia']?.toString().trim() ?? '';
    if (distLegacy.isNotEmpty) {
      final parsed = _parseLegacyDistance(distLegacy);
      if (parsed != null) return labelDesdeConductor(parsed);
      if (!distLegacy.toLowerCase().contains('de ti')) {
        return 'A $distLegacy de ti';
      }
      return distLegacy;
    }

    if (driverLat != null && driverLng != null) {
      final meters = metersToPickup(
        solicitud,
        driverLat: driverLat,
        driverLng: driverLng,
      );
      if (meters != null) return labelDesdeConductor(meters);
    }
    return null;
  }

  static double? _parseLegacyDistance(String raw) {
    final v = raw.toLowerCase().replaceAll(',', '.');
    final kmMatch = RegExp(r'([\d.]+)\s*km').firstMatch(v);
    if (kmMatch != null) {
      final km = double.tryParse(kmMatch.group(1) ?? '');
      if (km != null && km > 0) return km * 1000;
    }
    final mMatch = RegExp(r'([\d.]+)\s*m(?:\s|$)').firstMatch(v);
    if (mMatch != null) {
      final m = double.tryParse(mMatch.group(1) ?? '');
      if (m != null && m > 0) return m;
    }
    return null;
  }
}
