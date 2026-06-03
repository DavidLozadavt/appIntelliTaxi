import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:intellitaxi/core/services/app_logger.dart';
import 'package:intellitaxi/features/conductor/services/conductor_notification_sound_prefs.dart';

/// Reproduce y previsualiza el tono elegido por el conductor.
class ConductorNotificationSoundService {
  ConductorNotificationSoundService._();

  static AudioPlayer? _player;
  static Future<void>? _colaEntrante;
  static bool _cancelIncoming = false;

  static const Duration _maxDuracionTono = Duration(seconds: 8);

  static Future<void> _ensurePlayer() async {
    _player ??= AudioPlayer();
  }

  /// Cola corta: cada alta en «Llegando» suena (uno tras otro si llegan varios).
  /// [priority]: reproduce ya (p. ej. exclusiva → «Llegando»), sin esperar la cola.
  static Future<void> playNewServiceSound({bool priority = false}) {
    if (priority) {
      return _playNewServiceSoundBody();
    }
    final prev = _colaEntrante ?? Future.value();
    _colaEntrante = prev.then((_) => _playNewServiceSoundBody());
    return _colaEntrante!;
  }

  static Future<void> cancelIncomingPlayback() async {
    _cancelIncoming = true;
    await stopNewServiceSound();
  }

  static Future<void> _playNewServiceSoundBody() async {
    _cancelIncoming = false;
    try {
      final option = await ConductorNotificationSoundPrefs.getSelectedOption();
      await _playAssetToCompletion(option.assetPath);
    } catch (e) {
      AppLogger.d('❌ Error reproduciendo sonido de servicio: $e');
    }
  }

  static Future<void> preview(String assetPath) async {
    try {
      await stopPreview();
      await _playAssetToCompletion(assetPath);
    } catch (e) {
      AppLogger.d('❌ Error en vista previa de sonido: $e');
    }
  }

  static Future<void> stopPreview() async => stopNewServiceSound();

  static Future<void> stopNewServiceSound() async {
    try {
      await _player?.stop();
    } catch (_) {}
  }

  static Future<void> _playAssetToCompletion(String assetPath) async {
    if (_cancelIncoming) return;
    await _ensurePlayer();
    final player = _player!;
    final completer = Completer<void>();
    late final StreamSubscription<void> sub;
    sub = player.onPlayerComplete.listen((_) {
      if (!completer.isCompleted) completer.complete();
      sub.cancel();
    });
    try {
      await player.stop();
      await player.play(AssetSource(assetPath));
      await completer.future.timeout(
        _maxDuracionTono,
        onTimeout: () => player.stop(),
      );
    } finally {
      await sub.cancel();
    }
  }

  static void dispose() {
    try {
      _player?.dispose();
    } catch (_) {}
    _player = null;
    _colaEntrante = null;
  }
}
