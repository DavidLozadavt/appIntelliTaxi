import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intellitaxi/core/services/app_logger.dart';
import 'package:intellitaxi/core/theme/app_colors.dart';
import 'package:intellitaxi/features/conductor/utils/conductor_solicitud_payload_helper.dart';
import 'package:intellitaxi/features/conductor/utils/solicitud_display_helper.dart';
import 'package:intellitaxi/core/services/app_foreground_service.dart';
import 'package:intellitaxi/core/diagnostics/app_diagnostics.dart';
import 'package:intellitaxi/core/utils/device_screen_helper.dart';

/// Notificaciones de alta prioridad para nuevas solicitudes (Android: full-screen intent).
class IncomingServiceNotificationService {
  IncomingServiceNotificationService._();
  static final IncomingServiceNotificationService instance =
      IncomingServiceNotificationService._();

  static const String channelId = 'incoming_service_channel';
  static const int notificationId = 9101;

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<void> ensureInitialized() async {
    if (_initialized) return;

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);
    await _plugin.initialize(settings: initSettings);

    if (_isAndroid) {
      const channel = AndroidNotificationChannel(
        channelId,
        'Servicios entrantes',
        description: 'Alertas urgentes de nuevas solicitudes para conductores',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
        enableLights: true,
        bypassDnd: true,
      );
      final androidPlugin = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      await androidPlugin?.createNotificationChannel(channel);
    }

    _initialized = true;
  }

  /// Diálogos del sistema; llamar con app en primer plano (p. ej. [RuntimeBootstrap]).
  Future<void> requestAndroidAlertPermissions() async {
    if (!_isAndroid) return;
    AppDiagnostics.record(
      'bootstrap',
      'solicitando permisos notificación / pantalla completa',
    );
    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    try {
      await androidPlugin?.requestNotificationsPermission();
      await androidPlugin?.requestFullScreenIntentPermission();
      AppDiagnostics.record('bootstrap', 'permisos notificación / FSI listos');
    } catch (e) {
      AppLogger.d('⚠️ Permisos notificación/FSI: $e');
      AppDiagnostics.record('bootstrap', 'permisos notificación/FSI fallaron',
          extra: e.toString());
    }
  }

  Future<void> showIncomingService(Map<String, dynamic> solicitud) async {
    try {
      final id = solicitud['solicitud_id'] ?? solicitud['id'];
      AppDiagnostics.record(
        'incoming',
        'showIncomingService',
        extra: 'id=$id',
      );
      await ensureInitialized();
      await DeviceScreenHelper.wakeForIncomingService();

      final normalizada = SolicitudDisplayHelper.normalizeSolicitudMap(
        ConductorSolicitudPayloadHelper.normalizarSolicitud(solicitud),
      );
      final title = SolicitudDisplayHelper.notificationTitle(normalizada);
      final body = SolicitudDisplayHelper.notificationBody(normalizada);
      final payload = jsonEncode({
        'tipo': 'nueva_solicitud_servicio',
        'route': 'servicio',
        'solicitud_id': solicitud['solicitud_id'] ?? solicitud['id'],
        'servicio_id': solicitud['servicio_id'] ?? solicitud['solicitud_id'],
        ...normalizada,
      });

      final androidDetails = AndroidNotificationDetails(
        channelId,
        'Servicios entrantes',
        channelDescription: 'Nuevas solicitudes para conductores',
        importance: Importance.max,
        priority: Priority.max,
        category: AndroidNotificationCategory.call,
        visibility: NotificationVisibility.public,
        fullScreenIntent: true,
        ongoing: false,
        autoCancel: true,
        playSound: true,
        enableVibration: true,
        enableLights: true,
        ticker: 'Nuevo servicio disponible',
        color: AppColors.accent,
        styleInformation: BigTextStyleInformation(
          body,
          contentTitle: title,
          summaryText: SolicitudDisplayHelper.pickupDetailForDriver(normalizada)
                  .isNotEmpty
              ? SolicitudDisplayHelper.pickupDetailForDriver(normalizada)
              : SolicitudDisplayHelper.pickupTitleForDriver(normalizada),
        ),
      );

      await _plugin.show(
        id: notificationId,
        title: title,
        body: body,
        notificationDetails: NotificationDetails(android: androidDetails),
        payload: payload,
      );

      AppLogger.d('🔔 Notificación de servicio entrante mostrada');
    } catch (e, st) {
      AppLogger.e(
        'Error mostrando notificación de servicio',
        tag: 'IncomingService',
        error: e,
        stackTrace: st,
      );
    }
  }

  /// Quita la alerta de solicitud entrante (p. ej. si llegó por error al pasajero).
  Future<void> dismiss() async {
    try {
      await ensureInitialized();
      await _plugin.cancel(id: notificationId);
    } catch (e) {
      AppLogger.d('⚠️ Error cancelando notificación de servicio entrante: $e');
    }
  }

  /// Trae la app al frente cuando el conductor toca la alerta o vuelve del overlay.
  Future<void> bringAppToForeground() =>
      AppForegroundService.instance.bringAppToForeground();
}
