# Sistema de Restauración de Servicios Activos

## 📋 Resumen

Sistema robusto para restaurar automáticamente los servicios activos cuando la app vuelve del background o se reinicia. Implementa las mejores prácticas de apps de transporte como Uber, InDriver y Didi.

## 🎯 Objetivo

**El usuario nunca pierde su servicio activo**, aunque cierre o minimice la app.

## 🏗️ Arquitectura

### Componentes Principales

#### 1. **ActiveServiceRestorationService** 
`lib/core/services/active_service_restoration_service.dart`

**Responsabilidad**: Consultar el backend para obtener el servicio activo

**Métodos clave**:
- `verificarServicioActivoConductor()`: Consulta endpoint `/api/servicio-activo-conductor`
- `verificarServicioActivoPasajero()`: Consulta endpoint `/api/servicio-activo-pasajero`
- `verificarServicioActivoSegunRol(AuthProvider)`: Determina el rol y consulta el endpoint correcto
- `esServicioActivo(servicio)`: Valida si el servicio está realmente activo

**Reglas de negocio**:
- Un servicio está activo cuando `finServicio IS NULL` y `idEstado NOT IN (cancelado, finalizado)`
- Backend es la fuente de verdad del estado
- Nunca depende del socket o datos locales

---

#### 2. **ServiceNavigationHelper**
`lib/core/services/service_navigation_helper.dart`

**Responsabilidad**: Navegar a la pantalla correcta según el servicio y rol

**Métodos clave**:
- `navigateToActiveService(context, servicioData, authProvider)`: Navega a la pantalla correcta
- `shouldShowActiveService(servicioData)`: Determina si debe mostrar la pantalla

**Pantallas de destino**:
- **Conductor**: `ConductorServicioActivoScreen`
- **Pasajero**: `PasajeroEsperandoConductorScreen`

---

#### 3. **AppLifecycleManager**
`lib/core/services/app_lifecycle_manager.dart`

**Responsabilidad**: Observar el ciclo de vida de la app y restaurar servicios

**Eventos observados**:
- `AppLifecycleState.resumed`: App vuelve del background → verifica servicio activo
- `AppLifecycleState.paused`: App va al background
- `AppLifecycleState.inactive`: App en transición
- `AppLifecycleState.detached`: App siendo terminada

**Características**:
- Cooldown de 3 segundos para evitar verificaciones múltiples
- Previene ejecuciones simultáneas
- Limpieza automática con `dispose()`

---

#### 4. **AppLifecycleWrapper**
`lib/core/services/app_lifecycle_wrapper.dart`

**Responsabilidad**: Widget wrapper que inicializa el lifecycle manager

**Uso**: Envuelve `NavigationScreen` para activar el sistema

---

## 🔄 Flujo de Restauración

### Escenario 1: Usuario abre la app

```
1. InitialScreen inicia
   ↓
2. Verifica onboarding
   ↓
3. Carga AuthProvider
   ↓
4. Llama a ActiveServiceRestorationService.verificarServicioActivoSegunRol()
   ↓
5. Consulta endpoint según rol (conductor/pasajero)
   ↓
6. Si existe servicio activo:
   → ServiceNavigationHelper.navigateToActiveService()
   → Navega a pantalla de servicio activo
   
7. Si NO existe servicio activo:
   → Continúa al home normal
```

### Escenario 2: Usuario vuelve del background

```
1. AppLifecycleManager detecta AppLifecycleState.resumed
   ↓
2. Verifica cooldown (evita llamadas múltiples)
   ↓
3. Llama a _checkAndRestoreActiveService()
   ↓
4. ActiveServiceRestorationService.verificarServicioActivoSegunRol()
   ↓
5. Consulta backend según rol
   ↓
6. Si existe servicio activo Y está en pantalla diferente:
   → ServiceNavigationHelper.navigateToActiveService()
   → Reemplaza pantalla actual con servicio activo
   
7. Si NO hay servicio O ya está en la pantalla correcta:
   → No hace nada
```

---

## 📡 Endpoints del Backend

### Conductor
```
GET /api/taxi/servicio-activo-conductor
```

**Respuesta esperada**:
```json
{
  "success": true,
  "data": {
    "servicio": {
      "id": 123,
      "idEstado": 2,
      "finServicio": null,
      "origen_lat": -12.0464,
      "origen_lng": -77.0428,
      "destino_lat": -12.0500,
      "destino_lng": -77.0500,
      "origen_address": "San Isidro",
      "destino_address": "Miraflores",
      "precio_final": 25.5
    },
    "vehiculo": {
      "id": 1,
      "placa": "ABC-123",
      "marca": "Toyota",
      "modelo": "Corolla"
    },
    "pasajero": {
      "id": 456,
      "nombre": "Juan Pérez"
    }
  }
}
```

### Pasajero
```
GET /api/taxi/servicio-activo
```

**Respuesta esperada**:
```json
{
  "success": true,
  "data": {
    "servicio": {
      "id": 123,
      "idEstado": 2,
      "finServicio": null,
      "origen_lat": -12.0464,
      "origen_lng": -77.0428,
      "destino_lat": -12.0500,
      "destino_lng": -77.0500,
      "origen_address": "San Isidro",
      "destino_address": "Miraflores",
      "precio_final": 25.5
    },
    "conductor": {
      "id": 789,
      "nombre": "Carlos López",
      "calificacion_promedio": 4.8
    },
    "vehiculo": {
      "id": 1,
      "placa": "ABC-123",
      "marca": "Toyota",
      "modelo": "Corolla"
    }
  }
}
```

---

## 🔧 Integración en el Proyecto

### Archivos Modificados

1. **NavigationScreen** (`lib/features/home/presentation/navigation_screen.dart`)
   - Envuelto con `AppLifecycleWrapper`
   - Activa sistema de lifecycle

