import 'package:flutter_tts/flutter_tts.dart';
import 'package:intellitaxi/core/services/app_logger.dart';

class VoiceAlertService {
  static FlutterTts? _tts;
  static bool _ready = false;
  static DateTime? _lastSpeakAt;
  static String? _lastSpokenText;

  static Future<void> _ensureReady() async {
    if (_ready) return;

    _tts = FlutterTts();
    await _tts!.setLanguage('es-CO');
    await _tts!.setSpeechRate(0.48);
    await _tts!.setVolume(1.0);
    await _tts!.setPitch(1.0);
    await _tts!.awaitSpeakCompletion(true);
    _ready = true;
  }

  /// Precalienta TTS antes de oferta exclusiva (evita perder el primer speak).
  static Future<void> prepare() => _ensureReady();

  static Future<void> speak(
    String text, {
    Duration minInterval = const Duration(seconds: 2),
    bool force = false,
    bool stopBefore = true,
  }) async {
    final mensaje = text.trim();
    if (mensaje.isEmpty) return;

    final now = DateTime.now();
    if (!force &&
        _lastSpokenText == mensaje &&
        _lastSpeakAt != null &&
        now.difference(_lastSpeakAt!) < minInterval) {
      return;
    }

    try {
      await _ensureReady();
      if (stopBefore) {
        await _tts!.stop();
      }
      _lastSpeakAt = now;
      _lastSpokenText = mensaje;
      await _tts!.speak(mensaje);
    } catch (e) {
      AppLogger.d('⚠️ No se pudo reproducir TTS: $e');
    }
  }

  static Future<void> announceNewService() async {
    await speak(
      'Nuevo servicio disponible',
      minInterval: const Duration(seconds: 2),
      force: true,
      stopBefore: false,
    );
  }

  /// Solo la dirección (barrio, calle…), sin frases extra. Una vez por oferta.
  static Future<void> speakSoloDireccion(
    String texto, {
    bool force = true,
  }) async {
    final mensaje = texto.trim();
    if (mensaje.isEmpty) return;
    await speak(
      mensaje,
      minInterval: const Duration(seconds: 45),
      force: force,
    );
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
      _lastSpokenText = null;
    } catch (_) {}
  }
}
