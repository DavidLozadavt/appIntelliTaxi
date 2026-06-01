# Performance Playbook — TaxbelUrbano / IntelliTaxi

## Presupuesto objetivo

| Métrica | Objetivo |
|--------|----------|
| Arranque interactivo | < 2,5 s (gama media) |
| Jank en flujo crítico | < 1 % |
| APK instalado | Reducir assets y dependencias innecesarias |
| RAM imágenes | ~48 MB tope (`AppPerformanceConfig`) |

## Ya aplicado en el proyecto

- Poppins **solo en assets** (sin `google_fonts`).
- Providers pesados con `lazy: true` en `main.dart`.
- Servicios (FCM, Pusher, ubicación) en `RuntimeBootstrap` **después** del primer frame.
- `SessionPreload` en paralelo al splash.
- Release Android: `minifyEnabled` + `shrinkResources`.
- Caché de imágenes acotada (`AppPerformanceConfig`).
- Listas: `OptimizedListView` / `RepaintBoundary` donde aplica.

## Prioridad 1 — Peso del APK (rápido)

1. **Assets**
   - `assets/images/intellitaxi.png` (~1,4 MB) no está en `pubspec` → borrar o mover fuera del repo.
   - `mock3.png` (~280 KB) en onboarding → convertir a WebP o bajar resolución.
   - Usar solo `logoTaxbel.webp` (no duplicar PNG).
   - Sonidos: el catálogo incluye ~10 MP3; comprimir a 64–96 kbps o dejar 3–4 favoritos en el bundle y el resto descargables.

2. **Dependencias**
   - Evitar dos librerías de iconos (Iconsax + otra).
   - Cada paquete de mapas/overlay/background suma al APK y al arranque.

3. **Medir**
   ```bash
   flutter build appbundle --release --analyze-size
   ```

## Prioridad 2 — Arranque y fluidez

1. **No bloquear `main`**
   - Firebase + dotenv sí; el resto diferido (`RuntimeBootstrap`).

2. **Mapa conductor** (implementado en `ConductorHomeProvider` + `home_conductor`)
   - GPS en línea: `distanceFilter` 12 m, UI cada ~2 s o 14 m de movimiento.
   - En viaje: filtro 4 m, UI cada ~450 ms o 6 m.
   - Heartbeat API: mínimo 5 s (sin cambiar).
   - Mapa en `Selector`: no se repinta con el ticker de cuenta regresiva de solicitudes.
   - Cámara de navegación: listener dedicado, no en cada `build`.
   - Ajustes en `RuntimePerfFlags` (`conductorGps*`).

3. **Rebuilds**
   - `Selector` / `Consumer` acotado en `home_conductor` y tarjetas de solicitud.
   - Extraer widgets `const` donde el padre reconstruye mucho.

4. **Perfil real**
   ```bash
   flutter run --profile
   ```
   DevTools → Performance → grabar: solicitar viaje, aceptar, mapa en curso.

## Prioridad 3 — Red y batería

1. Enriquecimiento POI/direcciones: timeouts cortos + no fatal (ya en enrichment).
2. Un solo listener Pusher por rol/servicio activo.
3. Background location solo con turno o viaje activo.
4. Overlay Android solo en `paused` (restricciones FGS).

## Checklist por pantalla

- [ ] Sin `await` pesado en `build`.
- [ ] Listas largas: `ListView.builder`, no `Column` con muchos hijos.
- [ ] Imágenes de red: `OptimizedNetworkImage` con `memCacheWidth/Height`.
- [ ] Markers de mapa: bitmap pequeño y reutilizado.

## Logs

- `AppLogger` con nivel acorde; en release evitar logs masivos en hot paths.

## Próximos pasos recomendados (orden)

1. Publicar build **1.0.1+2** con fuentes locales y fixes Crashlytics.
2. Limpiar assets (`intellitaxi.png`, comprimir `mock3`, sonidos).
3. Perfil en `home_conductor` + mapa → lista de frames > 16 ms.
4. `Selector` en widgets que escuchan `ConductorHomeProvider` completo.
5. Evaluar **deferred imports** para pantallas poco usadas (documentos, historial, chat).
