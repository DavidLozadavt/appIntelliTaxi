# 🚖 Servicio de Solicitud de Viajes - Con Logs en Consola

## ✅ Implementación Completa

He creado el servicio completo para solicitar viajes con todos los datos necesarios y **logs detallados en consola**.

## 📦 Archivos Creados/Modificados

### Nuevos Archivos:
- `lib/features/rides/services/ride_request_service.dart` - Servicio de solicitud de viajes

### Archivos Modificados:
- `lib/features/home/presentation/home_pasajero.dart` - Integración con el servicio

## 🔍 Datos que se Envían al Backend

Cuando el usuario solicita un servicio, se envían los siguientes datos:

```dart
{
  // 👤 IDs del usuario
  'persona_id': int,              // ID de la persona del usuario
  'company_user_id': int,         // ID de activación de compañía
  
  // 📍 Información del ORIGEN
  'origin_lat': double,           // Latitud del origen
  'origin_lng': double,           // Longitud del origen
  'origin_address': String,       // Dirección completa del origen
  'origin_name': String,          // Nombre del lugar de origen
  'origin_place_id': String,      // Google Place ID del origen
  
  // 📍 Información del DESTINO
  'destination_lat': double,      // Latitud del destino
  'destination_lng': double,      // Longitud del destino
  'destination_address': String,  // Dirección completa del destino
  'destination_name': String,     // Nombre del lugar de destino
  'destination_place_id': String, // Google Place ID del destino
  
  // 🛣️ Información de la RUTA
  'distance': String,             // "5.2 km"
  'distance_value': int,          // 5200 (metros)
  'duration': String,             // "12 mins"
  'duration_value': int,          // 720 (segundos)
  'estimated_price': double,      // 18000.0
  
  // 🚗 Tipo de SERVICIO
  'service_type': String,         // 'taxi' o 'domicilio'
  'status': String,               // 'pending' (inicial)
  
  // 📝 OPCIONAL
  'observations': String?,        // Observaciones adicionales
  
  // ⏰ TIMESTAMP
  'requested_at': String,         // ISO 8601 timestamp
}
```

## 🖥️ Ejemplo de Logs en Consola

Cuando se solicita un servicio, verás en consola algo como esto:

```
================================================================================
🚖 DATOS DE SOLICITUD DE SERVICIO
================================================================================

👤 DATOS DEL USUARIO:
   persona_id: 123
   company_user_id: 456

📍 PUNTO DE ORIGEN:
   Nombre: Mi ubicación actual
   Dirección: Calle 5 #4-20, Popayán, Cauca
   Coordenadas: 2.442389, -76.613333
   Place ID: ChIJ...

📍 PUNTO DE DESTINO:
   Nombre: Centro Comercial El Campanario
   Dirección: Cra. 9 #15N-51, Popayán, Cauca
   Coordenadas: 2.455111, -76.605556
   Place ID: ChIJ...

🛣️  INFORMACIÓN DE LA RUTA:
   Distancia: 3.2 km (3200 metros)
   Duración: 8 mins (480 segundos)
   Precio estimado: $13000.0

🚗 TIPO DE SERVICIO:
   taxi (Transporte de pasajeros)
   Estado: pending

⏰ TIMESTAMP:
   2026-02-05T14:30:45.123Z

📦 JSON COMPLETO:
{
  "persona_id": 123,
  "company_user_id": 456,
  "origin_lat": 2.442389,
  "origin_lng": -76.613333,
  ...
}
================================================================================
```

## 🚀 Cómo Usar

### Para el Usuario:
1. Abre la app y ve al home de pasajero
2. Selecciona origen y destino
3. Presiona "Solicitar viaje" o "Solicitar domicilio"
4. Confirma los datos
5. Los datos se envían automáticamente al backend

### Para Desarrolladores:

#### Configurar el Endpoint:
Edita la línea en `ride_request_service.dart`:
```dart
'rides/request', // Cambia esto por tu endpoint
```

