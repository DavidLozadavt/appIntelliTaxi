import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intellitaxi/config/app_config.dart';
import 'package:intellitaxi/core/network/mobile_network_config.dart';
import 'package:intellitaxi/core/perf/runtime_perf_flags.dart';
import 'package:intellitaxi/core/services/location_tracking_config.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Entry point del isolate de segundo plano (requerido por flutter_background_service).
@pragma('vm:entry-point')
Future<void> backgroundLocationOnStart(ServiceInstance service) async {
  Timer? timer;
  int? servicioId;
  int? conductorId;
  Position? lastPosition;
  String? authToken;
  Dio? dio;

  if (service is AndroidServiceInstance) {
    service.setAsForegroundService();
    service.setForegroundNotificationInfo(
      title: 'IntelliTaxi en servicio',
      content: 'Seguimiento de ubicacion activo',
    );
  }

  Future<void> sendLocation() async {
    if (servicioId == null || conductorId == null) return;

    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 12),
        ),
      );

      if (lastPosition != null) {
        final moved = Geolocator.distanceBetween(
          lastPosition!.latitude,
          lastPosition!.longitude,
          position.latitude,
          position.longitude,
        );
        if (moved < LocationTrackingConfig.minDistanceMeters &&
            position.speed < 0.8) {
          return;
        }
      }

      if (authToken == null || authToken!.isEmpty) {
        final prefs = await SharedPreferences.getInstance();
        authToken = prefs.getString('token');
      }
      if (authToken == null || authToken!.isEmpty) return;

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

      final dioClient = dio;
      if (dioClient == null) return;

      await dioClient.post(
        'servicios/actualizar-ubicacion',
        data: {
          'servicio_id': servicioId,
          'conductor_id': conductorId,
          'lat': position.latitude,
          'lng': position.longitude,
          'velocidad': position.speed,
          'direccion': position.heading,
          'bg': true,
        },
      );

      lastPosition = position;

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

    timer?.cancel();
    await sendLocation();
    timer = Timer.periodic(
      Duration(
        seconds: RuntimePerfFlags.backgroundLocationIntervalSeconds,
      ),
      (_) => sendLocation(),
    );
  });

  service.on('stopTracking').listen((event) async {
    timer?.cancel();
    timer = null;
    servicioId = null;
    conductorId = null;
    lastPosition = null;
    authToken = null;
    dio = null;
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

  static Future<void> startTracking({
    required int servicioId,
    required int conductorId,
  }) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    if (!_initialized) {
      await initialize();
    }

    final isRunning = await _service.isRunning();
    if (!isRunning) {
      await _service.startService();
    }

    _service.invoke('startTracking', {
      'servicioId': servicioId,
      'conductorId': conductorId,
    });
  }

  static Future<void> stopTracking() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    _service.invoke('stopTracking');
  }
}
