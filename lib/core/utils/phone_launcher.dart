import 'package:flutter/material.dart';
import 'package:intellitaxi/core/services/app_logger.dart';
import 'package:url_launcher/url_launcher.dart';

/// Abre el marcador del sistema (`tel:`). En Android 11+ requiere `<queries>` en el manifest.
class PhoneLauncher {
  PhoneLauncher._();

  /// Normaliza a dígitos; añade +57 si es móvil colombiano de 10 dígitos.
  static String normalize(String? raw) {
    if (raw == null) return '';
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return '';

    final buffer = StringBuffer();
    for (var i = 0; i < trimmed.length; i++) {
      final c = trimmed[i];
      if (c == '+' && buffer.isEmpty) {
        buffer.write(c);
      } else if (RegExp(r'\d').hasMatch(c)) {
        buffer.write(c);
      }
    }

    var normalized = buffer.toString();
    if (normalized.startsWith('+')) return normalized;

    final digitsOnly = normalized.replaceAll('+', '');
    if (digitsOnly.length == 10 && digitsOnly.startsWith('3')) {
      return '+57$digitsOnly';
    }
    return digitsOnly;
  }

  /// Abre el marcador. Devuelve `true` si el sistema aceptó el intent.
  static Future<bool> dial(
    String? telefono, {
    BuildContext? context,
    String? emptyMessage,
    String? failureMessage,
  }) async {
    final limpio = normalize(telefono);
    if (limpio.isEmpty) {
      _snack(
        context,
        emptyMessage ?? 'No hay teléfono disponible',
      );
      return false;
    }

    final uri = Uri(scheme: 'tel', path: limpio);
    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        AppLogger.d('⚠️ launchUrl tel devolvió false: $uri');
        _snack(
          context,
          failureMessage ??
              'No se pudo abrir el marcador. Comprueba que haya una app de llamadas.',
        );
      }
      return launched;
    } catch (e, st) {
      AppLogger.e('Error abriendo tel:', error: e, stackTrace: st);
      _snack(
        context,
        failureMessage ?? 'No se pudo abrir la aplicación de llamadas',
      );
      return false;
    }
  }

  static void _snack(BuildContext? context, String message) {
    if (context == null || !context.mounted) return;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 3)),
    );
  }

  /// Dígitos para `wa.me` (código país + número, sin +).
  static String whatsappPhoneDigits(String? raw) {
    final limpio = normalize(raw);
    if (limpio.isEmpty) return '';
    return limpio.startsWith('+') ? limpio.substring(1) : limpio;
  }

  /// Mensaje estándar del conductor al pasajero por WhatsApp.
  static String mensajeConductorParaPasajero({
    required String nombreConductor,
    String? placa,
  }) {
    final nombre = nombreConductor.trim().isNotEmpty
        ? nombreConductor.trim()
        : 'tu conductor';
    final placaNorm = placa?.trim();
    if (placaNorm != null && placaNorm.isNotEmpty) {
      return 'Hola, soy $nombre, conductor Taxbel. Placa ${placaNorm.toUpperCase()}. Voy en camino a recogerte.';
    }
    return 'Hola, soy $nombre, conductor Taxbel. Voy en camino a recogerte.';
  }

  static List<Uri> _whatsappUris(String digits, {String? text}) {
    final trimmed = text?.trim() ?? '';
    final hasText = trimmed.isNotEmpty;

    if (hasText) {
      // Solo enlaces que incluyen el mensaje (nunca abrir chat vacío si hay texto).
      return [
        Uri(
          scheme: 'whatsapp',
          host: 'send',
          queryParameters: {
            'phone': digits,
            'text': trimmed,
          },
        ),
        Uri.https('api.whatsapp.com', '/send', {
          'phone': digits,
          'text': trimmed,
        }),
        Uri.https('wa.me', digits, {'text': trimmed}),
      ];
    }

    return [
      Uri(
        scheme: 'whatsapp',
        host: 'send',
        queryParameters: {'phone': digits},
      ),
      Uri.https('api.whatsapp.com', '/send', {'phone': digits}),
      Uri.https('wa.me', digits),
    ];
  }

  /// Abre WhatsApp con [mensaje] opcional (app externa).
  static Future<bool> openWhatsApp(
    String? telefono, {
    String? mensaje,
    BuildContext? context,
    String? emptyMessage,
    String? failureMessage,
  }) async {
    final digits = whatsappPhoneDigits(telefono);
    if (digits.isEmpty) {
      _snack(
        context,
        emptyMessage ?? 'No hay teléfono para WhatsApp',
      );
      return false;
    }

    final uris = _whatsappUris(digits, text: mensaje);
    Object? lastError;

    for (final uri in uris) {
      try {
        AppLogger.d('Intentando WhatsApp: $uri');
        final launched = await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
        if (launched) return true;
      } catch (e, st) {
        lastError = e;
        AppLogger.d('WhatsApp intent falló: $uri → $e\n$st');
      }
    }

    AppLogger.e('Error abriendo WhatsApp', error: lastError);
    _snack(
      context,
      failureMessage ??
          'No se pudo abrir WhatsApp. Instálalo o revisa el número.',
    );
    return false;
  }
}
