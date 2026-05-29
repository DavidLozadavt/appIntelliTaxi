import 'package:audioplayers/audioplayers.dart';
import 'package:intellitaxi/core/services/app_logger.dart';
import 'package:intellitaxi/features/conductor/services/conductor_notification_sound_prefs.dart';

/// Reproduce y previsualiza el tono elegido por el conductor.
class ConductorNotificationSoundService {
  ConductorNotificationSoundService._();

  static AudioPlayer? _player;

  static Future<void> _ensurePlayer() async {
    _player ??= AudioPlayer();
  }

  /// Sonido al recibir una nueva solicitud (Pusher / realtime).
  static Future<void> playNewServiceSound() async {
    try {
      final option = await ConductorNotificationSoundPrefs.getSelectedOption();
      await _playAsset(option.assetPath);
    } catch (e) {
      AppLogger.d('❌ Error reproduciendo sonido de servicio: $e');
    }
  }

  /// Vista previa al elegir un tono en ajustes.
  static Future<void> preview(String assetPath) async {
    try {
      await stopPreview();
      await _playAsset(assetPath);
    } catch (e) {
      AppLogger.d('❌ Error en vista previa de sonido: $e');
    }
  }

  static Future<void> stopPreview() async => stopNewServiceSound();

  /// Corta el tono de nueva solicitud (p. ej. al aceptar o rechazar).
  static Future<void> stopNewServiceSound() async {
    try {
      await _player?.stop();
    } catch (_) {}
  }

  static Future<void> _playAsset(String assetPath) async {
    await _ensurePlayer();
    final player = _player!;
    await player.stop();
    await player.play(AssetSource(assetPath));
  }

  static void dispose() {
    try {
      _player?.dispose();
    } catch (_) {}
    _player = null;
  }
}
