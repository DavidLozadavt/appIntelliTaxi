import 'package:geolocator/geolocator.dart';
import 'package:intellitaxi/core/services/device_location_service.dart';
import 'package:intellitaxi/features/conductor/providers/conductor_home_provider.dart';

/// Coordenadas para emergencia: caché del conductor primero, GPS rápido después.
class EmergenciaReportHelper {
  EmergenciaReportHelper._();

  /// Ubicación lista para POST (sin geocoding en el front).
  static Future<Position?> resolveCoords(ConductorHomeProvider conductor) async {
    final cached = conductor.currentPosition;
    if (cached != null) return cached;

    try {
      final last = await Geolocator.getLastKnownPosition();
      if (last != null) return last;
    } catch (_) {}

    final resolved = await DeviceLocationService.resolveCurrentPosition(
      timeout: const Duration(seconds: 4),
    );
    return resolved?.position;
  }
}
