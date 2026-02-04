// lib/config/app_config.dart
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  // URL base de tu API Laravel
  static String get baseUrl => dotenv.env['BASE_URL'] ?? 'https://tu-servidor.com/api/';
  
  // Google Maps API Key
  static String get googleMapsApiKey => dotenv.env['GOOGLE_MAPS_API_KEY'] ?? '';
  
  // Pusher Configuration
  static String get pusherAppKey => dotenv.env['PUSHER_APP_KEY'] ?? '';
  static String get pusherCluster => dotenv.env['PUSHER_CLUSTER'] ?? 'mt1';
  
  // Configuración de la app
  static int get defaultRadius => int.tryParse(dotenv.env['DEFAULT_RADIUS'] ?? '20') ?? 20;
  static int get offerExpirationMinutes => int.tryParse(dotenv.env['OFFER_EXPIRATION_MINUTES'] ?? '5') ?? 5;
  static double get defaultZoom => double.tryParse(dotenv.env['DEFAULT_ZOOM'] ?? '15.0') ?? 15.0;
}