#### Ver los Logs:
1. **En VS Code**: Abre el Debug Console
2. **En Android Studio**: Abre el Run tab
3. **En Terminal**: Los logs aparecen directamente
4. **En DevTools**: También aparecen en la pestaña Logging

Los logs solo aparecen en **modo debug** (`kDebugMode`), no en producción.

## 📤 Endpoint del Backend Esperado

```
POST {{base_url}}/rides/request
Authorization: Bearer {{token}}
Content-Type: application/json

Body: {
  // Todos los datos mencionados arriba
}
```

### Respuesta Esperada:
```json
{
  "success": true,
  "message": "Solicitud de viaje creada exitosamente",
  "ride": {
    "id": 789,
    "status": "pending",
    "estimated_arrival": "2026-02-05T14:45:00Z",
    ...
  }
}
```

## 🛠️ Métodos Adicionales Incluidos

### 1. Cancelar Solicitud
```dart
await _rideRequestService.cancelRideRequest(
  rideId: 789,
  reason: 'Usuario canceló',
  token: token,
);
```

### 2. Obtener Historial
```dart
final rides = await _rideRequestService.getRideHistory(
  personaId: 123,
  token: token,
  page: 1,
  limit: 20,
);
```

### 3. Obtener Estado del Viaje
```dart
final status = await _rideRequestService.getRideStatus(
  rideId: 789,
  token: token,
);
```

## 🎯 Características de los Logs

- ✅ **Formateo claro y legible**
- ✅ **Separación por categorías** (usuario, origen, destino, ruta, servicio)
- ✅ **JSON completo formateado** con indentación
- ✅ **Errores detallados** con stack trace
- ✅ **Solo en modo debug** (no afecta producción)
- ✅ **Compatible con DevTools** de Flutter

## 🔐 Seguridad

- El token se envía en el header `Authorization`
- Los datos se validan antes de enviar
- Los errores se capturan y muestran al usuario
- Las coordenadas son precisas (GPS del dispositivo)

## 📝 Notas Importantes

1. **Token Requerido**: El usuario debe estar autenticado
2. **Ubicación Requerida**: Se necesitan permisos de ubicación
3. **Conexión Internet**: Obligatoria para enviar la solicitud
4. **Timeout**: 30 segundos para la petición
5. **Logs**: Solo visibles en debug mode

## 🎨 Flujo Completo

```
Usuario abre app
    ↓
Selecciona origen/destino
    ↓
Ve ruta en el mapa
    ↓
Confirma solicitud
    ↓
🔍 LOGS EN CONSOLA (Datos completos)
    ↓
📤 Envío al backend
    ↓
⏳ Modal de "Buscando conductor..."
    ↓
✅ Respuesta exitosa / ❌ Error
    ↓
Usuario ve confirmación
```

## 🐛 Debugging

Si algo sale mal, revisa:
1. **Consola**: Todos los datos se muestran ahí
2. **Network**: Verifica la URL del endpoint
3. **Token**: Asegúrate que el usuario esté autenticado
4. **Permisos**: Ubicación debe estar habilitada

## 💡 Ejemplo de Uso Programático

```dart
final rideService = RideRequestService();

try {
  await rideService.requestRide(
    personaId: 123,
    companyUserId: 456,
    origin: originLocation,
    destination: destinationLocation,
    distance: '3.2 km',
    distanceValue: 3200,
    duration: '8 mins',
    durationValue: 480,
    estimatedPrice: 13000.0,
    serviceType: 'taxi',
    token: 'your_auth_token',
  );
  
  // ✅ Solicitud enviada con éxito
  // Revisa la consola para ver todos los detalles
} catch (e) {
  // ❌ Error al enviar
  print('Error: $e');
}
```

---

**🎉 Listo para usar! Los logs te mostrarán exactamente qué datos se están enviando.**
