class LocationTrackingConfig {
  /// Envío al ERP en viaje. El mapa del conductor usa GPS local más rápido.
  static const int sendIntervalSeconds = 8;

  /// No postear jitter de 2–3 m: solo si avanzó de verdad o va en marcha.
  static const double minDistanceMeters = 12.0;
}
