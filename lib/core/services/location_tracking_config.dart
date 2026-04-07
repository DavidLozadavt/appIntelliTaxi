class LocationTrackingConfig {
  // Intervalo para enviar ubicacion al backend durante servicio activo.
  static const int sendIntervalSeconds = 10;

  // Distancia minima para considerar que vale la pena enviar un update.
  static const double minDistanceMeters = 8.0;

  // Timeouts de red.
  static const int connectTimeoutSeconds = 60;
  static const int receiveTimeoutSeconds = 60;
}
