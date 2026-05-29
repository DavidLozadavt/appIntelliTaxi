import 'dart:async';
import 'dart:collection';

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:intellitaxi/core/diagnostics/native_diagnostics_helper.dart';
import 'package:intellitaxi/core/services/app_logger.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Evento reciente de diagnóstico (arranque, lifecycle, alertas nativas).
class DiagnosticEvent {
  DiagnosticEvent({
    required this.at,
    required this.category,
    required this.message,
    this.extra,
  });

  final DateTime at;
  final String category;
  final String message;
  final String? extra;

  String format() {
    final ts =
        '${at.hour.toString().padLeft(2, '0')}:'
        '${at.minute.toString().padLeft(2, '0')}:'
        '${at.second.toString().padLeft(2, '0')}.'
        '${at.millisecond.toString().padLeft(3, '0')}';
    final tail = extra == null || extra!.isEmpty ? '' : ' | $extra';
    return '[$ts][$category] $message$tail';
  }
}

/// Registro en memoria + Crashlytics (release) para investigar cierres / reinicios.
class AppDiagnostics {
  AppDiagnostics._();

  static const int _maxEvents = 120;
  static final ListQueue<DiagnosticEvent> _events = ListQueue();
  static final Stopwatch _launchStopwatch = Stopwatch();
  static final Stopwatch _activeStopwatch = Stopwatch();
  static int _sessionId = 0;
  static String? _lastPhase;
  static int _lastPhaseWallMs = 0;
  static int _lastPhaseActiveMs = 0;
  static int _pausedWallMs = 0;
  static DateTime? _pausedAt;
  static bool _isInForeground = true;
  static Completer<void>? _resumeCompleter;
  static bool _crashlyticsLogs = false;

  static int get sessionId => _sessionId;
  static int get pausedWallMs => _pausedWallMs;
  static int get activeElapsedMs => _activeStopwatch.elapsedMilliseconds;
  static int get wallElapsedMs => _launchStopwatch.elapsedMilliseconds;

  static void enableCrashlyticsLogs() {
    _crashlyticsLogs = true;
  }

  /// Llamar al inicio de [main].
  static void markLaunch() {
    _sessionId++;
    _launchStopwatch
      ..reset()
      ..start();
    _activeStopwatch
      ..reset()
      ..start();
    _lastPhase = null;
    _lastPhaseWallMs = 0;
    _lastPhaseActiveMs = 0;
    _pausedWallMs = 0;
    _pausedAt = null;
    _isInForeground = true;
    _resumeCompleter = null;
    record(
      'session',
      'Nueva sesión Dart #$_sessionId',
      extra: kDebugMode ? 'debug' : 'release',
    );
  }

  /// Fases de arranque con tiempo en pared y tiempo activo (sin pausas).
  static void phase(String name) {
    final wall = _launchStopwatch.elapsedMilliseconds;
    final active = _activeStopwatch.elapsedMilliseconds;
    final deltaWall = _lastPhase == null ? wall : wall - _lastPhaseWallMs;
    final deltaActive =
        _lastPhase == null ? active : active - _lastPhaseActiveMs;
    _lastPhase = name;
    _lastPhaseWallMs = wall;
    _lastPhaseActiveMs = active;
    record(
      'bootstrap',
      name,
      extra:
          'wall ${wall}ms (+${deltaWall}ms) | activo ${active}ms (+${deltaActive}ms)',
    );
  }

  static void record(
    String category,
    String message, {
    String? extra,
  }) {
    final event = DiagnosticEvent(
      at: DateTime.now(),
      category: category,
      message: message,
      extra: extra,
    );
    _events.addLast(event);
    while (_events.length > _maxEvents) {
      _events.removeFirst();
    }

    final line = event.format();
    if (kDebugMode) {
      debugPrint('DIAG $line');
    }

    if (_crashlyticsLogs && !kDebugMode) {
      try {
        FirebaseCrashlytics.instance.log(line);
      } catch (_) {}
    }
  }

