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

  /// Tiempo mínimo de marca en Splash (sin bloquear si la sesión tarda más).
  static const Duration splashMinDisplay = Duration(milliseconds: 550);

  /// Timeout del chequeo de actualización en Splash (no bloquear home).
  static const Duration splashUpdateCheckTimeout = Duration(seconds: 2);
}
