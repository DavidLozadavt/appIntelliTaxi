import 'package:intellitaxi/core/network/mobile_network_config.dart';

class LocationTrackingConfig {
  // Intervalo para enviar ubicacion al backend durante servicio activo.
  static const int sendIntervalSeconds = 10;

  // Distancia minima para considerar que vale la pena enviar un update.
  static const double minDistanceMeters = 8.0;

  // Timeouts de red (datos móviles lentos).
  static int get connectTimeoutSeconds =>
      MobileNetworkConfig.httpConnectTimeout.inSeconds;
  static int get receiveTimeoutSeconds =>
      MobileNetworkConfig.httpReceiveTimeout.inSeconds;
}
