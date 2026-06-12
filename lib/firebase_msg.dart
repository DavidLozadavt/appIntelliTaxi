import 'dart:async' show unawaited;
import 'dart:convert';
import 'dart:io';
import 'package:intellitaxi/core/services/fleet_emergency_alert_service.dart';
import 'package:intellitaxi/core/services/incoming_app_launch_helper.dart';
import 'package:intellitaxi/core/services/incoming_service_notification_service.dart';
import 'package:intellitaxi/core/services/pasajero_servicio_notification_helper.dart';
import 'package:intellitaxi/features/chat/services/chat_realtime_bridge.dart';
import 'package:intellitaxi/features/chat/utils/chat_notification_navigation.dart';
import 'package:intellitaxi/features/app_update/services/app_update_service.dart';
import 'package:intellitaxi/features/conductor/providers/conductor_home_provider.dart';
import 'package:intellitaxi/core/theme/app_colors.dart';
import 'package:intellitaxi/main.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intellitaxi/core/services/active_service_screen_registry.dart';
import 'package:intellitaxi/core/services/app_logger.dart';
import 'package:intellitaxi/core/utils/json_payload_helper.dart';
import 'package:intellitaxi/core/services/device_token_sync_service.dart';
import 'package:intellitaxi/core/services/fcm_session_guard.dart';
import 'package:intellitaxi/core/services/fcm_token_resolver.dart';
import 'package:intellitaxi/core/utils/app_lifecycle_helper.dart';
import 'package:intellitaxi/features/conductor/utils/conductor_overlay_badge_store.dart';
import 'package:intellitaxi/features/conductor/utils/conductor_pending_fcm.dart';
import 'package:intellitaxi/core/services/driver_overlay_service.dart';
import 'package:intellitaxi/features/conductor/utils/conductor_solicitud_payload_helper.dart';
import 'package:intellitaxi/features/conductor/utils/conductor_socket_payload_router.dart';
import 'package:intellitaxi/features/conductor/utils/solicitud_display_helper.dart';
import 'package:provider/provider.dart';
import 'package:intellitaxi/features/conductor/utils/conductor_incoming_dedup_store.dart';
import 'package:intellitaxi/core/utils/fcm_isolate_context.dart';

Future<bool> _shouldShowConductorIncomingAlert(
  Map<String, dynamic> data,
) async {
  if (!_isConductorIncomingServiceNotification(data)) return false;
  if (_isServicioTripUpdateNotification(data)) return false;
  return FcmSessionGuard.shouldProcessConductorIncomingPush();
}

Future<void> _ignorePushIfNoSession(String origen) async {
  if (await FcmSessionGuard.hasActiveSession()) return;
  AppLogger.d('📲 FCM ignorado ($origen): sesión cerrada');
  await IncomingServiceNotificationService.instance.dismiss();
}

/// Solo alertas de cola para conductores — no cambios de estado del viaje.
bool _isConductorIncomingServiceNotification(Map<String, dynamic> data) {
  final merged = JsonPayloadHelper.parseAndMerge(data);
  final notif = ConductorSocketPayloadRouter.notificacionTipo(merged) ?? '';
  if (notif == 'exclusiva_indrive' ||
      notif == 'oferta_directa' ||
      notif == 'cercano_broadcast' ||
      notif == 'global_indrive' ||
      notif == 'fase_abierta_indrive') {
    return true;
  }
  final tipo = merged['tipo']?.toString().toLowerCase() ?? '';
  if (tipo.contains('oferta_servicio_exclusiva')) return true;
  if (tipo.contains('oferta_directa')) return true;
  if (tipo.contains('nueva_solicitud_servicio')) return true;
  if (tipo.contains('servicio_asignado')) return true;
  if (tipo.contains('nueva_solicitud') || tipo.contains('nueva-solicitud')) {
    return true;
  }
  return false;
}

