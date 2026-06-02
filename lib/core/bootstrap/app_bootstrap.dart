import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:intellitaxi/config/app_config.dart';
import 'package:intellitaxi/core/diagnostics/app_diagnostics.dart';
import 'package:intellitaxi/core/services/app_logger.dart';

/// Arranque seguro: validación de `.env` y captura de errores en release.
class AppBootstrap {
  AppBootstrap._();

  static bool _crashlyticsReady = false;

  /// Debe llamarse tras [Firebase.initializeApp].
  static Future<void> initCrashlytics() async {
    if (kDebugMode) return;
    await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(true);
    _crashlyticsReady = true;
  }

  static void recordError(
    Object error,
    StackTrace? stack, {
    bool fatal = false,
  }) {
    AppDiagnostics.recordError(
      fatal ? 'fatal_error' : 'error',
      error: error,
      stackTrace: stack,
    );
    if (!_crashlyticsReady) return;
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: fatal);
  }

  static void installErrorHandlers() {
    FlutterError.onError = (details) {
      AppDiagnostics.recordError(
        'FlutterError',
        error: details.exception,
        stackTrace: details.stack,
      );
      if (_crashlyticsReady) {
        FirebaseCrashlytics.instance.recordFlutterFatalError(details);
      }
      AppLogger.e(
        details.exceptionAsString(),
        tag: 'FlutterError',
        error: details.exception,
        stackTrace: details.stack,
      );
      if (kDebugMode) {
        FlutterError.presentError(details);
      }
    };

    PlatformDispatcher.instance.onError = (error, stack) {
      recordError(error, stack, fatal: true);
      AppLogger.e(
        'Uncaught async error',
        tag: 'Platform',
        error: error,
        stackTrace: stack,
      );
      return true;
    };
  }

  /// Claves obligatorias para producción. Devuelve lista de faltantes.
  static List<String> validateProductionConfig() {
    final missing = <String>[];

    if (AppConfig.baseUrl.contains('tu-servidor.com')) {
      missing.add('BASE_URL (valor por defecto / placeholder)');
    }
    if (AppConfig.pusherAppKey.isEmpty) {
      missing.add('PUSHER_APP_KEY o PUSHER_SECONDARY_APP_KEY');
    }

    return missing;
  }

  static void logConfigWarnings() {
    if (AppConfig.pusherPrimaryUsesSecondaryFallback) {
      AppLogger.w(
        'PUSHER_APP_KEY vacío: Primary usará PUSHER_SECONDARY_APP_KEY',
        tag: 'Bootstrap',
      );
    }

    final missing = validateProductionConfig();
    if (missing.isEmpty) return;

    final message =
        'Config incompleta (${missing.join(', ')}). Revisa el archivo .env.';
    if (kDebugMode) {
      AppLogger.w(message, tag: 'Bootstrap');
    } else {
      AppLogger.e(message, tag: 'Bootstrap');
    }
  }
}
