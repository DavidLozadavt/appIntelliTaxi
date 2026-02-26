# Performance Playbook

## Presupuesto objetivo
- Arranque interactivo: < 2.5s en gama media.
- Jank: < 1% en flujo crítico (solicitar, aceptar, en curso, finalizar).
- Sin caídas de FPS perceptibles en mapa + bottom sheet.

## Checklist por pantalla
- Evitar trabajo pesado en `build`.
- Extraer widgets grandes en subwidgets `const` cuando aplique.
- Evitar `setState` global para cambios pequeños.
- Cachear recursos visuales reutilizados (íconos/markers).

## Mapa y tiempo real
- No recalcular rutas completas en cada update de ubicación.
- Throttle/debounce para eventos frecuentes de ubicación.
- Mantener un solo stream/listener activo por servicio.

## Logs
- Usar `AppLogger`.
- `debug`: solo desarrollo.
- `info/warn/error`: eventos importantes y fallos.

## Medición
- Correr en profile para decisiones reales.
- Registrar: FPS promedio, p95 frame build/raster, memoria pico.
