import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:intellitaxi/core/network/mobile_network_config.dart';
import 'package:intellitaxi/core/services/app_logger.dart';

/// Obtiene el token FCM sin bloquear flujos críticos (login, arranque).
///
/// En algunos Android (GMS desactualizado, sin red, ROM sin Play Services)
/// `getToken()` lanza `SERVICE_NOT_AVAILABLE`; el login debe seguir con token vacío.
class FcmTokenResolver {
  FcmTokenResolver._();

  static const _tag = 'FCM';

  /// Token para auth/API. `null` si FCM no está disponible en este dispositivo.
  ///
  /// En login usar [maxWait] (p. ej. [MobileNetworkConfig.fcmMaxWaitBeforeLogin])
  /// para no retrasar el ingreso en datos móviles lentos.
  static Future<String?> resolveForAuth({Duration? maxWait}) async {
    final future = _resolveInternal();
    if (maxWait == null) return future;
    try {
      return await future.timeout(maxWait, onTimeout: () => null);
    } catch (_) {
      return null;
    }
  }

  static Future<String?> _resolveInternal() async {
    final maxAttempts = MobileNetworkConfig.fcmMaxAttempts;
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        final token = await FirebaseMessaging.instance
            .getToken()
            .timeout(MobileNetworkConfig.fcmAttemptTimeout);
        if (token != null && token.isNotEmpty) {
          return token;
        }
        AppLogger.w(
          'Token FCM vacío (intento $attempt/$maxAttempts)',
          tag: _tag,
        );
      } catch (e, stackTrace) {
        final retryable = _isRetryable(e);
        AppLogger.w(
          'No se pudo obtener token FCM (intento $attempt/$maxAttempts)'
          '${retryable && attempt < maxAttempts ? ', reintentando…' : ''}',
          tag: _tag,
        );
        AppLogger.e(
          'Detalle token FCM',
          tag: _tag,
          error: e,
          stackTrace: stackTrace,
        );
        if (!retryable || attempt >= maxAttempts) {
          return null;
        }
        await Future<void>.delayed(MobileNetworkConfig.fcmRetryDelay);
      }
    }
    return null;
  }

  static bool _isRetryable(Object error) {
    final text = error.toString().toUpperCase();
    return text.contains('SERVICE_NOT_AVAILABLE') ||
        text.contains('IOEXCEPTION') ||
        text.contains('UNAVAILABLE') ||
        text.contains('TIMEOUT') ||
        text.contains('NETWORK');
  }
}
