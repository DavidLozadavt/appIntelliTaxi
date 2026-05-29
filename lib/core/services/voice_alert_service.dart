import 'package:flutter_tts/flutter_tts.dart';
import 'package:intellitaxi/core/services/app_logger.dart';

class VoiceAlertService {
  static FlutterTts? _tts;
  static bool _ready = false;
  static DateTime? _lastSpeakAt;

  static Future<void> _ensureReady() async {
    if (_ready) return;

    _tts = FlutterTts();
    await _tts!.setLanguage('es-CO');
    await _tts!.setSpeechRate(0.48);
    await _tts!.setVolume(1.0);
    await _tts!.setPitch(1.0);
    _ready = true;
  }

  static Future<void> announceNewService() async {
    final now = DateTime.now();
    if (_lastSpeakAt != null &&
        now.difference(_lastSpeakAt!) < const Duration(seconds: 5)) {
      return;
    }

    try {
      await _ensureReady();
      _lastSpeakAt = now;
      await _tts!.speak('Nuevo servicio disponible');
    } catch (e) {
      AppLogger.d('⚠️ No se pudo reproducir alerta de voz: $e');
    }
  }

  static Future<void> stop() async {
    try {
      await _tts?.stop();
    } catch (_) {}
  }

  static Future<void> dispose() async {
    try {
      await _tts?.stop();
      _tts = null;
      _ready = false;
      _lastSpeakAt = null;
    } catch (_) {}
  }
}
