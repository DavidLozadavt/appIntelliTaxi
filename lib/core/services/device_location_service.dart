import 'dart:async';

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

  static const Duration permissionRequestTimeout = Duration(seconds: 15);
  static const Duration resolveTimeout = Duration(seconds: 12);

  static Future<bool> isServiceEnabled() => Geolocator.isLocationServiceEnabled();

  static Future<PermissionStatus> locationPermissionStatus() =>
      Permission.location.status;

  /// Solicita permiso de ubicación con tope duro.
  /// Sin timeout, `Permission.location.request()` puede colgarse si el diálogo
  /// del sistema no aparece o queda tapado por otro overlay.
  static Future<bool> requestLocationPermission({
    Duration timeout = permissionRequestTimeout,
  }) async {
    if (!await isServiceEnabled()) return false;

    var status = await Permission.location.status;
    if (status.isGranted) return true;
    if (status.isPermanentlyDenied) return false;

    try {
      status = await Permission.location.request().timeout(timeout);
    } on TimeoutException {
      AppLogger.w(
        'Timeout pidiendo permiso de ubicación (${timeout.inSeconds}s)',
        tag: 'DeviceLocation',
      );
      status = await Permission.location.status;
    }
    return status.isGranted;
  }

  /// Abre ajustes de GPS o de la app según el fallo detectado.
  static Future<void> openRecoverySettings({
    required bool serviceEnabled,
    required PermissionStatus permission,
  }) async {
    if (!serviceEnabled) {
      await Geolocator.openLocationSettings();
      return;
    }
    if (permission.isPermanentlyDenied || permission.isDenied) {
      await openAppSettings();
    }
  }

  /// True cuando el reintento debe abrir ajustes en lugar de volver a pedir GPS.
  static bool needsSettingsRecovery({
    required bool serviceEnabled,
    required PermissionStatus permission,
  }) {
    if (!serviceEnabled) return true;
    return permission.isPermanentlyDenied;
  }

  /// Intenta GPS actual → última conocida → (solo debug) centro de Popayán.
  static Future<DeviceLocationResult?> resolveCurrentPosition({
    Duration timeout = resolveTimeout,
    Duration lastKnownMaxAge = const Duration(minutes: 5),
  }) async {
    Position? lastKnown;
    try {
      lastKnown = await Geolocator.getLastKnownPosition();
    } catch (e) {
      AppLogger.d('getLastKnownPosition: $e', tag: 'DeviceLocation');
    }

    if (lastKnown != null) {
      final age = DateTime.now().difference(lastKnown.timestamp);
      if (!age.isNegative && age <= lastKnownMaxAge) {
        AppLogger.d(
          '📍 lastKnown (${age.inSeconds}s): ${lastKnown.latitude}, ${lastKnown.longitude}',
          tag: 'DeviceLocation',
        );
        return DeviceLocationResult(
          position: lastKnown,
          usedLastKnown: true,
        );
      }
    }

    final attempts = <LocationSettings>[
      LocationSettings(
        accuracy: LocationAccuracy.medium,
        timeLimit: timeout,
      ),
      LocationSettings(
        accuracy: LocationAccuracy.low,
        timeLimit: timeout,
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

  static String actionLabelForFailure({
    required bool serviceEnabled,
    required PermissionStatus permission,
  }) {
    if (!serviceEnabled) return 'Activar ubicación';
    if (permission.isPermanentlyDenied) return 'Abrir ajustes';
    return 'Reintentar ubicación';
  }
}
