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
  /// [direccionVoz]: recogida (barrio/calle); si viene vacío, fallback genérico.
  static Future<void> alert({
    required bool includeVoice,
    String? dedupeKey,
    bool beepInmediato = false,
    String? direccionVoz,
  }) async {
    final esLlegando = dedupeKey != null && dedupeKey.endsWith(':llegando');
    final servicioId = _servicioIdDesdeKey(dedupeKey);

    if (esLlegando && servicioId != null) {
      final now = DateTime.now();
      final bloqueado = _beepBloqueadoHasta[servicioId];
      if (bloqueado != null) {
        if (now.isBefore(bloqueado)) return;
        _beepBloqueadoHasta.remove(servicioId);
      }
      final prev = _ultimoBeepLlegandoPorServicio[servicioId];
      if (prev != null && now.difference(prev) < _ventanaBeepLlegando) {
        return;
      }
      _ultimoBeepLlegandoPorServicio[servicioId] = now;
    }

    Future<void> reproducirVoz() async {
      if (!includeVoice) return;
      final dir = direccionVoz?.trim() ?? '';
      if (dir.isNotEmpty) {
        await VoiceAlertService.announceNewServiceWithAddress(dir);
      } else {
        await VoiceAlertService.announceNewService();
      }
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
              reproducirVoz,
            ),
          );
        }
        return;
      }
      await ConductorNotificationSoundService.playNewServiceSound();
      await reproducirVoz();
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
    _beepBloqueadoHasta.remove(id);
  }

  /// Tras descartar por radio: no repetir beep aunque llegue Pusher+FCM duplicado.
  static void bloquearBeep(String servicioId, {Duration duracion = const Duration(minutes: 10)}) {
    final id = servicioId.trim();
    if (id.isEmpty) return;
    _beepBloqueadoHasta[id] = DateTime.now().add(duracion);
    _ultimoBeepLlegandoPorServicio[id] = DateTime.now();
  }

  static final Map<String, DateTime> _beepBloqueadoHasta = {};

  static Future<void> cancel() async {
    await Future.wait([
      ConductorNotificationSoundService.cancelIncomingPlayback(),
      VoiceAlertService.stop(),
    ]);
  }
}
