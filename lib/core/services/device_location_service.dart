import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intellitaxi/core/geo/popayan_urban_area.dart';
import 'package:intellitaxi/core/services/app_logger.dart';
import 'package:permission_handler/permission_handler.dart';

/// Resultado de intentar obtener la ubicación del dispositivo.
class DeviceLocationResult {
  const DeviceLocationResult({
    required this.position,
    this.usedDebugFallback = false,
    this.usedLastKnown = false,
  });

  final Position position;
  final bool usedDebugFallback;
  final bool usedLastKnown;
}

/// Permisos + obtención robusta de GPS (emulador incluido).
class DeviceLocationService {
  DeviceLocationService._();

  static Future<bool> isServiceEnabled() => Geolocator.isLocationServiceEnabled();

  static Future<PermissionStatus> locationPermissionStatus() =>
      Permission.location.status;

  static Future<bool> requestLocationPermission() async {
    if (!await isServiceEnabled()) return false;

    var status = await Permission.location.status;
    if (status.isGranted) return true;

    status = await Permission.location.request();
    return status.isGranted;
  }

  /// Intenta GPS actual → última conocida → (solo debug) centro de Popayán.
  static Future<DeviceLocationResult?> resolveCurrentPosition({
    Duration timeout = const Duration(seconds: 12),
  }) async {
    Position? lastKnown;
    try {
      lastKnown = await Geolocator.getLastKnownPosition();
    } catch (e) {
      AppLogger.d('getLastKnownPosition: $e', tag: 'DeviceLocation');
    }

    final attempts = <LocationSettings>[
      LocationSettings(
        accuracy: LocationAccuracy.medium,
        timeLimit: timeout,
      ),
      const LocationSettings(
        accuracy: LocationAccuracy.low,
        timeLimit: Duration(seconds: 20),
      ),
    ];

    for (final settings in attempts) {
      try {
        final position = await Geolocator.getCurrentPosition(
          locationSettings: settings,
        ).timeout(timeout + const Duration(seconds: 2));
        AppLogger.d(
          '📍 GPS: ${position.latitude}, ${position.longitude}',
          tag: 'DeviceLocation',
        );
        return DeviceLocationResult(position: position);
      } catch (e) {
        AppLogger.d('getCurrentPosition (${settings.accuracy}): $e',
            tag: 'DeviceLocation');
      }
    }

    if (lastKnown != null) {
      AppLogger.w('Usando última ubicación conocida', tag: 'DeviceLocation');
      return DeviceLocationResult(
        position: lastKnown,
        usedLastKnown: true,
      );
    }

    if (kDebugMode) {
      AppLogger.w(
        'Emulador sin GPS: usando centro urbano Popayán (solo debug)',
        tag: 'DeviceLocation',
      );
      return DeviceLocationResult(
        position: debugPopayanPosition(),
        usedDebugFallback: true,
      );
    }

    return null;
  }

  /// Ubicación de prueba dentro del urbano de Popayán (desarrollo).
  static Position debugPopayanPosition() {
    return Position(
      latitude: PopayanUrbanArea.centerLat,
      longitude: PopayanUrbanArea.centerLng,
      timestamp: DateTime.now(),
      accuracy: 25,
      altitude: 1760,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    );
  }

  static String messageForFailure({
    required bool serviceEnabled,
    required PermissionStatus permission,
  }) {
    if (!serviceEnabled) {
      return 'Activa la ubicación (GPS) en ajustes del dispositivo o emulador.';
    }
    if (permission.isPermanentlyDenied) {
      return 'Permiso de ubicación bloqueado. Ábrelo en Ajustes de la app.';
    }
    if (!permission.isGranted) {
      return 'Permisos de ubicación denegados.';
    }
    if (kDebugMode) {
      return 'No se pudo obtener GPS. En el emulador: Extended Controls → Location → fija Popayán, o reintenta (debug usa centro urbano).';
    }
    return 'No se pudo obtener tu ubicación. Revisa GPS y permisos.';
  }
}
