import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intellitaxi/config/app_config.dart';
import 'package:intellitaxi/core/network/mobile_network_config.dart';
import 'package:intellitaxi/core/perf/runtime_perf_flags.dart';
import 'package:intellitaxi/core/services/app_logger.dart';
import 'package:intellitaxi/core/services/location_tracking_config.dart';
import 'package:intellitaxi/core/services/precise_gps.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum _BgLocationMode { none, trip, map }

/// Antigüedad máxima (s) de un fix para considerarse vigente.
const Duration _kFreshFixMaxAge = Duration(seconds: 8);

/// Entry point del isolate de segundo plano (requerido por flutter_background_service).
@pragma('vm:entry-point')
Future<void> backgroundLocationOnStart(ServiceInstance service) async {
  Timer? timer;
  StreamSubscription<Position>? positionSub;
  _BgLocationMode mode = _BgLocationMode.none;
  int? servicioId;
  int? conductorId;
  /// Fix más reciente del stream.
  Position? lastPosition;
  DateTime? lastFixAt;
  /// Última posición realmente enviada al backend (para el filtro de distancia).
  Position? lastSentPosition;
  String? authToken;
  Dio? dio;

  if (service is AndroidServiceInstance) {
    service.setAsForegroundService();
    service.setForegroundNotificationInfo(
      title: 'IntelliTaxi en servicio',
      content: 'Seguimiento de ubicacion activo',
    );
  }

  Future<int?> resolveConductorId() async {
    if (conductorId != null && conductorId! > 0) return conductorId;
    final prefs = await SharedPreferences.getInstance();
    final directId = prefs.getInt('conductor_id') ?? prefs.getInt('user_id');
    if (directId != null && directId > 0) {
      conductorId = directId;
      return conductorId;
    }
    final userDataStr = prefs.getString('user_data');
    if (userDataStr == null || userDataStr.isEmpty) return null;
    try {
      final userData = json.decode(userDataStr);
      final id = userData['user']?['id'] ?? userData['id'];
      if (id is int) {
        conductorId = id;
        return id;
      }
      if (id is num) {
        conductorId = id.toInt();
        return conductorId;
      }
      final parsed = int.tryParse(id?.toString() ?? '');
      if (parsed != null && parsed > 0) {
        conductorId = parsed;
        return parsed;
      }
    } catch (_) {}
    return null;
  }

  Future<Dio?> ensureDio() async {
    if (authToken == null || authToken!.isEmpty) {
      final prefs = await SharedPreferences.getInstance();
      authToken = prefs.getString('token');
    }
    if (authToken == null || authToken!.isEmpty) return null;

    dio ??= Dio(
      BaseOptions(
        baseUrl: AppConfig.baseUrl,
        connectTimeout: MobileNetworkConfig.httpConnectTimeout,
        receiveTimeout: MobileNetworkConfig.httpReceiveTimeout,
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
      ),
    );
    return dio;
  }

  Future<void> stopPositionStream() async {
    await positionSub?.cancel();
    positionSub = null;
  }

  /// Stream GPS continuo.
  ///
  /// Antes cada envío abría su propia sesión GNSS (`getCurrentPosition`),
  /// que en segundo plano tarda 8-12 s y a veces expira: el backend recibía
  /// un fix viejo o nada. Con el stream abierto hay un fix fresco siempre
  /// disponible y el envío es instantáneo.
  Future<void> startPositionStream() async {
    await stopPositionStream();

    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }

      positionSub = Geolocator.getPositionStream(
        locationSettings: PreciseGps.stream(
          use: PreciseGpsUse.navigation,
          distanceFilter: 3,
        ),
      ).listen(
        (position) {
          if (!PreciseGps.shouldAccept(position, lastPosition)) return;
          lastPosition = position;
          lastFixAt = DateTime.now();
        },
        onError: (Object _) {
          // Si el stream muere, el envío periódico sigue con fix puntual.
        },
        cancelOnError: false,
      );
    } catch (_) {
      // Sin stream: se usará fix puntual.
    }
  }

  /// Fix vigente: primero el del stream, si no está viejo.
  Future<Position?> resolveFreshPosition() async {
    final streamed = lastPosition;
    final streamedAt = lastFixAt;
    if (streamed != null && streamedAt != null) {
      final age = DateTime.now().difference(streamedAt);
      if (!age.isNegative && age <= _kFreshFixMaxAge) {
        return streamed;
      }
    }

    try {
      final fresh = await Geolocator.getCurrentPosition(
        locationSettings: PreciseGps.currentPosition(
          timeLimit: const Duration(seconds: 12),
        ),
      );
      lastPosition = fresh;
      lastFixAt = DateTime.now();
      return fresh;
    } catch (_) {
      // Sin fix nuevo: se prefiere no enviar nada antes que enviar un
      // punto viejo que teletransporte al conductor en el mapa.
      return null;
    }
  }

  Future<void> sendTripLocation() async {
    if (servicioId == null || conductorId == null) return;

    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }

      final position = await resolveFreshPosition();
      if (position == null) return;

      if (lastSentPosition != null) {
        final moved = Geolocator.distanceBetween(
          lastSentPosition!.latitude,
          lastSentPosition!.longitude,
          position.latitude,
          position.longitude,
        );
        if (moved < LocationTrackingConfig.minDistanceMeters &&
            position.speed < 0.5) {
          return;
        }
      }

      final dioClient = await ensureDio();
      if (dioClient == null) return;

      await dioClient.post(
        'servicios/actualizar-ubicacion',
        data: {
          'servicio_id': servicioId,
          'conductor_id': conductorId,
          'lat': position.latitude,
          'lng': position.longitude,
          'velocidad': position.speed.isFinite && position.speed >= 0
              ? position.speed
              : 0,
          'direccion': position.heading.isFinite && position.heading >= 0
              ? position.heading
              : 0,
          'bg': true,
        },
      );

      lastSentPosition = position;

      if (service is AndroidServiceInstance) {
        service.setForegroundNotificationInfo(
          title: 'IntelliTaxi en servicio',
          content: 'Servicio #$servicioId - ubicacion enviada',
        );
      }
    } catch (_) {
      // Mantener silencioso para no tumbar el isolate.
    }
  }

  Future<void> sendMapHeartbeat() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }

      final resolvedId = await resolveConductorId();
      if (resolvedId == null) return;

      final position = await resolveFreshPosition();
      if (position == null) return;

      final dioClient = await ensureDio();
      if (dioClient == null) return;

      await dioClient.post(
        'taxi/conductor/ubicacion-mapa',
        data: {
          'conductor_id': resolvedId,
          'idConductor': resolvedId,
          'lat': position.latitude,
          'lng': position.longitude,
          'velocidad': position.speed.isFinite && position.speed >= 0
              ? position.speed
              : 0,
          'direccion': position.heading.isFinite && position.heading >= 0
              ? position.heading
              : 0,
          'estado': 'disponible',
          'bg': true,
        },
      );

      lastSentPosition = position;

      if (service is AndroidServiceInstance) {
        service.setForegroundNotificationInfo(
          title: 'IntelliTaxi conductor',
          content: 'En linea - ubicacion actualizada',
        );
      }
    } catch (_) {
      // Mantener silencioso para no tumbar el isolate.
    }
  }

  void scheduleTimer() {
    timer?.cancel();
    if (mode == _BgLocationMode.none) return;

    final intervalSeconds = mode == _BgLocationMode.trip
        ? RuntimePerfFlags.backgroundLocationIntervalSeconds
        : RuntimePerfFlags.mapHeartbeatBackgroundIntervalSeconds;

    final send = mode == _BgLocationMode.trip
        ? sendTripLocation
        : sendMapHeartbeat;

    unawaited(send());
    timer = Timer.periodic(
      Duration(seconds: intervalSeconds),
      (_) => send(),
    );
  }

  service.on('startTracking').listen((event) async {
    final rawServicio = event?['servicioId'];
    final rawConductor = event?['conductorId'];

    servicioId = rawServicio is int
        ? rawServicio
        : int.tryParse(rawServicio?.toString() ?? '');
    conductorId = rawConductor is int
        ? rawConductor
        : int.tryParse(rawConductor?.toString() ?? '');

    if (servicioId == null || conductorId == null) return;

    mode = _BgLocationMode.trip;
    lastPosition = null;
    lastFixAt = null;
    lastSentPosition = null;
    await startPositionStream();
    scheduleTimer();
  });

  service.on('startMapHeartbeat').listen((event) async {
    if (mode == _BgLocationMode.trip) return;

    final rawConductor = event?['conductorId'];
    final parsed = rawConductor is int
        ? rawConductor
        : int.tryParse(rawConductor?.toString() ?? '');
    if (parsed != null && parsed > 0) {
      conductorId = parsed;
    } else {
      conductorId = await resolveConductorId();
    }
    if (conductorId == null) return;

    servicioId = null;
    mode = _BgLocationMode.map;
    lastPosition = null;
    lastFixAt = null;
    lastSentPosition = null;
    await startPositionStream();
    scheduleTimer();
  });

  /// Pausa el heartbeat de mapa pero mantiene el FGS caliente (Android 14+).
  service.on('pauseMapHeartbeat').listen((event) async {
    if (mode != _BgLocationMode.map) return;
    timer?.cancel();
    timer = null;
    mode = _BgLocationMode.none;
    servicioId = null;
    lastPosition = null;
    lastFixAt = null;
    lastSentPosition = null;
    await stopPositionStream();
  });

  service.on('stopMapHeartbeat').listen((event) async {
    if (mode == _BgLocationMode.trip) return;
    timer?.cancel();
    timer = null;
    mode = _BgLocationMode.none;
    servicioId = null;
    lastPosition = null;
    lastFixAt = null;
    lastSentPosition = null;
    await stopPositionStream();
    await service.stopSelf();
  });

  service.on('stopTracking').listen((event) async {
    timer?.cancel();
    timer = null;
    mode = _BgLocationMode.none;
    servicioId = null;
    conductorId = null;
    lastPosition = null;
    lastFixAt = null;
    lastSentPosition = null;
    authToken = null;
    dio = null;
    await stopPositionStream();
    await service.stopSelf();
  });
}

