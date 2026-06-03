/// Flags para reducir trabajo en debug (logs, polling, animaciones).
abstract final class RuntimePerfFlags {
  /// Logs HTTP completos (cuerpos JSON enormes bloquean el hilo en debug).
  static const bool verboseHttpLogs = false;

  /// Logs detallados de Pusher (eventos, handlers, estados).
  static const bool verbosePusherLogs = false;

  /// Log en cada request con token (muy ruidoso).
  static const bool logAuthInterceptor = false;

  /// Intervalo mínimo entre [GoogleMap] setState por marcadores (~15 fps).
  static const Duration markerSyncMinInterval = Duration(milliseconds: 66);

  /// Refresco API de conductores cuando Pusher está activo.
  static const Duration driversApiRefreshWithPusher = Duration(seconds: 45);

  /// Refresco API si no hay tiempo real.
  static const Duration driversApiRefreshWithoutPusher = Duration(seconds: 20);

  /// Debounce entre cargas API de conductores.
  static const Duration driversApiDebounce = Duration(seconds: 30);

  /// Retraso del reverse geocode tras el primer GPS (mapa primero).
  static const Duration originGeocodeDefer = Duration(seconds: 2);

  /// «Tu zona» del conductor (calle/barrio en el chip) sigue siempre activo.
  /// Solo limita cuántas veces se llama a Google por GPS; la etiqueta no se oculta.
  static const double conductorZonaMinMoveMeters = 50;

  /// Mismo orden de magnitud que antes (~50 s): al moverse o cada minuto.
  static const Duration conductorZonaMinInterval = Duration(seconds: 55);

  /// Home conductor en línea (sin viaje): GPS más espaciado = menos batería.
  static const int conductorGpsDistanceFilterIdle = 28;
  static const int conductorGpsDistanceFilterActive = 8;
  static const Duration conductorGpsUiMinIntervalIdle = Duration(seconds: 4);
  static const Duration conductorGpsUiMinIntervalNav = Duration(milliseconds: 800);
  static const double conductorGpsUiMinMoveMetersIdle = 22;
  static const double conductorGpsUiMinMoveMetersNav = 10;

  /// Heartbeat mapa flota (conductor en turno, sin viaje activo).
  static const Duration mapHeartbeatMinInterval = Duration(seconds: 15);

  /// Android: envío ubicación en servicio foreground (viaje).
  static const int backgroundLocationIntervalSeconds = 15;

  /// Tiempo mínimo de marca en Splash (sin bloquear si la sesión tarda más).
  static const Duration splashMinDisplay = Duration(milliseconds: 550);

  /// Timeout del chequeo de actualización en Splash (no bloquear home).
  static const Duration splashUpdateCheckTimeout = Duration(seconds: 2);

  /// Nueva solicitud conductor: abrir IntelliTaxi si está en otra app o pantalla apagada.
  static const bool autoOpenAppOnIncomingService = true;
}
