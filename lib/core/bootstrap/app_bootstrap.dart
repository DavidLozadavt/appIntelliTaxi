import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:intellitaxi/config/app_config.dart';
import 'package:intellitaxi/core/diagnostics/app_diagnostics.dart';
import 'package:intellitaxi/core/services/app_logger.dart';
import 'package:intellitaxi/core/utils/image_load_errors.dart';

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
    final benignImage = shouldSuppressImageCrashReport(
      error: error,
      stack: stack,
    );
    AppDiagnostics.recordError(
      benignImage ? 'image_load' : (fatal ? 'fatal_error' : 'error'),
      error: error,
      stackTrace: stack,
    );
    if (!_crashlyticsReady) return;
    if (benignImage) {
      FirebaseCrashlytics.instance.recordError(
        error,
        stack,
        fatal: false,
        reason: 'benign_image_decode',
      );
      return;
    }
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: fatal);
  }

  static void installErrorHandlers() {
    FlutterError.onError = (details) {
      final benignImage = shouldSuppressImageCrashReport(
        error: details.exception,
        stack: details.stack,
      );

      AppDiagnostics.recordError(
        benignImage ? 'image_load' : 'FlutterError',
        error: details.exception,
        stackTrace: details.stack,
      );

      if (_crashlyticsReady) {
        if (benignImage) {
          FirebaseCrashlytics.instance.recordError(
            details.exception,
            details.stack,
            fatal: false,
            reason: 'benign_image_decode',
          );
        } else {
          FirebaseCrashlytics.instance.recordFlutterFatalError(details);
        }
      }

      if (benignImage) {
        AppLogger.d(
          'Imagen no decodificada (placeholder): ${details.exception}',
          tag: 'ImageLoad',
        );
        return;
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
      if (shouldSuppressImageCrashReport(error: error, stack: stack)) {
        recordError(error, stack, fatal: false);
        return true;
      }
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
    if (AppConfig.googleMapsApiKey.trim().isEmpty) {
      missing.add('GOOGLE_MAPS_API_KEY');
    }
    if (AppConfig.socketAppKey.isEmpty) {
      missing.add('SOCKET_APP_KEY');
    }

    return missing;
  }

  static void logConfigWarnings() {
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
