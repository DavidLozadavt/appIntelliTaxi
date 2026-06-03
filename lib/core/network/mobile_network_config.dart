/// Parámetros de red pensados para datos móviles lentos o inestables.
abstract final class MobileNetworkConfig {
  /// HTTP general (API, login, ubicación en background).
  static const Duration httpConnectTimeout = Duration(seconds: 90);
  static const Duration httpReceiveTimeout = Duration(seconds: 90);
  static const Duration httpSendTimeout = Duration(seconds: 90);

  /// Acciones críticas del usuario (solicitar viaje, oferta directa).
  static const Duration userActionTimeout = Duration(seconds: 50);

  /// No retrasar el login esperando token FCM (Google puede tardar en 3G).
  static const Duration fcmMaxWaitBeforeLogin = Duration(seconds: 4);

  /// Intentos internos de FCM tras el arranque (no bloquean login).
  static const Duration fcmAttemptTimeout = Duration(seconds: 12);
  static const Duration fcmRetryDelay = Duration(seconds: 3);
  static const int fcmMaxAttempts = 2;

  /// Chequeo de actualización tras login (opcional).
  static const Duration postLoginUpdateCheckTimeout = Duration(seconds: 6);

  /// Reintentos automáticos en Dio ([RetryInterceptor]).
  static const int httpMaxRetries = 3;
  static const Duration httpRetryBaseDelay = Duration(milliseconds: 700);
}
