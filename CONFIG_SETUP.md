# IntelliTaxi - Configuración

## Configuración Inicial

### 1. Archivo de Configuración

Este proyecto usa un archivo de configuración para almacenar información sensible. Para configurar el proyecto:

1. Copia el archivo de ejemplo:
   ```bash
   cp lib/config/app_config.example.dart lib/config/app_config.dart
   ```

2. Edita `lib/config/app_config.dart` con tus credenciales reales:
   - **baseUrl**: URL de tu API Laravel
   - **googleMapsApiKey**: Clave de Google Maps API
   - **pusherAppKey**: Credenciales de Pusher
   - **pusherCluster**: Cluster de Pusher (mt1, eu, ap1, etc.)

### 2. Firebase (Opcional)

Si usas Firebase, también debes configurar:
- `lib/firebase_options.dart` (generado con FlutterFire CLI)
- `android/app/google-services.json`
- `ios/Runner/GoogleService-Info.plist`

### Notas de Seguridad

⚠️ **IMPORTANTE**: El archivo `app_config.dart` está en `.gitignore` y NO debe subirse al repositorio ya que contiene información sensible.

Solo el archivo `app_config.example.dart` debe estar en el control de versiones como plantilla.
