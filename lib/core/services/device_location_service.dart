import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intellitaxi/core/geo/popayan_urban_area.dart';
import 'package:intellitaxi/core/services/app_logger.dart';
import 'package:intellitaxi/core/services/precise_gps.dart';
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
  ///
  /// Prioriza **precisión máxima**: GNSS de navegación y un stream hasta
  /// que el radio de error baje de ~25 m. Nunca cae a GPS aproximado
  /// (medium/low): ese era el pin desplazado una o dos cuadras.
  static Future<DeviceLocationResult?> resolveCurrentPosition({
    Duration timeout = resolveTimeout,
    Duration lastKnownMaxAge = const Duration(seconds: 30),
    double lastKnownMaxAccuracyMeters = 25,
  }) async {
    Position? lastKnown;
    try {
      lastKnown = await Geolocator.getLastKnownPosition();
    } catch (e) {
      AppLogger.d('getLastKnownPosition: $e', tag: 'DeviceLocation');
    }

    // Atajo solo si el fix es reciente Y preciso; si no, vale más pena
    // esperar un GPS fresco antes de mandar un punto equivocado.
    if (lastKnown != null) {
      final age = DateTime.now().difference(lastKnown.timestamp);
      if (!age.isNegative &&
          age <= lastKnownMaxAge &&
          lastKnown.accuracy <= lastKnownMaxAccuracyMeters) {
        AppLogger.d(
          '📍 lastKnown fresco (${age.inSeconds}s, '
          '±${lastKnown.accuracy.round()}m): '
          '${lastKnown.latitude}, ${lastKnown.longitude}',
          tag: 'DeviceLocation',
        );
        return DeviceLocationResult(
          position: lastKnown,
          usedLastKnown: true,
        );
      }
      AppLogger.d(
        'lastKnown descartado (edad ${age.inSeconds}s, '
        '±${lastKnown.accuracy.round()}m) → pidiendo GPS fresco',
        tag: 'DeviceLocation',
      );
    }

    final streamed = await PreciseGps.waitForReliableFix(
      timeout: timeout,
      maxAccuracyMeters: PreciseGps.maxPickupAccuracyMeters,
      use: PreciseGpsUse.pickup,
    );
    if (streamed != null) {
      AppLogger.d(
        '📍 GPS preciso: ${streamed.latitude}, ${streamed.longitude} '
        '±${streamed.accuracy.round()}m',
        tag: 'DeviceLocation',
      );
      return DeviceLocationResult(position: streamed);
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: PreciseGps.currentPosition(
          timeLimit: timeout,
          use: PreciseGpsUse.pickup,
        ),
      ).timeout(timeout + const Duration(seconds: 2));
      AppLogger.d(
        '📍 GPS (bestForNavigation): '
        '${position.latitude}, ${position.longitude} '
        '±${position.accuracy.round()}m',
        tag: 'DeviceLocation',
      );
      return DeviceLocationResult(position: position);
    } catch (e) {
      AppLogger.d('getCurrentPosition: $e', tag: 'DeviceLocation');
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
