/// Flags para reducir trabajo en debug (logs, polling, animaciones).
abstract final class RuntimePerfFlags {
  /// Logs HTTP completos (cuerpos JSON enormes bloquean el hilo en debug).
  static const bool verboseHttpLogs = false;

  /// Logs detallados del WebSocket (eventos, handlers, estados).
  static const bool verboseSocketLogs = false;

  /// Log en cada request con token (muy ruidoso).
  static const bool logAuthInterceptor = false;

  /// Intervalo mínimo entre [GoogleMap] setState por marcadores (~15 fps).
  static const Duration markerSyncMinInterval = Duration(milliseconds: 66);

  /// Refresco API de conductores cuando el socket está activo.
  static const Duration driversApiRefreshWithSocket = Duration(seconds: 45);

  /// Refresco API si no hay tiempo real.
  static const Duration driversApiRefreshWithoutSocket = Duration(seconds: 20);

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
  static const int conductorGpsDistanceFilterIdle = 20;
  /// Metros entre lecturas GPS en movimiento (~8 m).
  static const int conductorGpsDistanceFilterActive = 8;
  static const Duration conductorGpsUiMinIntervalIdle = Duration(seconds: 4);
  static const Duration conductorGpsUiMinIntervalNav = Duration(milliseconds: 800);
  static const double conductorGpsUiMinMoveMetersIdle = 22;
  static const double conductorGpsUiMinMoveMetersNav = 10;

  /// Android: intervalo del stream GPS solo en movimiento.
  static const Duration conductorGpsStreamIntervalDriving = Duration(seconds: 4);

  /// Velocidad (m/s) a partir de la cual se trata como conducción (~5 km/h).
  static const double conductorDrivingSpeedMps = 1.4;

  /// Poll de respaldo solo si el stream GPS falla (no corre en paralelo).
  static const Duration mapHeartbeatPollIntervalFallback = Duration(seconds: 20);

  /// Heartbeat mapa flota parado.
  static const Duration mapHeartbeatMinInterval = Duration(seconds: 30);

  /// Heartbeat mapa flota en movimiento.
  static const Duration mapHeartbeatMinIntervalDriving = Duration(seconds: 8);

  /// Si se movió ≥ esto (m), enviar aunque no haya pasado el intervalo mínimo.
  static const double mapHeartbeatMinMoveMeters = 15;

  /// Android: envío ubicación en servicio foreground (viaje).
  static const int backgroundLocationIntervalSeconds = 12;

  /// Android: heartbeat mapa con conductor en línea y app en segundo plano.
  static const int mapHeartbeatBackgroundIntervalSeconds = 45;

  /// Tiempo mínimo de marca en Splash (sin bloquear si la sesión tarda más).
  static const Duration splashMinDisplay = Duration(milliseconds: 550);

  /// Timeout del chequeo de actualización en Splash (no bloquear home).
  static const Duration splashUpdateCheckTimeout = Duration(seconds: 2);

  /// Nueva solicitud conductor: abrir IntelliTaxi si está en otra app o pantalla apagada.
  static const bool autoOpenAppOnIncomingService = true;
}
