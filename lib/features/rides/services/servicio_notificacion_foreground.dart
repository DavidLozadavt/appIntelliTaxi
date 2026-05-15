import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intellitaxi/core/services/app_logger.dart';
import 'package:permission_handler/permission_handler.dart';

/// Servicio para manejar notificaciones foreground persistentes
/// Muestra un widget/notificación persistente cuando hay un servicio activo
class ServicioNotificacionForeground {
  static final ServicioNotificacionForeground _instance =
      ServicioNotificacionForeground._internal();
  factory ServicioNotificacionForeground() => _instance;
  ServicioNotificacionForeground._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  final bool _enabled = true;

  /// Inicializa el servicio de notificaciones
  Future<void> inicializar() async {
    if (!_enabled) return;
    if (_initialized) return;

    try {
      // Configuración Android
      const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');

      // Configuración iOS
      const iosInit = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: false,
      );

      const initSettings = InitializationSettings(
        android: androidInit,
        iOS: iosInit,
      );

      await _notificationsPlugin.initialize(settings: initSettings);
      await _requestPermissionsIfNeeded();

      _initialized = true;
      AppLogger.d('✅ Servicio de notificaciones foreground inicializado');
    } catch (e) {
      AppLogger.d('⚠️ Error inicializando notificaciones foreground: $e');
    }
  }

  Future<void> _requestPermissionsIfNeeded() async {
    try {
      if (kIsWeb) return;

      if (defaultTargetPlatform == TargetPlatform.android) {
        final status = await Permission.notification.status;
        if (!status.isGranted) {
          await Permission.notification.request();
        }
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        await _notificationsPlugin
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >()
            ?.requestPermissions(alert: true, badge: true, sound: false);
      }
    } catch (e) {
      AppLogger.d('⚠️ Error solicitando permisos de notificación: $e');
    }
  }

  /// Muestra notificación persistente para conductor
  Future<void> mostrarNotificacionConductor({
    required int servicioId,
    required String estado,
    required String origen,
    required String destino,
  }) async {
    if (!_enabled) return;
    if (!_initialized) await inicializar();

    try {
      final estadoTexto = _getEstadoTextoConductor(estado);

      final androidDetails = AndroidNotificationDetails(
        'servicio_conductor_channel',
        'Servicio Activo Conductor',
        channelDescription:
            'Notificación persistente durante servicio activo como conductor',
        importance: Importance.high,
        priority: Priority.high,
        ongoing: true, // Notificación persistente
        autoCancel: false,
        showWhen: true,
        icon: '@mipmap/ic_launcher',
        largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
        styleInformation: BigTextStyleInformation(
          '$estadoTexto\n📍 $destino',
          htmlFormatBigText: true,
          contentTitle: '🚗 Servicio en Curso #$servicioId',
          htmlFormatContentTitle: true,
        ),
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: false,
      );

      final details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _notificationsPlugin.show(
        id: servicioId,
        title: '🚗 Servicio en Curso #$servicioId',
        body: '$estadoTexto - $destino',
        notificationDetails: details,
      );

      AppLogger.d('✅ Notificación conductor mostrada: Servicio #$servicioId');
    } catch (e) {
      AppLogger.d('⚠️ Error mostrando notificación conductor: $e');
    }
  }

  /// Muestra notificación persistente para pasajero
  Future<void> mostrarNotificacionPasajero({
    required int servicioId,
    required String estado,
    String? conductorNombre,
    String? vehiculoInfo,
    required String destino,
  }) async {
    if (!_enabled) return;
    if (!_initialized) await inicializar();

    try {
      final estadoTexto = _getEstadoTextoPasajero(estado);
      String infoExtra = conductorNombre != null
          ? '\n👤 Conductor: $conductorNombre'
          : '';
      if (vehiculoInfo != null) {
        infoExtra += '\n🚗 Vehículo: $vehiculoInfo';
      }

      final androidDetails = AndroidNotificationDetails(
        'servicio_pasajero_channel',
        'Servicio Activo Pasajero',
        channelDescription:
            'Notificación persistente durante servicio activo como pasajero',
        importance: Importance.high,
        priority: Priority.high,
        ongoing: true, // Notificación persistente
        autoCancel: false,
        showWhen: true,
        icon: '@mipmap/ic_launcher',
        largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
        styleInformation: BigTextStyleInformation(
          '$estadoTexto$infoExtra\n📍 $destino',
          htmlFormatBigText: true,
          contentTitle: '🚕 Tu Viaje #$servicioId',
          htmlFormatContentTitle: true,
        ),
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: false,
      );

      final details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _notificationsPlugin.show(
        id: servicioId + 10000, // Offset para diferenciar de conductor
        title: '🚕 Tu Viaje #$servicioId',
        body: '$estadoTexto - $destino',
        notificationDetails: details,
      );

      AppLogger.d('✅ Notificación pasajero mostrada: Servicio #$servicioId');
    } catch (e) {
      AppLogger.d('⚠️ Error mostrando notificación pasajero: $e');
    }
  }

  /// Actualiza la notificación existente
  Future<void> actualizarNotificacion({
    required int servicioId,
    required String tipo, // 'conductor' o 'pasajero'
    required String estado,
    String? conductorNombre,
    String? vehiculoInfo,
    required String origen,
    required String destino,
  }) async {
    if (!_enabled) return;
    if (tipo == 'conductor') {
      await mostrarNotificacionConductor(
        servicioId: servicioId,
        estado: estado,
        origen: origen,
        destino: destino,
      );
    } else {
      await mostrarNotificacionPasajero(
        servicioId: servicioId,
        estado: estado,
        conductorNombre: conductorNombre,
        vehiculoInfo: vehiculoInfo,
        destino: destino,
      );
    }
  }

  /// Cancela la notificación persistente
  Future<void> cancelarNotificacion(
    int servicioId, {
    String tipo = 'conductor',
  }) async {
    if (!_enabled) return;
    try {
      final notificationId = tipo == 'conductor'
          ? servicioId
          : servicioId + 10000;
      await _notificationsPlugin.cancel(id: notificationId);
      AppLogger.d('✅ Notificación cancelada: Servicio #$servicioId');
    } catch (e) {
      AppLogger.d('⚠️ Error cancelando notificación: $e');
    }
  }

  /// Cancela todas las notificaciones
  Future<void> cancelarTodasLasNotificaciones() async {
    if (!_enabled) return;
    try {
      await _notificationsPlugin.cancelAll();
      AppLogger.d('✅ Todas las notificaciones canceladas');
    } catch (e) {
      AppLogger.d('⚠️ Error cancelando notificaciones: $e');
    }
  }

  String _getEstadoTextoConductor(String estado) {
    switch (estado) {
      case 'aceptado':
      case 'en_camino':
        return '🚗 Yendo al punto de recogida';
      case 'llegue':
        return '⏳ Esperando pasajero';
      case 'en_curso':
        return '🚀 Viaje en curso';
      default:
        return 'Servicio activo';
    }
  }

  String _getEstadoTextoPasajero(String estado) {
    switch (estado) {
      case 'buscando':
        return '🔍 Buscando conductor';
      case 'aceptado':
      case 'en_camino':
        return '🚗 Conductor en camino';
      case 'llegue':
        return '📍 Conductor ha llegado';
      case 'en_curso':
        return '🚀 Viaje en curso';
      default:
        return 'Servicio activo';
    }
  }
}
