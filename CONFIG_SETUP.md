# IntelliTaxi - Configuración

## Configuración Inicial

### 1. Variables de Entorno

Este proyecto usa un archivo `.env` para almacenar información sensible. Para configurar el proyecto:

1. Copia el archivo de ejemplo:
   ```bash
   cp .env.example .env
   ```

2. Edita `.env` con tus credenciales reales:
   ```env
   # API Configuration
   BASE_URL=https://tu-servidor.com/api/

   # Google Maps API Key
   GOOGLE_MAPS_API_KEY=TU_CLAVE_AQUI

   # Pusher Configuration
   PUSHER_APP_KEY=TU_PUSHER_KEY_AQUI
   PUSHER_CLUSTER=mt1

   # App Settings
   DEFAULT_RADIUS=20
   OFFER_EXPIRATION_MINUTES=5
   DEFAULT_ZOOM=15.0
   ```

3. Instala las dependencias:
   ```bash
   flutter pub get
   ```

### 2. Firebase (Opcional)

Si usas Firebase, también debes configurar:
- `lib/firebase_options.dart` (generado con FlutterFire CLI)
- `android/app/google-services.json`
- `ios/Runner/GoogleService-Info.plist`

### 3. Obtener Credenciales

#### Google Maps API Key
1. Ve a [Google Cloud Console](https://console.cloud.google.com/)
2. Crea un proyecto nuevo o selecciona uno existente
3. Habilita "Maps SDK for Android" y "Maps SDK for iOS"
4. Crea una API Key en "Credenciales"

#### Pusher
1. Regístrate en [Pusher](https://pusher.com/)
2. Crea un nuevo canal/app
3. Obtén tu `app_key` y `cluster` desde el dashboard

### Notas de Seguridad

⚠️ **IMPORTANTE**: 
- El archivo `.env` está en `.gitignore` y NO debe subirse al repositorio
- Solo el archivo `.env.example` debe estar en el control de versiones como plantilla
- Nunca subas tus API keys al repositorio público
