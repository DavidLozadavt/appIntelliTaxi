import 'dart:async' show unawaited;
import 'dart:convert';
import 'dart:io';
import 'package:intellitaxi/core/services/fleet_emergency_alert_service.dart';
import 'package:intellitaxi/core/services/incoming_service_notification_service.dart';
import 'package:intellitaxi/features/app_update/services/app_update_service.dart';
import 'package:intellitaxi/core/theme/app_colors.dart';
import 'package:intellitaxi/main.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intellitaxi/core/services/app_logger.dart';

/// Payload `data` de FCM taxi (backend: FCMServiceIntelliTaxi).
bool _isTaxiServiceNotificationData(Map<String, dynamic> data) {
  final route = data['route']?.toString().toLowerCase().trim() ?? '';
  if (route == 'servicio') return true;
  final tipo = data['tipo']?.toString().toLowerCase() ?? '';
  if (tipo.contains('nueva_solicitud_servicio')) return true;
  if (tipo.contains('servicio_asignado')) return true;
  return false;
}

bool _isCalificacionNotificationData(Map<String, dynamic> data) {
  final tipo = data['tipo']?.toString().toLowerCase() ?? '';
  return tipo.contains('calificacion');
}

bool _isAppUpdateNotificationData(Map<String, dynamic> data) {
  final type = data['type']?.toString().toLowerCase().trim() ?? '';
  final tipo = data['tipo']?.toString().toLowerCase().trim() ?? '';
  return type == 'app_update' || tipo == 'app_update';
}

bool _isFleetEmergencyNotificationData(Map<String, dynamic> data) {
  final tipo = data['tipo']?.toString().toLowerCase() ?? '';
  final route = data['route']?.toString().toLowerCase() ?? '';
  return tipo.contains('emergencia') || route.contains('emergencia');
}

void navigateFromFcmData(Map<String, dynamic>? data) {
  if (data == null || data.isEmpty) {
    AppLogger.d('📱 FCM sin data; fallback chat');
    navigatorKey.currentState?.pushNamed('/chat');
    return;
  }
  if (_isAppUpdateNotificationData(data)) {
    AppLogger.d('⬆️ FCM → actualización de app');
    AppUpdateService.instance.handlePushData(data);
    return;
  }
  if (_isCalificacionNotificationData(data)) {
    AppLogger.d('🔔 FCM → notificaciones (calificación)');
    navigatorKey.currentState?.pushNamed('/notifications');
    return;
  }
  if (_isFleetEmergencyNotificationData(data)) {
    AppLogger.d('🆘 FCM → emergencia de flota');
    unawaited(FleetEmergencyAlertService.instance.handlePayload(data));
    navigatorKey.currentState?.pushNamed('/home');
    return;
  }
  if (_isTaxiServiceNotificationData(data)) {
    AppLogger.d('🚕 FCM → inicio (solicitud / servicio taxi)');
    IncomingServiceNotificationService.instance.bringAppToForeground();
    return;
  }
  AppLogger.d('📱 FCM tipo no taxi; fallback chat');
  navigatorKey.currentState?.pushNamed('/chat');
}

/// Parsea payload de notificación local (JSON) o heurística si era `Map.toString()`.
Map<String, dynamic>? _parseNotificationPayloadString(String? payload) {
  if (payload == null || payload.trim().isEmpty) return null;
  try {
    final decoded = jsonDecode(payload);
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
  } catch (_) {}
  final tipo = RegExp(
    r'''tipo['"]?\s*[:=]\s*['"]?([^,'"}\s]+)''',
  ).firstMatch(payload)?.group(1);
  final route = RegExp(
    r'''route['"]?\s*[:=]\s*['"]?([^,'"}\s]+)''',
  ).firstMatch(payload)?.group(1);
  final sid = RegExp(
    r'''servicio_id['"]?\s*[:=]\s*['"]?([^,'"}\s]+)''',
  ).firstMatch(payload)?.group(1);
  if (tipo != null || route != null || sid != null) {
    final parsedData = <String, dynamic>{};
    if (tipo != null) parsedData['tipo'] = tipo;
    if (route != null) parsedData['route'] = route;
    if (sid != null) parsedData['servicio_id'] = sid;
    return parsedData;
  }
  return null;
}

void onNotificationTap(NotificationResponse notificationResponse) {
  final payload = notificationResponse.payload;
  AppLogger.d('📱 Notificación tocada. Payload: $payload');

  final data = _parseNotificationPayloadString(payload);
  if (data != null) {
    navigateFromFcmData(data);
    return;
  }

  if (payload != null &&
      (payload.contains('nueva_solicitud_servicio') ||
          payload.contains('servicio_asignado') ||
          payload.contains("'route': servicio") ||
          payload.contains('"route":"servicio"'))) {
    navigateFromFcmData({'tipo': 'nueva_solicitud_servicio'});
    return;
  }

  if (payload != null &&
      (payload.contains('calificacion') || payload.contains('CALIFICACION'))) {
    navigatorKey.currentState?.pushNamed('/notifications');
    return;
  }

  navigatorKey.currentState?.pushNamed('/chat');
}

@pragma('vm:entry-point')
Future<void> _handleBackgroundNotification(RemoteMessage message) async {
  AppLogger.d('Notificación en segundo plano: ${message.notification?.title}');
  final data = message.data;
  if (data.isEmpty) return;
  final map = Map<String, dynamic>.from(data);
  if (_isFleetEmergencyNotificationData(map)) {
    await FleetEmergencyAlertService.instance.handlePayload(map);
  } else if (_isTaxiServiceNotificationData(map)) {
    await IncomingServiceNotificationService.instance.showIncomingService(map);
  }
}

