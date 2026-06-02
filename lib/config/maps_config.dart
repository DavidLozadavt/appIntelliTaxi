/// Mapas: tiles OSM en cliente; geocode / autocomplete / rutas vía backend (Nominatim + OSRM).
abstract final class MapsConfig {
  static const bool useBackendProxy = bool.fromEnvironment(
    'USE_BACKEND_MAPS_PROXY',
    defaultValue: true,
  );

  /// Plantilla de tiles `{z}/{x}/{y}` (OpenStreetMap o Carto).
  static String tileUrlTemplate({required bool isDark}) {
    if (isDark) {
      return 'https://basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png';
    }
    return 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
  }

  static const Duration autocompleteDebounce = Duration(milliseconds: 500);
  static const int autocompleteMinChars = 3;

  /// Reverse geocode en cliente (pasajero origen / zona conductor).
  static const double reverseGeocodeMinMoveMeters = 80;
  static const Duration reverseGeocodeMinInterval = Duration(seconds: 30);

  static const Duration routeRecalcMinInterval = Duration(seconds: 60);
}
