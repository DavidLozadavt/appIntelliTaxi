class LocationTrackingConfig {
  // Intervalo para enviar ubicacion al backend durante servicio activo.
  static const int sendIntervalSeconds = 15;

  // Distancia minima para considerar que vale la pena enviar un update.
  static const double minDistanceMeters = 8.0;
}