/// Actualizaciones de viaje (estado, ubicación, etc.) — no son solicitudes nuevas.
bool _isServicioTripUpdateNotification(Map<String, dynamic> data) {
  final tipo = data['tipo']?.toString().toLowerCase() ?? '';
  if (tipo.contains('estado')) return true;
  if (tipo.contains('ubicacion') || tipo.contains('ubicación')) return true;
  if (tipo.contains('aceptado')) return true;
  if (tipo.contains('en_camino')) return true;
  if (tipo.contains('llegue') || tipo.contains('llegó')) return true;
  if (tipo.contains('en_curso')) return true;
  if (tipo.contains('finalizado')) return true;
  if (tipo.contains('cancelado') || tipo.contains('servicio_cancelado')) {
    return true;
  }
  if (data.containsKey('estado') ||
      data.containsKey('estado_id') ||
      data.containsKey('id_estado') ||
      data.containsKey('idEstado')) {
    return true;
  }
  final route = data['route']?.toString().toLowerCase().trim() ?? '';
  return route == 'servicio' && !_isConductorIncomingServiceNotification(data);
}

int? _servicioIdDesdeFcm(Map<String, dynamic> data) {
  try {
    final merged = JsonPayloadHelper.parseAndMerge(data);
    final fromHelper =
        ConductorSolicitudPayloadHelper.servicioIdFromAlertaPayload(merged);
    if (fromHelper != null && fromHelper.isNotEmpty) {
      return int.tryParse(fromHelper);
    }
    return JsonPayloadHelper.parseInt(
      merged['servicio_id'] ??
          merged['servicioId'] ??
          merged['solicitud_id'] ??
          merged['id'],
    );
  } catch (_) {
    return JsonPayloadHelper.parseInt(
      data['servicio_id'] ?? data['servicioId'] ?? data['id'],
    );
  }
}

String? _solicitudIdDesdePayload(Map<String, dynamic> data) {
  final parsed = int.tryParse(_servicioIdDesdeFcm(data)?.toString() ?? '');
  if (parsed != null) return parsed.toString();
  try {
    final merged = JsonPayloadHelper.parseAndMerge(data);
    return ConductorSolicitudPayloadHelper.servicioIdFromAlertaPayload(merged) ??
        ConductorSolicitudPayloadHelper.obtenerSolicitudId(
          ConductorSolicitudPayloadHelper.normalizarSolicitud(
            ConductorSolicitudPayloadHelper.parsePayload(merged),
          ),
        );
  } catch (_) {
    return null;
  }
}

bool _fcmIndicaCancelacion(Map<String, dynamic> data) {
  try {
    final merged = JsonPayloadHelper.parseAndMerge(data);
    final tipo = merged['tipo']?.toString().toLowerCase() ?? '';
    if (tipo.contains('servicio_cancelado') || tipo.contains('cancelado')) {
      return true;
    }
    final estado = merged['estado']?.toString().toLowerCase() ?? '';
    if (estado.contains('cancel')) return true;
    final idEstado = JsonPayloadHelper.parseInt(
      merged['id_estado'] ?? merged['idEstado'] ?? merged['estado_id'],
    );
    return idEstado == 6;
  } catch (_) {
    final tipo = data['tipo']?.toString().toLowerCase() ?? '';
    return tipo.contains('cancelado');
  }
}

/// Une `data` del push con heurística del título/cuerpo (FCM solo-notification).
Map<String, dynamic> mergeRemoteMessageData(RemoteMessage message) {
  final data = Map<String, dynamic>.from(message.data);
  if (data.isNotEmpty) return data;

  final title = message.notification?.title ?? '';
  final body = message.notification?.body ?? '';
  final combined = '$title $body'.toLowerCase();
  if (combined.contains('solicitud') ||
      combined.contains('servicio') ||
      combined.contains('taxbel')) {
    return {
      'tipo': 'nueva_solicitud_servicio',
      'route': 'servicio',
      if (title.isNotEmpty) 'title': title,
      if (body.isNotEmpty) 'body': body,
      'mensaje': body,
    };
  }
  return data;
}

