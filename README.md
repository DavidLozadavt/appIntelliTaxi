# IntelliTaxi

Aplicación móvil de transporte (pasajero/conductor) con tiempo real, mapas y gestión de servicios activos.

## Setup rápido

1. Instalar dependencias:
   - `flutter pub get`
2. Copiar configuración local:
   - `.env.example` -> `.env`
3. Ejecutar:
   - `flutter run`

## Calidad local

- `make format-check`
- `make analyze`
- `make test`
- `make quality`

## Documentación interna

- Arquitectura: `docs/ARCHITECTURE.md`
- Rendimiento: `docs/PERFORMANCE_PLAYBOOK.md`
- Contribución: `CONTRIBUTING.md`

## CI

El workflow `.github/workflows/quality.yml` valida automáticamente:
- formato,
- análisis estático,
- tests.
