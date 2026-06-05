// lib/config/app_config.dart
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  /// Primera variable definida en `.env` (alineado con Laravel `SOCKET_*`).
  static String _envFirst(List<String> keys, {String fallback = ''}) {
    for (final key in keys) {
      final value = dotenv.env[key]?.trim();
      if (value != null && value.isNotEmpty) return value;
    }
    return fallback;
  }

  // URL base de tu API Laravel
  static String get baseUrl {
    final raw = dotenv.env['BASE_URL'] ?? 'https://tu-servidor.com/api/';
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return 'https://tu-servidor.com/api/';
    return '${trimmed.replaceAll(RegExp(r'/+$'), '')}/';
  }

  // Google Maps API Key
  static String get googleMapsApiKey => dotenv.env['GOOGLE_MAPS_API_KEY'] ?? '';

  // WebSocket taxis — Soketi / laravel-websockets en VPS (NO Pusher.com)
  static String get socketAppKey => _envFirst(['SOCKET_APP_KEY']);

  /// Misma key que [socketAppKey] (una sola conexión al VPS).
  static String get socketAppKeySecondary => socketAppKey;

  static String get socketCluster =>
      _envFirst(['SOCKET_APP_CLUSTER'], fallback: 'mt1');

  static String get socketHost => _envFirst(['SOCKET_HOST']);

  static int get socketPort {
    final raw = _envFirst(['SOCKET_PORT']);
    if (raw.isNotEmpty) {
      return int.tryParse(raw) ?? (socketUseTls ? 443 : 80);
    }
    return socketUseTls ? 443 : 80;
  }

  static bool get socketUseTls {
    final scheme = _envFirst(['SOCKET_SCHEME']).toLowerCase();
    if (scheme == 'https' || scheme == 'wss') return true;
    if (scheme == 'http' || scheme == 'ws') return false;
    if (socketHost.isNotEmpty) return false;
    return true;
  }

  // Configuración de la app
  static int get defaultRadius =>
      int.tryParse(dotenv.env['DEFAULT_RADIUS'] ?? '20') ?? 20;
  static int get offerExpirationMinutes =>
      int.tryParse(dotenv.env['OFFER_EXPIRATION_MINUTES'] ?? '5') ?? 5;
  static double get defaultZoom =>
      double.tryParse(dotenv.env['DEFAULT_ZOOM'] ?? '15.0') ?? 15.0;

  /// POST autenticado para actualizar `device_token` (FCM) sin volver a hacer login.
  static String get deviceTokenSyncPath {
    final raw = dotenv.env['DEVICE_TOKEN_SYNC_PATH'] ?? 'update_device_token';
    final trimmed = raw.trim();
    return trimmed.isEmpty ? 'update_device_token' : trimmed;
  }
}