bool _fcmEsColaEntranteEstandar(Map<String, dynamic> data) {
  if (!_isConductorIncomingServiceNotification(data)) return false;
  final merged = JsonPayloadHelper.parseAndMerge(data);
  final notif = ConductorSocketPayloadRouter.notificacionTipo(merged) ?? '';
  if (notif == 'exclusiva_indrive' ||
      notif == 'oferta_directa' ||
      notif.contains('exclusiva')) {
    return false;
  }
  if (ConductorSocketPayloadRouter.requiereOverlayFullscreen(merged)) {
    return false;
  }
  return true;
}

/// Cola normal: FCM + burbuja; si la app está en segundo plano, abrir Activity.
Future<void> _notificarSolicitudConductorSinColaInApp(
  Map<String, dynamic> data, {
  bool showHeadsUp = true,
  bool showOverlay = true,
}) async {
  AppLogger.d('📲 FCM conductor: solo notificación (UI vía Pusher/sync)');
  await ConductorOverlayBadgeStore.recordIncomingFromFcm();

  if (await IncomingAppLaunchHelper.shouldAutoOpen()) {
    AppLogger.d('🚕 Abriendo app (solicitud estándar en segundo plano)');
    await IncomingAppLaunchHelper.openForIncoming(
      data: data,
      showHeadsUp: showHeadsUp,
      skipNativeWake: FcmIsolateContext.isBackgroundHandler,
    );
    if (showOverlay && !FcmIsolateContext.isBackgroundHandler) {
      unawaited(DriverOverlayService.instance.showFromBadgeStore(enLinea: true));
    }
    unawaited(_triggerConductorIncomingSync(data));
    return;
  }

  if (showHeadsUp) {
    final solicitud = SolicitudDisplayHelper.normalizeSolicitudMap(
      ConductorSolicitudPayloadHelper.normalizarSolicitud(
        ConductorSolicitudPayloadHelper.parsePayload(data),
      ),
    );
    await IncomingServiceNotificationService.instance.showIncomingService(
      solicitud,
      skipNativeWake: FcmIsolateContext.isBackgroundHandler,
    );
  }
  if (showOverlay && !FcmIsolateContext.isBackgroundHandler) {
    await DriverOverlayService.instance.showFromBadgeStore(enLinea: true);
  }
}

/// Burbuja + heads-up para oferta exclusiva / directa (pantalla fullscreen).
Future<void> _alertConductorEnSegundoPlano(
  Map<String, dynamic> data, {
  bool showHeadsUp = true,
  bool showOverlay = true,
}) async {
  await ConductorOverlayBadgeStore.recordIncomingFromFcm();
  if (showHeadsUp) {
    final solicitud = SolicitudDisplayHelper.normalizeSolicitudMap(
      ConductorSolicitudPayloadHelper.normalizarSolicitud(
        ConductorSolicitudPayloadHelper.parsePayload(data),
      ),
    );
    await IncomingServiceNotificationService.instance.showIncomingService(
      solicitud,
      skipNativeWake: FcmIsolateContext.isBackgroundHandler,
    );
  }
  if (showOverlay && !FcmIsolateContext.isBackgroundHandler) {
    await DriverOverlayService.instance.showFromBadgeStore(enLinea: true);
  }
}

