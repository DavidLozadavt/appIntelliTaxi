# Guía para Play Store: Privacidad y Data safety

Fecha de revisión: 25 de mayo de 2026

Esta guía está basada en el comportamiento observado en el proyecto Flutter de TaxbelUrbano. Antes de enviar a revisión, valida que coincida con el backend real y con la ficha de Play Console.

## Requisitos clave

- Publicar una URL pública de política de privacidad en Play Console.
- Incluir enlace o texto de política de privacidad dentro de la app.
- La política debe mencionar TaxbelUrbano o la entidad desarrolladora que aparece en la ficha de Google Play.
- La política debe explicar acceso, recopilación, uso y compartición de datos, incluyendo datos sensibles.
- La sección Data safety debe ser consistente con la política y con lo que hacen la app, los SDK y el backend.

## Categorías que probablemente debes declarar en Data safety

### Ubicación

- Ubicación aproximada.
- Ubicación precisa.
- Se recopila.
- Se comparte con proveedores necesarios para mapas, rutas, backend, operación de viajes o servicios en tiempo real.
- Finalidades: funcionalidad de la app, seguridad, prevención de fraude, gestión de servicios.
- Marcar como necesaria para funciones principales.

### Información personal

- Nombre.
- Correo electrónico.
- Número de teléfono.
- Dirección.
- Identificadores personales, como tipo y número de identificación.
- Fecha de nacimiento y sexo si se guardan en perfil.
- Se recopila.
- Puede compartirse con conductores, pasajeros, empresa operadora o proveedores cuando sea necesario para el servicio.
- Finalidades: gestión de cuenta, funcionalidad de la app, seguridad, cumplimiento.

### Fotos y videos

- Fotos de perfil, documentos o vehículos.
- Se recopila cuando el usuario carga o captura imágenes.
- Finalidades: perfil, verificación, operación de conductor/vehículo, soporte.

### Mensajes

- Mensajes dentro de la app relacionados con chat o servicios.
- Se recopila.
- Finalidades: comunicación dentro del servicio y soporte.

### Actividad de la app

- Interacciones, historial de viajes, estado de servicios, cancelaciones, calificaciones y comentarios.
- Se recopila.
- Finalidades: funcionalidad, historial, soporte, seguridad y mejora.

### Información financiera

- Si la app solo muestra precio estimado o final y no procesa pagos, no declarar pagos.
- Si el backend procesa pagos, declarar método de pago, historial de compras o información financiera según aplique.

### Identificadores del dispositivo

- Token de notificaciones push.
- Identificadores técnicos usados por Firebase/Pusher o servicios similares.
- Se recopila.
- Finalidades: notificaciones, seguridad, funcionalidad.

### Diagnóstico

- Logs, errores o datos de rendimiento si se envían al backend o servicios externos.
- Finalidades: estabilidad, soporte y mejora.

## Permisos sensibles observados

- `ACCESS_FINE_LOCATION`
- `ACCESS_COARSE_LOCATION`
- `ACCESS_BACKGROUND_LOCATION`
- `FOREGROUND_SERVICE_LOCATION`
- `POST_NOTIFICATIONS`
- `CAMERA`
- `READ_MEDIA_IMAGES`
- `SYSTEM_ALERT_WINDOW`
- `RECORD_AUDIO`

Revisa especialmente ubicación en segundo plano y permisos de audio/cámara. Google Play suele pedir que la funcionalidad sea evidente para el usuario y esté justificada por la ficha de la app.

## Pendientes antes de publicar

- Reemplazar `[REEMPLAZAR_CON_CORREO_DE_SOPORTE]` por un correo real y monitoreado.
- Subir `web/privacy.html` a una URL pública HTTPS.
- Agregar un acceso a la política dentro de la app, por ejemplo en Perfil, Ajustes, Acerca de o pantalla inicial.
- Confirmar si se procesan pagos. Si sí, actualizar política y Data safety.
- Confirmar si se usa analítica, crash reporting o publicidad. Si sí, actualizar política y Data safety.
- Confirmar nombre legal del responsable o empresa titular para reemplazar "TaxbelUrbano" si corresponde.