  static void handleLifecycle(AppLifecycleState state) {
    final hint = _lifecycleHint(state);
    record('lifecycle', state.name, extra: hint);

    if (state == AppLifecycleState.resumed) {
      if (_pausedAt != null) {
        final pauseMs = DateTime.now().difference(_pausedAt!).inMilliseconds;
        _pausedWallMs += pauseMs;
        record(
          'lifecycle',
          'volvió a primer plano',
          extra: 'estuvo en pausa ${pauseMs}ms (acumulado ${_pausedWallMs}ms)',
        );
        _pausedAt = null;
      }
      _isInForeground = true;
      if (!_activeStopwatch.isRunning) {
        _activeStopwatch.start();
      }
      final pending = _resumeCompleter;
      _resumeCompleter = null;
      if (pending != null && !pending.isCompleted) {
        pending.complete();
      }
      return;
    }

    if (state == AppLifecycleState.detached) {
      _isInForeground = false;
      if (_activeStopwatch.isRunning) {
        _activeStopwatch.stop();
      }
      return;
    }

    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _pausedAt ??= DateTime.now();
      _isInForeground = false;
      if (_activeStopwatch.isRunning) {
        _activeStopwatch.stop();
      }
    }
  }

  static String? _lifecycleHint(AppLifecycleState state) {
    return switch (state) {
      AppLifecycleState.inactive =>
        'suele ser diálogo de permisos, notificación o cambio rápido de app',
      AppLifecycleState.paused => 'app en segundo plano',
      AppLifecycleState.hidden => 'ventana oculta (Android 14+)',
      AppLifecycleState.resumed => null,
      AppLifecycleState.detached => 'motor Flutter desmontándose',
    };
  }

  /// Espera a que el usuario vuelva (p. ej. tras cerrar permisos) antes de FCM/Pusher.
  static Future<void> waitForForeground({
    Duration timeout = const Duration(minutes: 2),
    String reason = '',
  }) async {
    if (_isInForeground) return;
    record(
      'bootstrap',
      'esperando primer plano',
      extra: reason.isEmpty ? null : reason,
    );
    final completer = Completer<void>();
    _resumeCompleter = completer;
    try {
      await completer.future.timeout(timeout);
      record('bootstrap', 'primer plano listo', extra: reason);
    } on TimeoutException {
      record(
        'bootstrap',
        'timeout esperando primer plano — continúa igual',
        extra: reason,
      );
    } finally {
      if (identical(_resumeCompleter, completer)) {
        _resumeCompleter = null;
      }
    }
  }

  static void recordError(
    String context, {
    Object? error,
    StackTrace? stackTrace,
  }) {
    record(
      'error',
      context,
      extra: error?.toString(),
    );
    if (stackTrace != null && kDebugMode) {
      AppLogger.e(context, tag: 'Diag', error: error, stackTrace: stackTrace);
    }
  }

  static List<DiagnosticEvent> recentEvents() => List.unmodifiable(_events);

  static Future<String> buildReport() async {
    final buffer = StringBuffer();
    PackageInfo? info;
    try {
      info = await PackageInfo.fromPlatform();
    } catch (_) {}

    buffer.writeln('=== IntelliTaxi — Diagnóstico ===');
    buffer.writeln(
      'App: ${info?.appName ?? '?'} ${info?.version ?? '?'} (${info?.buildNumber ?? '?'})',
    );
    buffer.writeln('Sesión Dart: #$_sessionId');
    buffer.writeln(
      'Tiempo wall: ${wallElapsedMs}ms | tiempo activo: ${activeElapsedMs}ms | '
      'en pausa (acum): ${_pausedWallMs}ms',
    );
    buffer.writeln(
      'Lifecycle actual: ${WidgetsBinding.instance.lifecycleState?.name ?? 'null'}',
    );
    buffer.writeln('Modo: ${kDebugMode ? 'debug' : 'release/profile'}');
    buffer.writeln('');

    try {
      final native = await NativeDiagnosticsHelper.fetchSnapshot();
      buffer.writeln('--- Android nativo ---');
      for (final entry in native.entries) {
        buffer.writeln('${entry.key}: ${entry.value}');
      }
      buffer.writeln('');
    } catch (e) {
      buffer.writeln('--- Android nativo: no disponible ($e) ---');
      buffer.writeln('');
    }

    buffer.writeln('--- Eventos recientes (${_events.length}) ---');
    for (final e in _events) {
      buffer.writeln(e.format());
    }
    return buffer.toString();
  }
}
