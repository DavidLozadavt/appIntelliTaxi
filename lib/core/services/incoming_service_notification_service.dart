import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intellitaxi/core/services/app_logger.dart';
import 'package:intellitaxi/core/theme/app_colors.dart';
import 'package:intellitaxi/features/conductor/utils/solicitud_display_helper.dart';
import 'package:intellitaxi/main.dart';

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
      );
      await _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(channel);
    }

    _initialized = true;
  }

  Future<void> showIncomingService(Map<String, dynamic> solicitud) async {
    try {
      await ensureInitialized();

      final title = SolicitudDisplayHelper.notificationTitle(solicitud);
      final body = SolicitudDisplayHelper.notificationBody(solicitud);
      final payload = jsonEncode({
        'tipo': 'nueva_solicitud_servicio',
        'route': 'servicio',
        'solicitud_id': solicitud['solicitud_id'] ?? solicitud['id'],
      });

      final androidDetails = AndroidNotificationDetails(
        channelId,
        'Servicios entrantes',
        channelDescription: 'Nuevas solicitudes para conductores',
        importance: Importance.max,
        priority: Priority.max,
        category: AndroidNotificationCategory.call,
        visibility: NotificationVisibility.public,
        fullScreenIntent: _isAndroid,
        ongoing: false,
        autoCancel: true,
        color: AppColors.accent,
        styleInformation: BigTextStyleInformation(
          body,
          contentTitle: title,
          summaryText: SolicitudDisplayHelper.barrioFromPayload(solicitud),
        ),
        ticker: 'Nuevo servicio',
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
  void bringAppToForeground() {
    final nav = navigatorKey.currentState;
    if (nav == null) return;
    nav.pushNamedAndRemoveUntil('/home', (route) => false);
  }
}
