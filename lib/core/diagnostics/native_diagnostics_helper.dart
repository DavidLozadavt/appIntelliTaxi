import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Snapshot de Activity / proceso desde Android.
class NativeDiagnosticsHelper {
  NativeDiagnosticsHelper._();

  static const MethodChannel _channel =
      MethodChannel('com.virtualt.intellitaxi/app');

  static bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static Future<void> openBatteryOptimizationSettings() async {
    if (!_isAndroid) return;
    try {
      await _channel.invokeMethod<void>('openBatteryOptimizationSettings');
    } catch (_) {}
  }

  static Future<Map<String, String>> fetchSnapshot() async {
    if (!_isAndroid) {
      return {'platform': defaultTargetPlatform.name};
    }
    final raw = await _channel.invokeMethod<Map<Object?, Object?>>(
      'getDiagnosticsSnapshot',
    );
    if (raw == null) return {};
    return raw.map(
      (key, value) => MapEntry(key.toString(), value?.toString() ?? ''),
    );
  }
}