class BackgroundLocationService {
  static final FlutterBackgroundService _service = FlutterBackgroundService();
  static bool _initialized = false;

  static Future<void> initialize() async {
    if (_initialized) return;
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return;
    }

    await _service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: backgroundLocationOnStart,
        autoStart: false,
        isForegroundMode: true,
        autoStartOnBoot: false,
        foregroundServiceNotificationId: 7771,
        initialNotificationTitle: 'IntelliTaxi activo',
        initialNotificationContent: 'Preparando seguimiento de ubicacion...',
      ),
      iosConfiguration: IosConfiguration(),
    );
    _initialized = true;
  }

  static Future<void> _ensureRunning() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    if (!_initialized) {
      await initialize();
    }
    final isRunning = await _service.isRunning();
    if (!isRunning) {
      await _service.startService();
    }
  }

  /// Arranca el FGS en primer plano (requerido en Android 14+ antes de ir a background).
  static Future<void> ensureServiceRunning() async {
    await _ensureRunning();
  }

  static Future<bool> isServiceRunning() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return false;
    if (!_initialized) return false;
    return _service.isRunning();
  }

  static Future<void> startTracking({
    required int servicioId,
    required int conductorId,
  }) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    await _ensureRunning();
    _service.invoke('startTracking', {
      'servicioId': servicioId,
      'conductorId': conductorId,
    });
  }

  /// Heartbeat de mapa en segundo plano (conductor en línea, app pausada).
  static Future<void> startMapHeartbeat({
    int? conductorId,
    bool ensureService = true,
  }) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    if (ensureService) {
      await _ensureRunning();
    } else {
      final running = await isServiceRunning();
      if (!running) {
        AppLogger.w(
          '📍 [BG] Heartbeat omitido: FGS no estaba caliente. '
          'Debe prepararse en primer plano al iniciar turno.',
          tag: 'BackgroundLocation',
        );
        return;
      }
    }
    _service.invoke('startMapHeartbeat', {
      'conductorId': ?conductorId,
    });
  }

  /// Pausa el timer de mapa al volver al foreground; el FGS sigue activo.
  static Future<void> pauseMapHeartbeat() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    if (!await isServiceRunning()) return;
    _service.invoke('pauseMapHeartbeat');
  }

  /// Detiene por completo el FGS de mapa (fin de turno).
  static Future<void> stopMapHeartbeat() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    if (!await isServiceRunning()) return;
    _service.invoke('stopMapHeartbeat');
  }

  static Future<void> stopTracking() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    _service.invoke('stopTracking');
  }
}
