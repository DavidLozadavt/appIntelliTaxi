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

## Android Release

1. Crear `android/key.properties` a partir de `android/key.properties.example`.
2. Configurar `storeFile`, `storePassword`, `keyAlias`, `keyPassword` y `MAPS_API_KEY`.
3. Generar build:
   - `make apk-release`
   - `make aab-release`

Notas:
- `MAPS_API_KEY` ya no está hardcodeada en `AndroidManifest.xml`.
- Si falta `key.properties`, localmente usará firma `debug` para no bloquear desarrollo.
