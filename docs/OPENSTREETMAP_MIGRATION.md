# Migración a OpenStreetMap (rama `feature/openstreetmap-flutter-map`)

## Qué cambió

- **Mapa visual:** `google_maps_flutter` → `flutter_map` con tiles OSM (claro) y Carto Dark (tema oscuro).
- **API de mapa en código:** capa de compatibilidad en `lib/core/map/` (`LatLng`, `Marker`, `GoogleMapController`, etc.).
- **Geocode / rutas / autocomplete:** sin cambios; siguen en backend (Nominatim + OSRM) con `MapsConfig.useBackendProxy`.

## Dependencias

- Añadido: `flutter_map`, `latlong2`
- Eliminado: `google_maps_flutter`, `flutter_polyline_points`

## Configuración

- `GOOGLE_MAPS_API_KEY` ya no es obligatoria para arrancar la app.
- Opcional solo si usas geocode legacy de Google en cliente (`USE_BACKEND_MAPS_PROXY=false`).

## Producción

- No abuses del tile server público de OSM; para muchos usuarios usa tu propio servidor de tiles o un proveedor (MapTiler, etc.).
- La app muestra atribución «© OpenStreetMap» en el mapa.

## Probar

```bash
git checkout feature/openstreetmap-flutter-map
flutter pub get
flutter run
```

Verifica: home pasajero, home conductor, servicio activo, oferta exclusiva, polilíneas de ruta y marcadores de taxi.
