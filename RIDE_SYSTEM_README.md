# Sistema de Solicitud de Viajes - IntelliTaxi

## Características Implementadas

### 1. Servicio de Google Places API
**Archivo:** `lib/features/rides/services/places_service.dart`

- ✅ Búsqueda de lugares limitada a Popayán (radio de 20 km)
- ✅ Autocomplete de direcciones con restricción geográfica
- ✅ Obtención de detalles de lugares por placeId
- ✅ Validación de proximidad a Popayán usando fórmula Haversine
- ✅ Respuestas en español

### 2. Servicio de Rutas y Polilíneas
**Archivo:** `lib/features/rides/services/routes_service.dart`

- ✅ Cálculo de rutas entre dos puntos usando Google Directions API
- ✅ Decodificación de polilíneas para visualización en mapa
- ✅ Cálculo de precio estimado basado en distancia
- ✅ Información de distancia y duración del viaje
- ✅ Formato de precios en pesos colombianos

### 3. Modelo de Ubicación
**Archivo:** `lib/features/rides/data/trip_location.dart`

- ✅ Modelo para representar ubicaciones de viaje
- ✅ Soporte para ubicación actual del usuario
- ✅ Soporte para lugares seleccionados de Google Places

### 4. Bottom Sheet Animado (estilo InDriver)
**Archivo:** `lib/features/rides/widgets/ride_request_bottom_sheet.dart`

- ✅ Diseño expansible (35% - 90% de la pantalla)
- ✅ Animación suave al expandir/contraer
- ✅ Arrastre con gestos (swipe up/down)
- ✅ Campo de origen (por defecto: ubicación actual)
- ✅ Campo de destino con búsqueda en tiempo real
- ✅ Autocomplete con sugerencias de Google Places
- ✅ Límite de búsqueda a Popayán
- ✅ Indicador visual de área de búsqueda
- ✅ Validación antes de confirmar

### 5. Pantalla de Mapa con Ruta
**Archivo:** `lib/features/rides/presentation/ride_map_screen.dart`

- ✅ Visualización de ruta en Google Maps
- ✅ Polilínea animada entre origen y destino
- ✅ Marcadores para origen (verde) y destino (rojo)
- ✅ Ajuste automático de cámara para mostrar ruta completa
- ✅ Panel inferior con información del viaje:
  - Distancia
  - Duración estimada
  - Precio estimado
- ✅ Botón de centrar mapa
- ✅ Soporte para tema claro/oscuro
- ✅ Botón de confirmación de viaje

### 6. Integración con Home Pasajero
**Archivo:** `lib/features/rides/presentation/home_pasajero.dart`

- ✅ Convertido a StatefulWidget
- ✅ Obtención automática de ubicación actual
- ✅ Botón principal para solicitar viaje
- ✅ Apertura del bottom sheet modal
- ✅ Navegación fluida a pantalla de mapa

## Configuración

### Dependencias Agregadas
```yaml
http: ^1.2.2  # Para llamadas a Google Places API
```

### API Keys Utilizadas
- Google Maps API Key (ya configurada en `app_config.dart`)
- Servicios habilitados:
  - Places API
  - Directions API
  - Maps SDK for Android/iOS

## Flujo de Usuario

1. **Inicio**: Usuario ve botón "¿A dónde vas?" en home
2. **Bottom Sheet**: Se abre sheet animado con campos de búsqueda
3. **Selección de Origen**: Por defecto usa ubicación actual
4. **Búsqueda de Destino**: Usuario escribe y ve sugerencias de Popayán
5. **Confirmación**: Al seleccionar destino, botón "Continuar" se activa
6. **Pantalla de Ruta**: Muestra mapa con ruta trazada
7. **Detalles**: Panel inferior con distancia, duración y precio
8. **Solicitud**: Usuario confirma y solicita el viaje

## Características Técnicas

### Limitación Geográfica
- **Centro**: Popayán (2.4419°N, 76.6063°W)
- **Radio**: 20 km
- **País**: Solo Colombia
- **Validación**: Fórmula de Haversine para distancias

### Cálculo de Precios
- **Tarifa base**: $5,000 COP
- **Por kilómetro**: $2,500 COP
- **Redondeo**: Múltiplos de $100

### UX/UI
- Animaciones suaves (300ms)
- Drag gestures para expandir/contraer
- Loading states en búsquedas
- Feedback visual constante
- Diseño limpio y moderno

## Próximos Pasos Sugeridos

1. Integrar con backend para guardar solicitudes
2. Agregar sistema de notificaciones push
3. Implementar seguimiento en tiempo real
4. Agregar historial de viajes
5. Integrar pasarela de pagos
6. Sistema de calificación conductor/pasajero
7. Chat en vivo durante el viaje

## Notas Importantes

- ⚠️ Las búsquedas están limitadas a Popayán y alrededores
- ⚠️ Se requiere permiso de ubicación del usuario
- ⚠️ Los precios son estimados y pueden variar
- ⚠️ Se necesita conexión a internet activa
