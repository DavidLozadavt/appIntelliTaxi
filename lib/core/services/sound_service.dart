import 'package:audioplayers/audioplayers.dart';
import 'package:intellitaxi/core/services/app_logger.dart';

/// Servicio para reproducir sonidos de notificaciones
class SoundService {
  static AudioPlayer? _player;
  static bool _isInitialized = false;

  /// Inicializa el reproductor de audio
  static Future<void> _initialize() async {
    if (_isInitialized) return;

    try {
      _player = AudioPlayer();
      _isInitialized = true;
      AppLogger.d('🔊 AudioPlayer inicializado correctamente');
    } catch (e) {
      AppLogger.d('⚠️ No se pudo inicializar AudioPlayer: $e');
      _player = null;
      _isInitialized = false;
    }
  }

  /// Reproduce el sonido de nueva oferta (2 veces)
  static Future<void> playNewOfferSound() async {
    await _initialize();

    if (_player == null) {
      AppLogger.d('⚠️ AudioPlayer no disponible, omitiendo sonido');
      return;
    }

    try {
      AppLogger.d('🔊 Reproduciendo sonido de nueva oferta...');

      // Primera reproducción
      await _player!.play(AssetSource('sound/nuevaoferta.mp3'));

      // Esperar tiempo estimado del sonido + pausa
      await Future.delayed(const Duration(milliseconds: 1500));

      // Segunda reproducción
      await _player!.play(AssetSource('sound/nuevaoferta.mp3'));

      AppLogger.d('✅ Sonido reproducido 2 veces');
    } catch (e) {
      AppLogger.d('⚠️ Error reproduciendo sonido (no crítico): $e');
      // No lanzar error, solo loguearlo
    }
  }

  /// Reproduce un sonido personalizado
  static Future<void> playSound(String assetPath, {int times = 1}) async {
    await _initialize();

    if (_player == null) {
      AppLogger.d('⚠️ AudioPlayer no disponible, omitiendo sonido');
      return;
    }

    try {
      for (int i = 0; i < times; i++) {
        await _player!.play(AssetSource(assetPath));

        if (i < times - 1) {
          await Future.delayed(const Duration(milliseconds: 1500));
        }
      }

      AppLogger.d('✅ Sonido reproducido $times veces');
    } catch (e) {
      AppLogger.d('⚠️ Error reproduciendo sonido: $e');
    }
  }

  /// Detiene la reproducción actual
  static Future<void> stop() async {
    try {
      await _player?.stop();
    } catch (e) {
      AppLogger.d('⚠️ Error deteniendo sonido: $e');
    }
  }

  /// Libera los recursos del reproductor
  static void dispose() {
    try {
      _player?.dispose();
      _player = null;
      _isInitialized = false;
    } catch (e) {
      AppLogger.d('⚠️ Error liberando reproductor: $e');
    }
  }
}
