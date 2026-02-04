import 'dart:io';
import 'package:intellitaxi/core/theme/app_colors.dart';
import 'package:intellitaxi/main.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

void onNotificationTap(NotificationResponse notificationResponse) {
  navigatorKey.currentState?.pushNamed('/chat');
}

@pragma('vm:entry-point')
Future<void> _handleBackgroundNotification(RemoteMessage message) async {
  print('Notificación en segundo plano: ${message.notification?.title}');
}

class FirebaseMsg {
  final FirebaseMessaging msgService = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin localNotifications = FlutterLocalNotificationsPlugin();

  Future<void> initFCM() async {
    await msgService.requestPermission(alert: true, badge: true, sound: true);
    await _setupLocalNotifications();
    await _setupTokenHandling(); // 🔹 importante: await

    FirebaseMessaging.onMessage.listen(_handleForegroundNotification);

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('Notificación abierta desde segundo plano: ${message.notification?.title}');
      navigatorKey.currentState?.pushNamed('/chat');
    });

    _handleTerminatedStateNotification();
  }

  Future<void> _handleTerminatedStateNotification() async {
    RemoteMessage? initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      print('App abierta desde estado terminado por notificación: ${initialMessage.notification?.title}');
      navigatorKey.currentState?.pushNamed('/chat');
    }
  }

Future<void> _setupTokenHandling() async {
  try {
    if (Platform.isIOS) {
      final apnsToken = await msgService.getAPNSToken();
      if (apnsToken == null) {
        debugPrint('⚠️ No hay APNs token (simulador iOS). Continuando sin APNs.');
        // 👉 Asignamos token simulado directamente
        debugPrint("✅ Token FCM: SIMULATOR_FAKE_TOKEN");
        return;
      }
    }

    // ✅ Android o dispositivo físico iOS
    final token = await msgService.getToken();
    if (token != null) {
      debugPrint("✅ Token FCM: $token");
    } else {
      debugPrint("⚠️ No se pudo obtener el token FCM, asignando token simulado");
      debugPrint("✅ Token FCM: SIMULATOR_FAKE_TOKEN");
    }
  } catch (e) {
    // ⚠️ En simulador puede lanzar apns-token-not-set: lo manejamos y seguimos
    if (e.toString().contains('apns-token-not-set')) {
      debugPrint("⚠️ Simulador iOS sin APNs. Usando token simulado.");
      debugPrint("✅ Token FCM: SIMULATOR_FAKE_TOKEN");
    } else {
      debugPrint('🔥 Error inesperado obteniendo token FCM: $e');
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

    final InitializationSettings initializationSettings = InitializationSettings(
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
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    await localNotifications
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
  }

  Future<void> _handleForegroundNotification(RemoteMessage message) async {
    print('Notificación en primer plano: ${message.notification}');
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

    await localNotifications.show(
      id: 0,
      title: message.notification?.title,
      body: message.notification?.body,
      notificationDetails: NotificationDetails(android: androidDetails),
      payload: message.data.toString(),
    );
  }
}
  