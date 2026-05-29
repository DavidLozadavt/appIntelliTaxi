/// Mapas: geocode / autocomplete / rutas vía backend (Nominatim + OSRM).
/// El [google_maps_flutter] SDK sigue para el mapa visual.
abstract final class MapsConfig {
  static const bool useBackendProxy = bool.fromEnvironment(
    'USE_BACKEND_MAPS_PROXY',
    defaultValue: true,
  );

  static const Duration autocompleteDebounce = Duration(milliseconds: 500);
  static const int autocompleteMinChars = 3;

  /// Reverse geocode en cliente (pasajero origen / zona conductor).
  static const double reverseGeocodeMinMoveMeters = 80;
  static const Duration reverseGeocodeMinInterval = Duration(seconds: 30);

  static const Duration routeRecalcMinInterval = Duration(seconds: 60);
}
