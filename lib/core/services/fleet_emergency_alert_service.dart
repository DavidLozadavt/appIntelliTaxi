import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intellitaxi/core/services/app_logger.dart';
import 'package:intellitaxi/core/services/reverse_geocoding_service.dart';
import 'package:intellitaxi/features/emergencias/data/emergencia_model.dart';
import 'package:intellitaxi/features/emergencias/providers/emergencia_provider.dart';
import 'package:intellitaxi/main.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

/// Alertas a la flota: Pusher `emergencia.activa` / FCM `tipo=emergencia`.
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
    await _plugin.initialize(
      settings: const InitializationSettings(android: androidInit),
    );

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

      final model = EmergenciaModel.fromJson(map);
      await _syncProvider(model);
      await _showAlert(model);
    } catch (e, st) {
      AppLogger.e(
        'Error procesando emergencia de flota',
        tag: 'FleetEmergency',
        error: e,
        stackTrace: st,
      );
    }
  }

  Future<void> handleFinalizada(dynamic data) async {
    try {
      final map = _parsePayload(data);
      final id = EmergenciaModel.fromJson(map).id;
      if (id <= 0) return;
      _syncFinalizada(id);
      await dismiss();
    } catch (e) {
      AppLogger.d('⚠️ handleFinalizada: $e');
    }
  }

  Future<void> dismiss() async {
    try {
      await ensureInitialized();
      await _plugin.cancel(id: notificationId);
    } catch (_) {}
  }

  Future<void> _syncProvider(EmergenciaModel model) async {
    final ctx = navigatorKey.currentContext;
    if (ctx == null || !ctx.mounted) return;
    ctx.read<EmergenciaProvider>().registrarEmergenciaRemota(
      _parsePayload(model),
    );
  }

  void _syncFinalizada(int id) {
    final ctx = navigatorKey.currentContext;
    if (ctx == null || !ctx.mounted) return;
    ctx.read<EmergenciaProvider>().finalizarEmergenciaRemota(id);
  }

  Map<String, dynamic> _parsePayload(dynamic data) {
    if (data is EmergenciaModel) {
      return {
        'id': data.id,
        'lat': data.lat,
        'lng': data.lng,
        'direccion_completa': data.direccionCompleta,
        'barrio': data.barrio,
        'maps_url': data.mapsUrl,
        'conductor_telefono': data.conductorTelefono,
        'conductor_nombre': data.conductorNombre,
        'placa': data.placa,
        'mensaje': data.mensaje,
      };
    }
    if (data is String) {
      try {
        final decoded = jsonDecode(data);
        if (decoded is Map) {
          final map = Map<String, dynamic>.from(decoded);
          if (map['data'] is Map) {
            return Map<String, dynamic>.from(map['data'] as Map);
          }
          return map;
        }
      } catch (_) {
        return {};
      }
    }
    if (data is Map<String, dynamic>) {
      if (data['data'] is Map) {
        return Map<String, dynamic>.from(data['data'] as Map);
      }
      return data;
    }
    if (data is Map) return Map<String, dynamic>.from(data);
    return {};
  }

  Future<EmergenciaModel> _enrichIfNeeded(EmergenciaModel model) async {
    if (model.direccionCompleta != null &&
        model.direccionCompleta!.trim().isNotEmpty) {
      return model;
    }
    final lat = model.lat;
    final lng = model.lng;
    if (lat == 0 && lng == 0) return model;

    final barrio = await _geocoding.resolveAreaName(lat: lat, lng: lng);
    final label = await _geocoding.resolveCurrentLocationLabel(
      lat: lat,
      lng: lng,
    );
    final direccion = [
      if (barrio != null && barrio.isNotEmpty) barrio,
      label.address,
    ].where((e) => e.isNotEmpty).join(' · ');

    return EmergenciaModel(
      id: model.id,
      idConductor: model.idConductor,
      lat: lat,
      lng: lng,
      tipo: model.tipo,
      estado: model.estado,
      direccionCompleta: direccion.isNotEmpty ? direccion : model.direccionCompleta,
      barrio: barrio ?? model.barrio,
      mapsUrl: model.mapsUrl,
      conductorTelefono: model.conductorTelefono,
      conductorNombre: model.conductorNombre,
      placa: model.placa,
      mensaje: model.mensaje,
    );
  }

  Future<void> _showAlert(EmergenciaModel raw) async {
    final model = await _enrichIfNeeded(raw);
    await _showNotification(model);
    _showInAppDialog(model);
  }

  Future<void> _showNotification(EmergenciaModel model) async {
    await ensureInitialized();
    final placa = model.placa;
    final title = placa != null && placa.isNotEmpty
        ? '🆘 Emergencia · $placa'
        : '🆘 Conductor necesita apoyo';
    final body = model.tituloUbicacion;

    final payload = jsonEncode({
      'tipo': 'emergencia',
      'id': model.id,
      'lat': model.lat,
      'lng': model.lng,
      'maps_url': model.urlMaps,
      'direccion_completa': model.direccionCompleta,
    });

    final androidDetails = AndroidNotificationDetails(
      channelId,
      'Emergencias de flota',
      channelDescription: 'Alertas de emergencia entre conductores',
      importance: Importance.max,
      priority: Priority.max,
      category: AndroidNotificationCategory.alarm,
      fullScreenIntent: _isAndroid,
      styleInformation: BigTextStyleInformation(
        model.subtituloUbicacion.isNotEmpty
            ? '${model.tituloUbicacion}\n${model.subtituloUbicacion}'
            : model.tituloUbicacion,
        contentTitle: title,
      ),
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

  void _showInAppDialog(EmergenciaModel model) {
    final context = navigatorKey.currentContext;
    if (context == null || !context.mounted) return;

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
              if (model.placa != null && model.placa!.isNotEmpty)
                Text(
                  'Vehículo ${model.placa}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              if (model.conductorNombre != null &&
                  model.conductorNombre!.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  model.conductorNombre!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade700),
                ),
              ],
              const SizedBox(height: 14),
              Text(
                model.tituloUbicacion,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  height: 1.2,
                ),
              ),
              if (model.subtituloUbicacion.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  model.subtituloUbicacion,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade700,
                  ),
                ),
              ],
              if (model.mensaje != null && model.mensaje!.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  model.mensaje!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontStyle: FontStyle.italic),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cerrar'),
            ),
            if (model.conductorTelefono != null &&
                model.conductorTelefono!.trim().isNotEmpty)
              TextButton.icon(
                onPressed: () async {
                  final tel = model.conductorTelefono!.replaceAll(
                    RegExp(r'[^\d+]'),
                    '',
                  );
                  final uri = Uri.parse('tel:$tel');
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri);
                  }
                },
                icon: const Icon(Icons.phone),
                label: const Text('Llamar'),
              ),
            FilledButton.icon(
              onPressed: () async {
                final uri = Uri.parse(model.urlMaps);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
              icon: const Icon(Icons.navigation),
              label: const Text('Ir'),
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
            ),
          ],
        );
      },
    );
  }
}