/// Oferta exclusiva/directa: cola FCM + sync in-app. Cola estándar: solo notificación.
Future<void> _manejarSolicitudEntranteConductor(
  Map<String, dynamic> data, {
  bool showHeadsUp = true,
  bool systemNotificationAlreadyShown = false,
}) async {
  final solicitudId = _solicitudIdDesdePayload(data);
  if (await ConductorIncomingDedupStore.shouldSkipFcmFor(solicitudId)) {
    AppLogger.d(
      '📲 FCM omitido: solicitud $solicitudId ya mostrada por realtime/push',
    );
    return;
  }

  if (systemNotificationAlreadyShown) {
    AppLogger.d(
      '📲 FCM: sistema ya mostró push, omitiendo notificación local',
    );
    await ConductorIncomingDedupStore.recordPushShown(solicitudId);
    showHeadsUp = false;
  }

  final enPrimerPlano = await AppLifecycleHelper.isInForegroundReliable();
  if (enPrimerPlano && !await AppLifecycleHelper.shouldShowIncomingServiceAlert()) {
    AppLogger.d(
      '📲 FCM omitido en primer plano (Pusher gestiona UI)',
    );
    if (solicitudId != null) {
      await ConductorIncomingDedupStore.recordRealtimeIncoming(solicitudId);
    }
    return;
  }

  if (_fcmEsColaEntranteEstandar(data)) {
    await _notificarSolicitudConductorSinColaInApp(
      data,
      showHeadsUp: showHeadsUp,
    );
    return;
  }

  await ConductorPendingFcm.enqueue(data);

  if (await IncomingAppLaunchHelper.shouldAutoOpen()) {
    AppLogger.d('🚕 Abriendo IntelliTaxi automáticamente (solicitud entrante)');
    await IncomingAppLaunchHelper.openForIncoming(
      data: data,
      showHeadsUp: showHeadsUp,
      skipNativeWake: FcmIsolateContext.isBackgroundHandler,
    );
    if (!FcmIsolateContext.isBackgroundHandler) {
      unawaited(DriverOverlayService.instance.showFromBadgeStore(enLinea: true));
    }
    unawaited(_triggerConductorIncomingSync(data));
    Future<void>.delayed(const Duration(seconds: 3), () async {
      if (AppLifecycleHelper.isInForeground()) return;
      await _alertConductorEnSegundoPlano(
        data,
        showHeadsUp: false,
        showOverlay: true,
      );
    });
    return;
  }

  unawaited(_triggerConductorIncomingSync(data));
  unawaited(_alertConductorEnSegundoPlano(data, showHeadsUp: showHeadsUp));
}

Future<void> _triggerConductorIncomingSync(Map<String, dynamic> data) async {
  await ConductorPendingFcm.enqueue(data);
  try {
    final context = navigatorKey.currentContext;
    if (context == null || !context.mounted) return;
    await context.read<ConductorHomeProvider>().procesarAlertaSolicitudEntrante(
      data,
    );
    await ConductorPendingFcm.clearAfterProcessed();
  } catch (e) {
    AppLogger.d('⚠️ FCM sync conductor fallback: $e');
  }
}

