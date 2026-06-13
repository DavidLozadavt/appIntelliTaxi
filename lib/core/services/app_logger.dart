import 'package:flutter/foundation.dart';

enum LogLevel { debug, info, warning, error }

class AppLogger {
  static const bool _allowVerboseInDebug = true;

  static void d(Object? message, {String? tag}) {
    _log(LogLevel.debug, message, tag: tag);
  }

  static void i(Object? message, {String? tag}) {
    _log(LogLevel.info, message, tag: tag);
  }

  static void w(Object? message, {String? tag}) {
    _log(LogLevel.warning, message, tag: tag);
  }

  static void e(
    String message, {
    String? tag,
    Object? error,
    StackTrace? stackTrace,
  }) {
    final errorSuffix = error == null ? '' : ' | error=$error';
    final stackSuffix = stackTrace == null ? '' : '\n$stackTrace';
    _log(LogLevel.error, '$message$errorSuffix$stackSuffix', tag: tag);
  }

  static void _log(LogLevel level, Object? message, {String? tag}) {
    if (!kDebugMode && level == LogLevel.debug) return;
    // En release: INFO solo para tags críticos (overlay, GPS background).
    if (!kDebugMode && level == LogLevel.info) {
      const releaseInfoTags = {'DriverOverlay', 'BackgroundLocation'};
      if (tag == null || !releaseInfoTags.contains(tag)) return;
    }
    if (kDebugMode && !_allowVerboseInDebug && level == LogLevel.debug) return;

    final levelText = switch (level) {
      LogLevel.debug => 'DEBUG',
      LogLevel.info => 'INFO',
      LogLevel.warning => 'WARN',
      LogLevel.error => 'ERROR',
    };
    final scope = tag == null || tag.isEmpty ? '' : '[$tag] ';
    debugPrint('$levelText $scope${message ?? ''}');
  }
}
