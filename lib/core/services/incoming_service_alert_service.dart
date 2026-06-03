import 'dart:async';

import 'package:intellitaxi/core/services/app_logger.dart';
import 'package:intellitaxi/core/services/voice_alert_service.dart';
import 'package:intellitaxi/features/conductor/services/conductor_notification_sound_service.dart';

/// Alerta al entrar en «Llegando»: un beep por servicio y ventana corta.
class IncomingServiceAlertService {
  IncomingServiceAlertService._();

  /// Un beep «llegando» por [servicioId] en esta ventana (todas las rutas).
  static final Map<String, DateTime> _ultimoBeepLlegandoPorServicio = {};
  static const Duration _ventanaBeepLlegando = Duration(seconds: 12);

  /// [dedupeKey] formato `servicioId:llegando` o `servicioId:exclusiva`.
  /// [beepInmediato]: exclusiva → «Llegando» sin esperar cola.
  static Future<void> alert({
    required bool includeVoice,
    String? dedupeKey,
    bool beepInmediato = false,
  }) async {
    final esLlegando = dedupeKey != null && dedupeKey.endsWith(':llegando');
    final servicioId = _servicioIdDesdeKey(dedupeKey);

    if (esLlegando && servicioId != null) {
      final now = DateTime.now();
      final prev = _ultimoBeepLlegandoPorServicio[servicioId];
      if (prev != null && now.difference(prev) < _ventanaBeepLlegando) {
        return;
      }
      _ultimoBeepLlegandoPorServicio[servicioId] = now;
    }

    try {
      if (beepInmediato) {
        unawaited(
          ConductorNotificationSoundService.playNewServiceSound(priority: true),
        );
        if (includeVoice) {
          unawaited(
            Future<void>.delayed(
              const Duration(milliseconds: 400),
              VoiceAlertService.announceNewService,
            ),
          );
        }
        return;
      }
      await ConductorNotificationSoundService.playNewServiceSound();
      if (includeVoice) {
        await VoiceAlertService.announceNewService();
      }
    } catch (e) {
      AppLogger.d('⚠️ Alerta solicitud entrante: $e');
    }
  }

  static String? _servicioIdDesdeKey(String? dedupeKey) {
    if (dedupeKey == null || dedupeKey.isEmpty) return null;
    final i = dedupeKey.indexOf(':');
    if (i <= 0) return dedupeKey;
    return dedupeKey.substring(0, i);
  }

  /// Rebote a «Llegando» tras TTL del overlay.
  static void permitirNuevoBeepLlegando(String solicitudId) {
    final id = solicitudId.trim();
    if (id.isEmpty) return;
    _ultimoBeepLlegandoPorServicio.remove(id);
  }

  static Future<void> cancel() async {
    await Future.wait([
      ConductorNotificationSoundService.cancelIncomingPlayback(),
      VoiceAlertService.stop(),
    ]);
  }
}
