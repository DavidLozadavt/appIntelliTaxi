/// Límites globales de memoria y arranque (ajustar según dispositivos objetivo).
abstract final class AppPerformanceConfig {
  /// Imágenes decodificadas en RAM (mapas + listas + chat).
  static const int imageCacheMaxCount = 80;

  /// ~48 MB: suficiente para markers/mapas sin retener 80 MB como antes.
  static const int imageCacheMaxBytes = 48 << 20;
}