2. **InitialScreen** (`lib/features/onboarding/presentation/initial_screen.dart`)
   - Verifica servicio activo al iniciar
   - Usa `ActiveServiceRestorationService`

### Archivos Creados

1. `lib/core/services/active_service_restoration_service.dart`
2. `lib/core/services/service_navigation_helper.dart`
3. `lib/core/services/app_lifecycle_manager.dart`
4. `lib/core/services/app_lifecycle_wrapper.dart`

---

## ✅ Verificación del Sistema

### Logs a Observar

#### Al abrir la app:
```
🔍 [InitialScreen] Verificando servicio activo al iniciar...
✅ [Restoration] Servicio activo conductor encontrado
📱 [Navigation] Navegando a pantalla de conductor...
✅ [Navigation] Navegación a conductor completada
```

#### Al volver del background:
```
🔄 [Lifecycle] Estado de la app cambió: AppLifecycleState.resumed
🔄 [Lifecycle] App resumed - verificando servicio activo...
🔍 [Restoration] Verificando servicio activo del pasajero...
✅ [Restoration] Servicio activo pasajero encontrado
```

#### Cuando no hay servicio activo:
```
ℹ️ [Restoration] No hay servicio activo del conductor (404)
ℹ️ [Lifecycle] No hay servicio activo para restaurar
```

---

## 🎯 Estados de Servicio

### Estados Activos (el usuario debe ver la pantalla):
- **1**: Buscando conductor
- **2**: Aceptado
- **3**: Conductor en camino (llegue)
- **4**: En curso (en_viaje)

### Estados Inactivos (NO mostrar pantalla):
- **5**: Cancelado
- **6**: Finalizado
- **7**: Rechazado

**Nota**: Ajustar los IDs según tu base de datos en:
- `ActiveServiceRestorationService.esServicioActivo()`
- `ServiceNavigationHelper.shouldShowActiveService()`

---

## 🛡️ Reglas Obligatorias Implementadas

✅ **Backend es la fuente de la verdad**
   - Siempre consulta el endpoint al restaurar
   - Nunca confía en datos locales o socket

✅ **Flutter no depende del socket para reconstruir estado**
   - Pusher solo notifica cambios en tiempo real
   - Estado siempre se obtiene del backend

✅ **Verificación automática al volver del background**
   - AppLifecycleState.resumed dispara verificación
   - Cooldown para evitar llamadas excesivas

✅ **Navegación automática a pantalla correcta**
   - Según rol: conductor o pasajero
   - Según estado del servicio

---

## 🚀 Casos de Uso

### ✅ Caso 1: Usuario cierra la app durante un viaje
1. Usuario tiene servicio activo
2. Cierra completamente la app
3. Vuelve a abrir la app
4. **Resultado**: Se restaura automáticamente a la pantalla de servicio activo

### ✅ Caso 2: Usuario minimiza la app durante espera de conductor
1. Pasajero solicita servicio
2. Minimiza la app
3. Conductor acepta (evento Pusher)
4. Usuario vuelve a la app
5. **Resultado**: Se verifica el backend y muestra el servicio actualizado

### ✅ Caso 3: Conductor acepta servicio y la app se cae
1. Conductor acepta servicio
2. App crashea o se cierra
3. Conductor vuelve a abrir la app
4. **Resultado**: Se restaura a la pantalla del servicio aceptado

### ✅ Caso 4: No hay servicio activo
1. Usuario abre la app
2. Backend responde sin servicio activo
3. **Resultado**: Va al home normal

---

## 🔍 Debug y Troubleshooting

### Si el servicio no se restaura:

1. **Verificar logs en consola**:
   - ¿Se llama al endpoint?
   - ¿El backend devuelve datos?
   - ¿El idEstado es correcto?

2. **Verificar respuesta del backend**:
   - Status code debe ser 200
   - `success` debe ser `true`
   - `data.servicio` debe existir

3. **Verificar que finServicio sea null**:
   - Si `finServicio` tiene valor, el servicio ya terminó

4. **Verificar estado del servicio**:
   - Estados inactivos (5, 6, 7) no restauran

5. **Verificar AuthProvider**:
   - Usuario debe estar autenticado
   - Roles deben estar correctos

---

## 📝 Mejoras Futuras

- [ ] Agregar retry automático si falla la llamada al backend
- [ ] Cachear último estado conocido como fallback
- [ ] Agregar analytics para medir tasa de restauración exitosa
- [ ] Implementar indicador visual durante la verificación
- [ ] Manejar casos de múltiples servicios (histórico)

---

## 👥 Comportamiento Esperado (como Uber)

✅ Nunca perder el servicio activo
✅ Restaurar estado al volver del background
✅ Funcionar sin internet (caché) pero validar con backend cuando vuelva conexión
✅ Notificaciones persistentes mientras hay servicio activo
✅ Sincronización automática del estado

---

## 🧪 Testing

### Test Manual:

1. **Test de inicio**:
   - Solicitar servicio
   - Cerrar app completamente
   - Abrir app
   - ✅ Debe restaurar servicio

2. **Test de background**:
   - Tener servicio activo
   - Minimizar app (Home button)
   - Cambiar estado en backend
   - Volver a app
   - ✅ Debe sincronizar estado

3. **Test de finalización**:
   - Tener servicio activo
   - Finalizar servicio
   - Cerrar app
   - Abrir app
   - ✅ Debe ir al home (sin restaurar)

---

## 📞 Contacto / Soporte

Para dudas sobre la implementación, revisar:
1. Logs de consola con prefijo `[Restoration]`, `[Navigation]`, `[Lifecycle]`
2. Respuestas de endpoints en Postman/Insomnia
3. Estados de servicio en base de datos