class FirebaseMsg {
  final FirebaseMessaging msgService = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin localNotifications =
      FlutterLocalNotificationsPlugin();

  Future<void> initFCM({bool requestPermissionOnStart = false}) async {
    if (requestPermissionOnStart) {
      await requestUserPermissionIfNeeded();
    }
    await _setupLocalNotifications();
    await _setupTokenHandling(); // 🔹 importante: await

    FirebaseMessaging.onMessage.listen(_handleForegroundNotification);

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      AppLogger.d(
        'Notificación abierta desde segundo plano: ${message.notification?.title}',
      );
      AppLogger.d('Data: ${message.data}');
      navigateFromFcmData(
        message.data.isEmpty ? null : Map<String, dynamic>.from(message.data),
      );
    });

    _handleTerminatedStateNotification();
  }

  Future<void> requestUserPermissionIfNeeded() async {
    // En Android 13+ pedir este permiso al arranque causa congelones percibidos.
    // Se recomienda pedirlo desde una acción explícita del usuario.
    if (Platform.isAndroid) return;
    await msgService.requestPermission(alert: true, badge: true, sound: true);
  }

  Future<void> _handleTerminatedStateNotification() async {
    RemoteMessage? initialMessage = await FirebaseMessaging.instance
        .getInitialMessage();
    if (initialMessage != null) {
      AppLogger.d(
        'App abierta desde estado terminado por notificación: ${initialMessage.notification?.title}',
      );
      AppLogger.d('Data: ${initialMessage.data}');
      navigateFromFcmData(
        initialMessage.data.isEmpty
            ? null
            : Map<String, dynamic>.from(initialMessage.data),
      );
    }
  }

  Future<void> _setupTokenHandling() async {
    try {
      if (Platform.isIOS) {
        final apnsToken = await msgService.getAPNSToken();
        if (apnsToken == null) {
          AppLogger.w(
            'No hay APNs token (simulador iOS). Continuando sin APNs.',
            tag: 'FCM',
          );
          // 👉 Asignamos token simulado directamente
          AppLogger.i('Token FCM: SIMULATOR_FAKE_TOKEN', tag: 'FCM');
          return;
        }
      }

      // ✅ Android o dispositivo físico iOS
      final token = await msgService.getToken();
      if (token != null) {
        AppLogger.i('Token FCM: $token', tag: 'FCM');
      } else {
        AppLogger.w(
          'No se pudo obtener el token FCM, asignando token simulado',
          tag: 'FCM',
        );
        AppLogger.i('Token FCM: SIMULATOR_FAKE_TOKEN', tag: 'FCM');
      }
    } catch (e) {
      // ⚠️ En simulador puede lanzar apns-token-not-set: lo manejamos y seguimos
      if (e.toString().contains('apns-token-not-set')) {
        AppLogger.w(
          'Simulador iOS sin APNs. Usando token simulado.',
          tag: 'FCM',
        );
        AppLogger.i('Token FCM: SIMULATOR_FAKE_TOKEN', tag: 'FCM');
      } else {
        AppLogger.e(
          'Error inesperado obteniendo token FCM',
          tag: 'FCM',
          error: e,
        );
      }
    }
  }

  Future<void> _setupLocalNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    final DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        );

    final InitializationSettings initializationSettings =
        InitializationSettings(
          android: initializationSettingsAndroid,
          iOS: initializationSettingsDarwin,
        );

    await localNotifications.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: onNotificationTap,
      onDidReceiveBackgroundNotificationResponse: onNotificationTap,
    );

    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'high_importance_channel',
      'Notificaciones importantes',
      description: 'Canal para notificaciones importantes',
      importance: Importance.high,
      playSound: true,
    );

    await localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);

    await localNotifications
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, badge: true, sound: true);
  }

  Future<void> _handleForegroundNotification(RemoteMessage message) async {
    AppLogger.d('Notificación en primer plano: ${message.notification}');
    final data = Map<String, dynamic>.from(message.data);
    if (_isAppUpdateNotificationData(data)) {
      await AppUpdateService.instance.handlePushData(data);
      return;
    }
    if (_isFleetEmergencyNotificationData(data)) {
      await FleetEmergencyAlertService.instance.handlePayload(data);
      return;
    }
    if (_isTaxiServiceNotificationData(data)) {
      await IncomingServiceNotificationService.instance.showIncomingService(
        data,
      );
      return;
    }
    await _showNotification(message);
  }

  Future<void> _showNotification(RemoteMessage message) async {
    final bigTextStyle = BigTextStyleInformation(
      message.notification?.body ?? '',
      htmlFormatBigText: true,
      contentTitle: message.notification?.title,
      htmlFormatContentTitle: true,
    );

    final androidDetails = AndroidNotificationDetails(
      'high_importance_channel',
      'Notificaciones importantes',
      channelDescription: 'Canal para mensajes prioritarios',
      importance: Importance.max,
      priority: Priority.max,
      styleInformation: bigTextStyle,
      color: AppColors.accent,
      largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
    );

    final payload = jsonEncode(message.data);

    await localNotifications.show(
      id: 0,
      title: message.notification?.title,
      body: message.notification?.body,
      notificationDetails: NotificationDetails(android: androidDetails),
      payload: payload,
    );
  }
}
