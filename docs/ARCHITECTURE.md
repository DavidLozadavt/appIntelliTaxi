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
