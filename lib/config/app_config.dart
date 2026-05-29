// lib/config/app_config.dart
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  // URL base de tu API Laravel
  static String get baseUrl {
    final raw = dotenv.env['BASE_URL'] ?? 'https://tu-servidor.com/api/';
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return 'https://tu-servidor.com/api/';
    return '${trimmed.replaceAll(RegExp(r'/+$'), '')}/';
  }

  // Google Maps API Key
  static String get googleMapsApiKey => dotenv.env['GOOGLE_MAPS_API_KEY'] ?? '';

  // Pusher Configuration (Primary)
  static String get pusherAppKeyRaw =>
      (dotenv.env['PUSHER_APP_KEY'] ?? '').trim();

  /// Si [PUSHER_APP_KEY] está vacío, usa [PUSHER_SECONDARY_APP_KEY] para Primary.
  static String get pusherAppKey {
    if (pusherAppKeyRaw.isNotEmpty) return pusherAppKeyRaw;
    return pusherSecondaryAppKey;
  }

  static bool get pusherPrimaryUsesSecondaryFallback =>
      pusherAppKeyRaw.isEmpty && pusherSecondaryAppKey.isNotEmpty;

  static String get pusherCluster => dotenv.env['PUSHER_CLUSTER'] ?? 'mt1';

  // Pusher Configuration (Secondary)
  static String get pusherSecondaryAppKey =>
      (dotenv.env['PUSHER_SECONDARY_APP_KEY'] ?? '').trim();
  static String get pusherSecondaryCluster => 'mt1';

  // Configuración de la app
  static int get defaultRadius =>
      int.tryParse(dotenv.env['DEFAULT_RADIUS'] ?? '20') ?? 20;
  static int get offerExpirationMinutes =>
      int.tryParse(dotenv.env['OFFER_EXPIRATION_MINUTES'] ?? '5') ?? 5;
  static double get defaultZoom =>
      double.tryParse(dotenv.env['DEFAULT_ZOOM'] ?? '15.0') ?? 15.0;
}
