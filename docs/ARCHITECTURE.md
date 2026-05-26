# Arquitectura IntelliTaxi

## Objetivo
Mantener una app Flutter escalable por módulos (features), con estado predecible y UI consistente.

## Estructura recomendada

```text
lib/
  core/
    services/
    theme/
    widgets/
    interceptors/
  features/
    <feature>/
      data/
      logic/
      presentation/
      widgets/
```

## Reglas clave
- `core/`: solo piezas transversales (logger, dio, theming, widgets compartidos).
- `features/`: lógica encapsulada por dominio funcional.
- Mapeo API: usar modelos/mapper por feature, no consumir JSON crudo en UI.
- Navegación: solo desde capas de presentación o helpers de navegación del core.

## Estado y ciclo de vida
- Usar `Provider` por feature y evitar providers globales innecesarios.
- En callbacks async: validar `mounted` antes de `setState` o navegar.
- Cerrar timers/listeners/subscripciones en `dispose`.

## Eventos en tiempo real
- Canal único por servicio: `servicio.{id}`.
- Evento de estado: `servicio.estado.cambiado` debe ser fuente de verdad para cierre de pantallas activas.

## Calidad mínima antes de merge
- `dart format lib test`
- `dart analyze`
- `flutter test`

## Producción

### Arranque
- `AppBootstrap.installErrorHandlers()` en `main.dart` (errores Flutter y async en release).
- `AppBootstrap.logConfigWarnings()` valida `.env` (`BASE_URL`, Maps, Pusher).

### Capas por feature
| Capa | Uso |
|------|-----|
| `presentation/` | Widgets, `Scaffold`, navegación |
| `controllers/` | Estado + Pusher + mapa sin UI |
| `services/` | API, geocoding, enriquecimiento |
| `utils/` | Funciones puras (parseo, estados) |

### Archivos clave refactor
- Conductor home: `conductor_solicitud_*`, `conductor_session_helper`
- Viaje activo: `conductor_servicio_map_service`, `conductor_servicio_pusher_controller`, `conductor_servicio_state_transitions`
- Pasajero home: `pasajero_nearby_drivers_controller`, `pasajero_active_service_controller`

### Checklist release
1. `.env` de producción (sin `tu-servidor.com` placeholder).
2. `flutter build apk/appbundle` o `flutter build ios --release`.
3. Probar: turno conductor, solicitud, viaje completo, pasajero pide viaje.
4. Permisos: ubicación, notificaciones, overlay (Android conductor).
5. Revisar `docs/play_store_privacy_checklist.md`.
