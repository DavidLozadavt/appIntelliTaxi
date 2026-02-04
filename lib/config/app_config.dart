// lib/config/app_config.dart
class AppConfig {
  // URL base de tu API Laravel
  static const String baseUrl = 'https://pre-rapidotambo-erp.virtualt.org/api/'; // Android Emulator
  // static const String baseUrl = 'http://localhost:8000/api'; // iOS Simulator
  // static const String baseUrl = 'https://tu-dominio.com/api'; // Producción
  
  // Google Maps API Key
  static const String googleMapsApiKey = 'AIzaSyDN2nvuXUru3ZN1N5cr1oMpqkZRA6d4es0';
  
  // Pusher Configuration
  static const String pusherAppKey = '6eb089dff17ffe3c7c47';
  static const String pusherCluster = 'mt1';
  
  // Configuración de la app
  static const int defaultRadius = 20; // km
  static const int offerExpirationMinutes = 5;
  static const double defaultZoom = 15.0;
}