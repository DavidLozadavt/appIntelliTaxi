import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intellitaxi/core/services/app_logger.dart';

/// Uso del GPS: el pasajero no necesita barra azul de fondo;
/// el conductor sí necesita GNSS de navegación en viaje.
enum PreciseGpsUse { pickup, navigation }

/// Política única de GPS de máxima precisión (recogida + flota).
///
/// Geolocator `high` en Android es el mismo fused provider que `best`,
/// pero sin `intervalDuration` el sistema entrega un punto cada varios
/// segundos y con radio de error grande. Aquí se fuerza GNSS de
/// navegación, intervalo de 1 s y se descartan fixes ruidosos.
abstract final class PreciseGps {
  static const LocationAccuracy accuracy = LocationAccuracy.bestForNavigation;

  /// Radio de error máximo (m) para pintar / enviar. ±80 m es otra cuadra.
  static const double maxAccuracyMeters = 40;

  /// Recogida del pasajero: más estricto para no mandar el taxi al vecino.
  static const double maxPickupAccuracyMeters = 25;

  static const Duration defaultTimeLimit = Duration(seconds: 12);

  /// Velocidad implícita por encima de esto (m/s ≈ 200 km/h) es salto GNSS.
  static const double maxPlausibleSpeedMps = 55;

  static const String iosPrecisePurposeKey = 'PrecisePickup';

  static bool isReliable(
    Position position, {
    double maxAccuracyMeters = PreciseGps.maxAccuracyMeters,
  }) {
    if (!position.accuracy.isFinite || position.accuracy < 0) return true;
    return position.accuracy <= maxAccuracyMeters;
  }

  /// Primer fix siempre entra (el mapa no debe quedar vacío).
  /// Después se rechaza ruido: error grande o teletransporte.
  static bool shouldAccept(Position next, Position? previous) {
    if (previous == null) return true;

    final nextErr = next.accuracy.isFinite && next.accuracy >= 0
        ? next.accuracy
        : 9999.0;
    final prevErr = previous.accuracy.isFinite && previous.accuracy >= 0
        ? previous.accuracy
        : 9999.0;

    final meters = Geolocator.distanceBetween(
      previous.latitude,
      previous.longitude,
      next.latitude,
      next.longitude,
    );

    final dt = next.timestamp.difference(previous.timestamp);
    if (!dt.isNegative &&
        dt.inMilliseconds > 200 &&
        dt < const Duration(seconds: 8)) {
      final mps = meters / (dt.inMilliseconds / 1000);
      if (mps > maxPlausibleSpeedMps && nextErr >= prevErr) {
        return false;
      }
    }

    if (nextErr <= maxAccuracyMeters) return true;
    // En movimiento un radio un poco peor sigue siendo mejor que congelar.
    if (meters >= 15 && nextErr <= maxAccuracyMeters * 2) return true;
    return nextErr + 8 < prevErr;
  }

  static LocationSettings currentPosition({
    Duration timeLimit = defaultTimeLimit,
    PreciseGpsUse use = PreciseGpsUse.navigation,
  }) {
    return platform(
      use: use,
      distanceFilter: 0,
      timeLimit: timeLimit,
      interval: const Duration(seconds: 1),
    );
  }

  static LocationSettings stream({
    PreciseGpsUse use = PreciseGpsUse.navigation,
    int distanceFilter = 3,
    Duration interval = const Duration(seconds: 1),
  }) {
    return platform(
      use: use,
      distanceFilter: distanceFilter,
      interval: interval,
    );
  }

  static LocationSettings platform({
    PreciseGpsUse use = PreciseGpsUse.navigation,
    int distanceFilter = 0,
    Duration? timeLimit,
    Duration interval = const Duration(seconds: 1),
  }) {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return AndroidSettings(
        accuracy: accuracy,
        distanceFilter: distanceFilter,
        intervalDuration: interval,
        timeLimit: timeLimit,
        forceLocationManager: false,
      );
    }
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      final driving = use == PreciseGpsUse.navigation;
      return AppleSettings(
        accuracy: accuracy,
        distanceFilter: distanceFilter,
        timeLimit: timeLimit,
        pauseLocationUpdatesAutomatically: false,
        activityType: driving
            ? ActivityType.automotiveNavigation
            : ActivityType.otherNavigation,
        allowBackgroundLocationUpdates: driving,
        showBackgroundLocationIndicator: driving,
      );
    }
    return LocationSettings(
      accuracy: accuracy,
      distanceFilter: distanceFilter,
      timeLimit: timeLimit,
    );
  }

  /// En iOS 14+ / Android 12+ el usuario puede haber dado solo ubicación
  /// aproximada. Pedimos precisión completa justo antes de un fix crítico.
  static Future<void> requestFullAccuracyIfNeeded() async {
    try {
      final status = await Geolocator.getLocationAccuracy();
      if (status == LocationAccuracyStatus.precise) return;
      await Geolocator.requestTemporaryFullAccuracy(
        purposeKey: iosPrecisePurposeKey,
      );
    } catch (e) {
      AppLogger.d('Precisión completa no disponible: $e', tag: 'PreciseGps');
    }
  }

  /// Espera un fix con radio de error aceptable; si no llega, devuelve el
  /// mejor que haya visto (nunca medium/low a propósito).
  static Future<Position?> waitForReliableFix({
    Duration timeout = defaultTimeLimit,
    double maxAccuracyMeters = PreciseGps.maxAccuracyMeters,
    PreciseGpsUse use = PreciseGpsUse.pickup,
  }) async {
    await requestFullAccuracyIfNeeded();

    final completer = Completer<Position?>();
    Position? best;
    StreamSubscription<Position>? sub;
    Timer? timer;

    void finish(Position? value) {
      if (!completer.isCompleted) completer.complete(value);
    }

    timer = Timer(timeout, () => finish(best));
    sub = Geolocator.getPositionStream(
      locationSettings: stream(use: use, distanceFilter: 0),
    ).listen(
      (position) {
        if (best == null ||
            (position.accuracy.isFinite &&
                best!.accuracy.isFinite &&
                position.accuracy < best!.accuracy) ||
            !best!.accuracy.isFinite) {
          best = position;
        }
        if (isReliable(position, maxAccuracyMeters: maxAccuracyMeters)) {
          finish(position);
        }
      },
      onError: (Object _) => finish(best),
      cancelOnError: false,
    );

    try {
      return await completer.future;
    } finally {
      timer.cancel();
      await sub.cancel();
    }
  }
}
