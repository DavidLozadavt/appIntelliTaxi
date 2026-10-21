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

  /// GPS local (sin HTTP): pin suave. El servidor se actualiza aparte.
  static const int conductorGpsDistanceFilterIdle = 8;
  static const int conductorGpsDistanceFilterActive = 2;
  static const Duration conductorGpsUiMinIntervalIdle = Duration(seconds: 1);
  static const Duration conductorGpsUiMinIntervalNav = Duration(milliseconds: 400);
  static const double conductorGpsUiMinMoveMetersIdle = 4;
  static const double conductorGpsUiMinMoveMetersNav = 2;

  /// Stream GNSS en el dispositivo (no es petición al ERP).
  static const Duration conductorGpsStreamIntervalDriving = Duration(seconds: 1);

  /// Velocidad (m/s) a partir de la cual se trata como conducción (~5 km/h).
  static const double conductorDrivingSpeedMps = 1.4;

  /// Poll de respaldo solo si el stream GPS falla (no corre en paralelo).
  static const Duration mapHeartbeatPollIntervalFallback = Duration(seconds: 10);

  /// Si no llega ningún fix GPS en este tiempo, revisa el stream.
  ///
  /// Por encima de [conductorGpsIdleHeartbeatInterval] a propósito: el timer
  /// de reposo ya refresca, así que un umbral menor haría que el watchdog
  /// compitiese con él.
  static const Duration conductorGpsStaleAfter = Duration(seconds: 20);

  /// Con el conductor detenido el GPS no emite eventos (distanceFilter), así
  /// que no se reinicia el stream: basta con refrescar la posición de vez en
  /// cuando para evitar la deriva.
  static const Duration conductorGpsIdleRefreshMinInterval = Duration(
    seconds: 40,
  );

  /// HTTP al ERP con el conductor parado. No bajar de esto: 12 s ≈ 5 req/min.
  static const Duration conductorGpsIdleHeartbeatInterval = Duration(
    seconds: 15,
  );

  /// Cada cuánto se revisa si el GPS del home está estancado (local).
  static const Duration conductorGpsWatchdogInterval = Duration(seconds: 15);

  /// lastKnown más viejo que esto no se pinta como posición válida al resume.
  static const Duration conductorGpsLastKnownMaxAge = Duration(minutes: 2);

  /// HTTP mapa: parado. 15 s ≈ 4 req/min por conductor.
  static const Duration mapHeartbeatMinInterval = Duration(seconds: 15);

  /// HTTP mapa: en movimiento. 8 s ≈ 7–8 req/min (el pin local sigue a 1 Hz).
  static const Duration mapHeartbeatMinIntervalDriving = Duration(seconds: 8);

  /// Nunca más rápido que esto, aunque se haya movido. Evita ráfagas y 429.
  static const Duration mapHeartbeatAbsoluteMinInterval = Duration(seconds: 4);

  /// Adelantar el HTTP solo si avanzó un tramo real, no por jitter GPS.
  static const double mapHeartbeatMinMoveMeters = 18;

  /// Android viaje: envío al ERP (no el stream GNSS).
  static const int backgroundLocationIntervalSeconds = 8;

  /// Android en línea en segundo plano.
  static const int mapHeartbeatBackgroundIntervalSeconds = 20;

  /// Tiempo mínimo de marca en Splash (sin bloquear si la sesión tarda más).
  static const Duration splashMinDisplay = Duration(milliseconds: 550);

  /// Timeout del chequeo de actualización en Splash (no bloquear home).
  static const Duration splashUpdateCheckTimeout = Duration(seconds: 2);

  /// Nueva solicitud conductor: abrir IntelliTaxi si está en otra app o pantalla apagada.
  static const bool autoOpenAppOnIncomingService = true;
}
