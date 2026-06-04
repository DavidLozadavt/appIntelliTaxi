// lib/config/app_config.dart
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  /// Primera variable definida en `.env` (alineado con Laravel `SOCKET_*` / `PUSHER_*`).
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

  // WebSocket taxis (Laravel: SOCKET_* en broadcasting; PUSHER_* suele ir vacío)
  static String get pusherAppKeyRaw =>
      _envFirst(['PUSHER_APP_KEY', 'SOCKET_APP_KEY']);

  /// Si primary está vacío, usa secondary / SOCKET_APP_KEY.
  static String get pusherAppKey {
    if (pusherAppKeyRaw.isNotEmpty) return pusherAppKeyRaw;
    return pusherSecondaryAppKey;
  }

  static bool get pusherPrimaryUsesSecondaryFallback =>
      pusherAppKeyRaw.isEmpty && pusherSecondaryAppKey.isNotEmpty;

  static String get pusherCluster =>
      _envFirst(['PUSHER_CLUSTER', 'SOCKET_APP_CLUSTER'], fallback: 'mt1');

  /// Host Soketi / laravel-websockets. Vacío = cluster Pusher.com.
  static String get pusherHost => _envFirst([
        'PUSHER_HOST',
        'PUSHER_SECONDARY_HOST',
        'SOCKET_HOST',
      ]);

  static int get pusherPort {
    final raw = _envFirst([
      'PUSHER_PORT',
      'PUSHER_SECONDARY_PORT',
      'SOCKET_PORT',
    ]);
    if (raw.isNotEmpty) {
      return int.tryParse(raw) ?? (pusherUseTls ? 443 : 80);
    }
    return pusherUseTls ? 443 : 80;
  }

  static bool get pusherUseTls {
    final scheme = _envFirst([
      'PUSHER_SCHEME',
      'PUSHER_SECONDARY_SCHEME',
      'SOCKET_SCHEME',
    ]).toLowerCase();
    if (scheme == 'https' || scheme == 'wss') return true;
    if (scheme == 'http' || scheme == 'ws') return false;
    final useTls = dotenv.env['PUSHER_USE_TLS']?.trim().toLowerCase();
    if (useTls == 'true' || useTls == '1') return true;
    if (useTls == 'false' || useTls == '0') return false;
    // VPS taxi habitual (SOCKET_SCHEME=http): sin TLS si hay host propio
    if (pusherHost.isNotEmpty) return false;
    return true;
  }

  static String get pusherSecondaryAppKey => _envFirst([
        'PUSHER_SECONDARY_APP_KEY',
        'SOCKET_APP_KEY',
        'PUSHER_APP_KEY',
      ]);

  static String get pusherSecondaryCluster => _envFirst([
        'PUSHER_SECONDARY_CLUSTER',
        'PUSHER_CLUSTER',
        'SOCKET_APP_CLUSTER',
      ], fallback: 'mt1');

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
