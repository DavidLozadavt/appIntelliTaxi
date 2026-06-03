import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:intellitaxi/core/services/app_logger.dart';

/// Obtiene el token FCM sin bloquear flujos críticos (login, arranque).
///
/// En algunos Android (GMS desactualizado, sin red, ROM sin Play Services)
/// `getToken()` lanza `SERVICE_NOT_AVAILABLE`; el login debe seguir con token vacío.
class FcmTokenResolver {
  FcmTokenResolver._();

  static const _tag = 'FCM';
  static const _attemptTimeout = Duration(seconds: 10);
  static const _retryDelay = Duration(seconds: 2);
  static const _maxAttempts = 2;

  /// Token para auth/API. `null` si FCM no está disponible en este dispositivo.
  static Future<String?> resolveForAuth() async {
    for (var attempt = 1; attempt <= _maxAttempts; attempt++) {
      try {
        final token = await FirebaseMessaging.instance
            .getToken()
            .timeout(_attemptTimeout);
        if (token != null && token.isNotEmpty) {
          return token;
        }
        AppLogger.w(
          'Token FCM vacío (intento $attempt/$_maxAttempts)',
          tag: _tag,
        );
      } catch (e, stackTrace) {
        final retryable = _isRetryable(e);
        AppLogger.w(
          'No se pudo obtener token FCM (intento $attempt/$_maxAttempts)'
          '${retryable && attempt < _maxAttempts ? ', reintentando…' : ''}',
          tag: _tag,
        );
        AppLogger.e(
          'Detalle token FCM',
          tag: _tag,
          error: e,
          stackTrace: stackTrace,
        );
        if (!retryable || attempt >= _maxAttempts) {
          return null;
        }
        await Future<void>.delayed(_retryDelay);
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
