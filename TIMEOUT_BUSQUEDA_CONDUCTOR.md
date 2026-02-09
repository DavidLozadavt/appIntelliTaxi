# Sistema de Timeout para Búsqueda de Conductor

## 📋 Descripción

Se ha implementado un sistema de timeout para evitar que el pasajero se quede esperando indefinidamente cuando no hay conductores disponibles o cuando ningún conductor acepta el viaje.

## ⏱️ Funcionamiento

### Tiempo de Espera
- **Máximo:** 2 minutos (120 segundos)
- **Contador visible:** Muestra el tiempo restante al pasajero
- **Cancelación automática:** Timer limpiado cuando se encuentra conductor

### Estados de la Búsqueda

1. **Buscando (0-120 segundos)**
   - Se muestra un indicador circular de progreso
   - Contador regresivo visible (MM:SS)
   - Botón "Cancelar búsqueda" disponible
   - Timer activo verificando disponibilidad

2. **Timeout (120 segundos)**
   - Se muestra diálogo informativo
   - Opciones disponibles:
     - ✅ **Reintentar:** Inicia nueva búsqueda
     - ❌ **Cancelar solicitud:** Cancela y vuelve al home

3. **Conductor encontrado**
   - Timer cancelado automáticamente
   - Transición a pantalla de seguimiento
   - Estado cambia a "aceptado"

## 🎯 Características Implementadas

### 1. Control de Tiempo
```dart
static const int _maxWaitingSeconds = 120; // 2 minutos
Timer? _timeoutTimer;
Timer? _countdownTimer;
int _elapsedSeconds = 0;
```

### 2. Indicador Visual de Progreso
- CircularProgressIndicator con progreso del tiempo
- Contador regresivo numérico (MM:SS)
- Color que cambia según tiempo restante:
  - Verde/Azul: > 30 segundos
  - Naranja: ≤ 30 segundos

### 3. Diálogo de Timeout
Cuando se agota el tiempo, se muestra un diálogo con:
- Mensaje explicativo
- Sugerencias útiles:
  - Intentar nuevamente en unos momentos
  - Verificar ubicación
  - Considerar hora de alta demanda
- Botones de acción:
  - **Cancelar solicitud** (rojo)
  - **Reintentar** (azul)

### 4. Función de Cancelación
```dart
POST /servicios/taxi/{servicioId}/cancelar
{
  "motivo": "No se encontraron conductores disponibles"
}
```

### 5. Función de Reintento
- Reinicia estado a "buscando"
- Reinicia timer desde 0
- Mantiene la solicitud existente
- Muestra mensaje de confirmación

## 📱 Interfaz de Usuario

### Panel de Búsqueda
```
┌─────────────────────────────┐
│     ⭕ [1:45]              │  ← Contador circular
│                             │
│  Buscando conductor         │
│  disponible...              │
│                             │
│  Por favor espera mientras  │
│  encontramos un conductor   │
│  cerca de ti                │
│                             │
│  [❌ Cancelar búsqueda]     │  ← Botón cancelar
└─────────────────────────────┘
```

### Diálogo de Timeout
```
┌─────────────────────────────┐
│  ⏰ Sin conductores         │
│     disponibles             │
│                             │
│  No hemos encontrado        │
│  conductores disponibles    │
│  en este momento.           │
│                             │
│  ┌─────────────────────┐   │
│  │ 💡 Sugerencias:     │   │
│  │ • Intenta de nuevo  │   │
│  │ • Verifica ubicación│   │
│  │ • Alta demanda      │   │
│  └─────────────────────┘   │
│                             │
│ [Cancelar]    [Reintentar] │
└─────────────────────────────┘
```

## 🔧 Archivos Modificados

### 1. `pasajero_esperando_conductor_screen.dart`
- ✅ Import de `dart:async` para Timer
- ✅ Variables de control de timeout
- ✅ Método `_iniciarTimeout()`
- ✅ Método `_cancelarTimeout()`
- ✅ Método `_mostrarDialogoTimeout()`
- ✅ Método `_reintentar()`
- ✅ Método `_cancelarServicio()`
- ✅ Widget `_buildBuscandoConductor()` mejorado con contador
- ✅ Cancelación automática en `onServicioAceptado`
- ✅ Limpieza de timers en `dispose()`

### 2. `waiting_for_driver_dialog.dart`
- ✅ Parámetro opcional `onCancel`
- ✅ Botón de cancelar opcional

## 🎨 Mejoras de UX

1. **Transparencia:** El usuario siempre sabe cuánto tiempo queda
2. **Control:** Puede cancelar en cualquier momento
3. **Flexibilidad:** Opción de reintentar sin perder contexto
4. **Feedback:** Mensajes claros sobre el estado
5. **Prevención:** Evita esperas infinitas

## 🚀 Uso

El sistema se activa automáticamente cuando:
1. El pasajero confirma una solicitud de viaje
2. Se navega a `PasajeroEsperandoConductorScreen`
3. El estado es "buscando"

No requiere configuración adicional. Los timers se gestionan automáticamente.

## ⚠️ Consideraciones

1. **Backend:** Asegurarse de que el endpoint de cancelación esté implementado:
   ```
   POST /servicios/taxi/{id}/cancelar
   ```

2. **Notificaciones:** Considerar enviar notificación push cuando se encuentre conductor después de timeout

3. **Ajuste de tiempo:** El valor de 120 segundos es configurable en:
   ```dart
   static const int _maxWaitingSeconds = 120;
   ```

4. **Sincronización:** El timer se cancela cuando Pusher notifica conductor encontrado

## 📊 Flujo Completo

```
Solicitud de viaje
        ↓
Pantalla de búsqueda
        ↓
Timer iniciado (120s)
        ↓
    ┌───────┴───────┐
    ↓               ↓
Conductor      Timeout
encontrado     (120s)
    ↓               ↓
Timer          Diálogo
cancelado      opciones
    ↓               ↓
Seguimiento    Reintentar
              o Cancelar
```

## ✅ Testing Recomendado

1. Esperar timeout completo
2. Cancelar durante búsqueda
3. Recibir conductor antes de timeout
4. Probar reintento después de timeout
5. Verificar cancelación de timer en dispose
6. Verificar navegación después de cancelar

## 🎯 Próximas Mejoras Sugeridas

- [ ] Permitir ajustar tiempo de espera por configuración
- [ ] Agregar estadísticas de tiempo promedio de aceptación
- [ ] Notificación de vibración al encontrar conductor
- [ ] Sonido opcional al encontrar conductor
- [ ] Historial de búsquedas fallidas
- [ ] Sugerencia de horarios con más disponibilidad
