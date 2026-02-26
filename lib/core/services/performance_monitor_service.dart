import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:intellitaxi/core/services/app_logger.dart';
import 'dart:ui' as ui;

class PerformanceMonitorService {
  static bool _initialized = false;
  static int _totalFrames = 0;
  static int _jankyFrames = 0;
  static DateTime _lastReport = DateTime.now();

  static void _handleTimings(List<FrameTiming> timings) {
    for (final timing in timings) {
      _totalFrames++;
      if (_isJanky(timing)) {
        _jankyFrames++;
      }
    }

    final now = DateTime.now();
    if (kDebugMode && now.difference(_lastReport).inSeconds >= 30) {
      final ratio = _totalFrames == 0
          ? 0.0
          : (_jankyFrames / _totalFrames) * 100;
      AppLogger.i(
        'Frames=$_totalFrames | Janky=$_jankyFrames (${ratio.toStringAsFixed(1)}%)',
        tag: 'Perf',
      );
      _lastReport = now;
    }
  }

  static void initialize() {
    if (_initialized) return;

    // Evita assertion de SchedulerBinding cuando otra librería tomó onReportTimings.
    final currentCallback = ui.PlatformDispatcher.instance.onReportTimings;
    if (currentCallback != null) {
      AppLogger.w(
        'Frame timings desactivado: onReportTimings ya está en uso por otra integración.',
        tag: 'Perf',
      );
      return;
    }

    _initialized = true;
    SchedulerBinding.instance.addTimingsCallback(_handleTimings);
  }

  static bool _isJanky(FrameTiming t) {
    // 16.6ms budget (60fps) * 2 para tolerar carga moderada.
    const budgetMicros = 33333;
    return t.buildDuration.inMicroseconds > budgetMicros ||
        t.rasterDuration.inMicroseconds > budgetMicros;
  }
}
