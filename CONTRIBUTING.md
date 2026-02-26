# Contribuir a IntelliTaxi

## Flujo recomendado
1. Crear rama por feature/fix.
2. Implementar cambios por módulo (`features/...`).
3. Ejecutar calidad local:
   - `make format-check`
   - `make analyze`
   - `make test`
4. Abrir PR con alcance claro y evidencia de pruebas.

## Convenciones
- Evitar lógica de negocio en widgets.
- Evitar JSON crudo en UI: usar modelos y mappers.
- Evitar `print`; usar `AppLogger`.
- Usar nombres explícitos y funciones pequeñas.

## Errores frecuentes a evitar
- `setState` después de `dispose`.
- uso de `BuildContext` tras `await` sin revisar `mounted`.
- suscripciones/timers sin limpiar en `dispose`.

## Comandos útiles
- `make deps`
- `make quality`
