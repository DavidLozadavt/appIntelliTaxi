// lib/config/app_config.dart
// INSTRUCCIONES: Copia este archivo como 'app_config.dart' y completa con tus credenciales reales

class AppConfig {
  // URL base de tu API Laravel
  static const String baseUrl = 'https://tu-servidor.com/api/'; // Android Emulator
  // static const String baseUrl = 'http://localhost:8000/api'; // iOS Simulator
  // static const String baseUrl = 'https://tu-dominio.com/api'; // Producción
  
  // Google Maps API Key - Obtén tu clave en: https://console.cloud.google.com/
  static const String googleMapsApiKey = 'TU_GOOGLE_MAPS_API_KEY_AQUI';
  
  // Pusher Configuration - Obtén tus credenciales en: https://pusher.com/
  static const String pusherAppKey = 'TU_PUSHER_APP_KEY_AQUI';
  static const String pusherCluster = 'mt1'; // Ejemplo: mt1, eu, ap1, etc.
  
  // Configuración de la app
  static const int defaultRadius = 20; // km
  static const int offerExpirationMinutes = 5;
  static const double defaultZoom = 15.0;
}