Future<void> _reconciliarConductorTrasFcmTap(Map<String, dynamic> data) async {
  try {
    final context = navigatorKey.currentContext;
    if (context == null || !context.mounted) return;
    await context.read<ConductorHomeProvider>().reconciliarTrasFcm(data: data);
  } catch (e) {
    AppLogger.d('⚠️ FCM reconciliar tap: $e');
  }
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

Future<void> navigateFromFcmData(Map<String, dynamic>? data) async {
  if (!await FcmSessionGuard.hasActiveSession()) {
    AppLogger.d('📲 FCM tap ignorado: sesión cerrada');
    return;
  }
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
  if (ChatNotificationNavigation.isChatTaxiNotification(data)) {
    AppLogger.d('💬 FCM → chat del servicio activo');
    await ChatNotificationNavigation.openFromNotification(data);
    return;
  }
  if (await _shouldShowConductorIncomingAlert(data)) {
    if (_fcmEsColaEntranteEstandar(data)) {
      AppLogger.d('🚕 FCM tap → home + GET pendientes');
      navigatorKey.currentState?.pushNamed('/home');
      await _triggerConductorIncomingSync(data);
      return;
    }
    AppLogger.d('🚕 FCM → solicitud entrante (conductor)');
    await _manejarSolicitudEntranteConductor(data);
    await _reconciliarConductorTrasFcmTap(data);
    return;
  }
  if (_isServicioTripUpdateNotification(data)) {
    AppLogger.d('🚕 FCM → actualización de viaje');
    await IncomingServiceNotificationService.instance.dismiss();
    final sid = _servicioIdDesdeFcm(data);
    final handled = sid != null &&
        _fcmIndicaCancelacion(data) &&
        ActiveServiceScreenRegistry.notifyRemoteTerminal(
          serviceId: sid,
          cancelado: true,
        );
    if (!handled) {
      navigatorKey.currentState?.pushNamed('/home');
    }
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
  final mensajeTipo = RegExp(
    r'''mensaje_tipo['"]?\s*[:=]\s*['"]?([^,'"}\s]+)''',
  ).firstMatch(payload)?.group(1);
  if (tipo != null || route != null || sid != null || mensajeTipo != null) {
    final parsedData = <String, dynamic>{};
    if (tipo != null) parsedData['tipo'] = tipo;
    if (route != null) parsedData['route'] = route;
    if (sid != null) parsedData['servicio_id'] = sid;
    if (mensajeTipo != null) parsedData['mensaje_tipo'] = mensajeTipo;
    return parsedData;
  }
  return null;
}

void onNotificationTap(NotificationResponse notificationResponse) {
  final payload = notificationResponse.payload;
  AppLogger.d('📱 Notificación tocada. Payload: $payload');

  final data = _parseNotificationPayloadString(payload);
  if (data != null) {
    unawaited(navigateFromFcmData(data));
    return;
  }

  if (payload != null &&
      (payload.contains('nueva_solicitud_servicio') ||
          payload.contains('servicio_asignado'))) {
    unawaited(navigateFromFcmData({'tipo': 'nueva_solicitud_servicio'}));
    return;
  }

  if (payload != null &&
      (payload.contains("'route': servicio") ||
          payload.contains('"route":"servicio"'))) {
    unawaited(navigateFromFcmData({'route': 'servicio', 'estado': 'update'}));
    return;
  }

  if (payload != null &&
      (payload.contains('calificacion') || payload.contains('CALIFICACION'))) {
    navigatorKey.currentState?.pushNamed('/notifications');
    return;
  }

  if (payload != null &&
      (payload.contains('chat_servicio') ||
          payload.contains('mensaje_tipo'))) {
    final parsed = _parseNotificationPayloadString(payload);
    if (parsed != null &&
        ChatNotificationNavigation.isChatTaxiNotification(parsed)) {
      unawaited(ChatNotificationNavigation.openFromNotification(parsed));
      return;
    }
  }

  navigatorKey.currentState?.pushNamed('/home');
}

/// Procesa FCM con la app en segundo plano o cerrada (registrado en [main]).
Future<void> handleRemoteMessageInBackground(RemoteMessage message) async {
  AppLogger.d('Notificación en segundo plano: ${message.notification?.title}');
  if (!await FcmSessionGuard.hasActiveSession()) {
    await _ignorePushIfNoSession('background');
    return;
  }
  final map = mergeRemoteMessageData(message);
  if (map.isEmpty) return;

  if (_isFleetEmergencyNotificationData(map)) {
    await FleetEmergencyAlertService.instance.handlePayload(map);
    return;
  }

  if (await _shouldShowConductorIncomingAlert(map)) {
    await _manejarSolicitudEntranteConductor(
      map,
      showHeadsUp: true,
      systemNotificationAlreadyShown: message.notification != null,
    );
    return;
  }

  if (!await FcmSessionGuard.isActiveConductorRole() &&
      _isConductorIncomingServiceNotification(map)) {
    await IncomingServiceNotificationService.instance.dismiss();
  }
}

class FirebaseMsg {
  final FirebaseMessaging msgService = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin localNotifications =
      FlutterLocalNotificationsPlugin();

  Future<void> initFCM({bool requestPermissionOnStart = false}) async {
    DeviceTokenSyncService.instance.attachTokenRefreshListener();
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
      final data = mergeRemoteMessageData(message);
      unawaited(navigateFromFcmData(data.isEmpty ? null : data));
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
      final data = mergeRemoteMessageData(initialMessage);
      await navigateFromFcmData(data.isEmpty ? null : data);
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

      final token = await FcmTokenResolver.resolveForAuth();
      if (token != null) {
        AppLogger.i('Token FCM: $token', tag: 'FCM');
        unawaited(DeviceTokenSyncService.instance.onTokenAvailable(token));
      } else {
        AppLogger.w(
          'FCM no disponible en este dispositivo; push puede no funcionar hasta reiniciar o actualizar Play Services.',
          tag: 'FCM',
        );
        unawaited(DeviceTokenSyncService.instance.flushPendingIfNeeded());
      }
    } catch (e) {
      if (e.toString().contains('apns-token-not-set')) {
        AppLogger.w(
          'Simulador iOS sin APNs. Push desactivado en este entorno.',
          tag: 'FCM',
        );
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
    if (!await FcmSessionGuard.hasActiveSession()) {
      await _ignorePushIfNoSession('foreground');
      return;
    }
    final data = mergeRemoteMessageData(message);
    if (data.isEmpty) {
      await _showNotification(message);
      return;
    }
    if (_isAppUpdateNotificationData(data)) {
      await AppUpdateService.instance.handlePushData(data);
      return;
    }
    if (_isFleetEmergencyNotificationData(data)) {
      await FleetEmergencyAlertService.instance.handlePayload(data);
      return;
    }
    if (await _shouldShowConductorIncomingAlert(data)) {
      final headsUp = await AppLifecycleHelper.shouldShowIncomingServiceAlert();
      unawaited(
        _manejarSolicitudEntranteConductor(
          data,
          showHeadsUp: headsUp,
          systemNotificationAlreadyShown: message.notification != null,
        ),
      );
      return;
    }

    final isConductor = await FcmSessionGuard.isActiveConductorRole();

    // El pasajero no debe ver "nueva solicitud" (es eco de su propia petición).
    if (!isConductor && _isConductorIncomingServiceNotification(data)) {
      await IncomingServiceNotificationService.instance.dismiss();
      return;
    }

    // Pasajero o cambio de estado: quitar alerta de conductor si quedó activa.
    if (_isServicioTripUpdateNotification(data) || !isConductor) {
      await IncomingServiceNotificationService.instance.dismiss();
    }

    if (_isServicioTripUpdateNotification(data) && _fcmIndicaCancelacion(data)) {
      final sid = _servicioIdDesdeFcm(data);
      if (sid != null) {
        ActiveServiceScreenRegistry.notifyRemoteTerminal(
          serviceId: sid,
          cancelado: true,
        );
      }
    }

    if (ChatRealtimeBridge.tryDeliverFromPush(data)) {
      return;
    }

    await _showNotification(message);
  }

  Future<void> _showNotification(RemoteMessage message) async {
    final data = message.data;
    final title = message.notification?.title ??
        data['title']?.toString() ??
        data['titulo']?.toString();
    final body = message.notification?.body ??
        data['body']?.toString() ??
        data['mensaje']?.toString() ??
        data['message']?.toString();

    if ((title == null || title.isEmpty) && (body == null || body.isEmpty)) {
      return;
    }

    final bigTextStyle = BigTextStyleInformation(
      body ?? '',
      htmlFormatBigText: true,
      contentTitle: title,
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
      autoCancel: true,
    );

    final payload = jsonEncode(message.data);
    final servicioIdRaw =
        data['servicio_id'] ?? data['servicioId'] ?? data['id_servicio'];
    final servicioId = servicioIdRaw != null
        ? int.tryParse(servicioIdRaw.toString())
        : null;
    final notificationId = servicioId != null
        ? PasajeroServicioNotificationHelper.fcmNotificationIdForServicio(
            servicioId,
          )
        : message.hashCode & 0x7FFFFFFF;

    await localNotifications.show(
      id: notificationId,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(android: androidDetails),
      payload: payload,
    );
  }
}
