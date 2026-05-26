import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intellitaxi/core/services/app_logger.dart';
import 'package:intellitaxi/core/services/reverse_geocoding_service.dart';
import 'package:intellitaxi/features/conductor/utils/solicitud_display_helper.dart';
import 'package:intellitaxi/main.dart';
import 'package:url_launcher/url_launcher.dart';

/// Alertas a la flota cuando otro conductor reporta emergencia.
class FleetEmergencyAlertService {
  FleetEmergencyAlertService._();
  static final FleetEmergencyAlertService instance =
      FleetEmergencyAlertService._();

  static const String channelId = 'fleet_emergency_channel';
  static const int notificationId = 9201;

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  final ReverseGeocodingService _geocoding = ReverseGeocodingService();
  bool _initialized = false;

  bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<void> ensureInitialized() async {
    if (_initialized) return;
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _plugin.initialize(settings: const InitializationSettings(android: androidInit));

    if (_isAndroid) {
      const channel = AndroidNotificationChannel(
        channelId,
        'Emergencias de flota',
        description: 'Apoyo urgente entre conductores',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
      );
      await _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(channel);
    }
    _initialized = true;
  }

  Future<void> handlePayload(dynamic data) async {
    try {
      final map = _parsePayload(data);
      if (map.isEmpty) return;

      final conductorId = map['idConductor'] ?? map['conductor_id'];
      final lat = SolicitudDisplayHelper.parseCoordinate(map['lat']);
      final lng = SolicitudDisplayHelper.parseCoordinate(map['lng']);
      final placa = map['placa']?.toString() ?? map['vehiculo_placa']?.toString();

      var ubicacion = map['direccion']?.toString() ??
          map['ubicacion']?.toString() ??
          map['direccion_emergencia']?.toString() ??
          '';

      if (ubicacion.trim().isEmpty && lat != null && lng != null) {
        final barrio = await _geocoding.resolveAreaName(lat: lat, lng: lng);
        final label = await _geocoding.resolveCurrentLocationLabel(
          lat: lat,
          lng: lng,
        );
        ubicacion = [
          if (barrio != null && barrio.isNotEmpty) barrio,
          label.address,
        ].where((e) => e.isNotEmpty).join(' · ');
      }

      if (ubicacion.trim().isEmpty && lat != null && lng != null) {
        ubicacion = '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}';
      }

      await _showNotification(
        conductorId: conductorId?.toString(),
        placa: placa,
        ubicacion: ubicacion,
        lat: lat,
        lng: lng,
      );
      _showInAppDialog(
        conductorId: conductorId?.toString(),
        placa: placa,
        ubicacion: ubicacion,
        lat: lat,
        lng: lng,
      );
    } catch (e, st) {
      AppLogger.e(
        'Error procesando emergencia de flota',
        tag: 'FleetEmergency',
        error: e,
        stackTrace: st,
      );
    }
  }

  Map<String, dynamic> _parsePayload(dynamic data) {
    if (data is String) {
      try {
        final decoded = jsonDecode(data);
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
      } catch (_) {
        return {};
      }
    }
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return {};
  }

  Future<void> _showNotification({
    String? conductorId,
    String? placa,
    required String ubicacion,
    double? lat,
    double? lng,
  }) async {
    await ensureInitialized();
    final title = placa != null && placa.isNotEmpty
        ? '🆘 Emergencia · $placa'
        : '🆘 Conductor necesita apoyo';
    final body = ubicacion.isNotEmpty
        ? ubicacion
        : 'Ubicación en el mapa';

    final payload = jsonEncode({
      'tipo': 'emergencia_conductor',
      'lat': lat,
      'lng': lng,
      'conductor_id': conductorId,
    });

    final androidDetails = AndroidNotificationDetails(
      channelId,
      'Emergencias de flota',
      channelDescription: 'Alertas de emergencia entre conductores',
      importance: Importance.max,
      priority: Priority.max,
      category: AndroidNotificationCategory.alarm,
      fullScreenIntent: _isAndroid,
      styleInformation: BigTextStyleInformation(body, contentTitle: title),
      color: const Color(0xFFD32F2F),
    );

    await _plugin.show(
      id: notificationId,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(android: androidDetails),
      payload: payload,
    );
  }

  void _showInAppDialog({
    String? conductorId,
    String? placa,
    required String ubicacion,
    double? lat,
    double? lng,
  }) {
    final context = navigatorKey.currentContext;
    if (context == null) return;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          icon: const Icon(Icons.emergency, color: Colors.red, size: 48),
          title: const Text(
            'Emergencia de conductor',
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (placa != null && placa.isNotEmpty)
                Text(
                  'Vehículo $placa',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              const SizedBox(height: 12),
              Text(
                ubicacion.isNotEmpty ? ubicacion : 'Ver ubicación en mapa',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              if (conductorId != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Conductor #$conductorId',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cerrar'),
            ),
            if (lat != null && lng != null)
              FilledButton.icon(
                onPressed: () async {
                  final uri = Uri.parse(
                    'https://www.google.com/maps/search/?api=1&query=$lat,$lng',
                  );
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                },
                icon: const Icon(Icons.map),
                label: const Text('Ver en mapa'),
                style: FilledButton.styleFrom(backgroundColor: Colors.red),
              ),
          ],
        );
      },
    );
  }
}
