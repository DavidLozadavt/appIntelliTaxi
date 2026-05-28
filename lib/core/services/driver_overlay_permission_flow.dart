import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:intellitaxi/core/services/driver_overlay_service.dart';
import 'package:intellitaxi/core/theme/app_colors.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Flujo educativo para permiso «Mostrar sobre otras apps» (burbuja al minimizar).
///
/// Estilo apps de movilidad: explicar el porqué al iniciar turno, no pedir en frío al abrir la app.
class DriverOverlayPermissionFlow {
  DriverOverlayPermissionFlow._();

  static const String _keyLastDeclinedMs = 'driver_overlay_declined_ms_v1';
  static const String _keyHomePromptDone = 'driver_overlay_home_prompt_done_v1';
  static const int _remindAfterDeclineDays = 10;

  static bool _dialogVisible = false;
  static bool _homePromptInFlight = false;

  static bool get isSupported => DriverOverlayService.instance.isPlatformSupported;

  /// Al entrar al mapa del conductor: diálogo **una vez** si falta permiso; silencio si ya está activo.
  static Future<void> promptOnConductorHomeEntered(BuildContext context) async {
    if (!context.mounted || _homePromptInFlight || _dialogVisible) return;
    if (!isSupported) return;

    _homePromptInFlight = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final granted = await DriverOverlayService.instance.hasPermission();
      if (!context.mounted) return;

      if (granted) {
        await prefs.setBool(_keyHomePromptDone, true);
        return;
      }

      if (prefs.getBool(_keyHomePromptDone) == true) {
        final lastDeclined = prefs.getInt(_keyLastDeclinedMs);
        if (lastDeclined == null) return;
        final declinedAt = DateTime.fromMillisecondsSinceEpoch(lastDeclined);
        if (DateTime.now().difference(declinedAt).inDays <
            _remindAfterDeclineDays) {
          return;
        }
      }

      if (!context.mounted) return;
      await _showEducationDialog(
        context,
        intro:
            'Para no perder servicios cuando uses WhatsApp, llamadas o el mapa, '
            'activa la burbuja de TaxbelUrbano sobre otras apps.',
      );
      await prefs.setBool(_keyHomePromptDone, true);
    } finally {
      _homePromptInFlight = false;
    }
  }

  /// Tras iniciar turno: sin mensajes si la burbuja ya está configurada.
  static Future<void> promptAfterShiftStarted(BuildContext context) async {
    if (!context.mounted || !isSupported) return;
    if (await DriverOverlayService.instance.hasPermission()) return;

    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_keyHomePromptDone) == true) return;

    if (!context.mounted) return;
    await promptOnConductorHomeEntered(context);
  }

  /// Reinicia avisos (p. ej. cerrar sesión en otro dispositivo).
  static Future<void> resetStoredPromptState() async {
    _dialogVisible = false;
    _homePromptInFlight = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyHomePromptDone);
    await prefs.remove(_keyLastDeclinedMs);
  }

  /// @deprecated Use [resetStoredPromptState].
  static void resetSessionPrompts() {
    unawaited(resetStoredPromptState());
  }

  /// Recordatorio suave desde ajustes o si el conductor lo solicita.
  static Future<void> promptFromSettings(BuildContext context) async {
    if (!isSupported) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('La burbuja flotante solo está disponible en Android.'),
        ),
      );
      return;
    }
    if (await DriverOverlayService.instance.hasPermission()) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ya tienes activada la burbuja sobre otras apps.'),
          backgroundColor: Colors.green,
        ),
      );
      return;
    }
    if (!context.mounted) return;
    await _showEducationDialog(context, fromSettings: true);
  }

  static Future<void> _showEducationDialog(
    BuildContext context, {
    bool fromSettings = false,
    String? intro,
  }) async {
    if (_dialogVisible) return;
    _dialogVisible = true;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    bool continuar = false;
    try {
      continuar = await showDialog<bool>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: !fromSettings,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Iconsax.layer_copy,
                  color: AppColors.accent,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Burbuja al minimizar',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                intro ??
                    (fromSettings
                        ? 'Activa el acceso para volver a TaxbelUrbano con un toque mientras usas otras apps (mapas, llamadas, WhatsApp).'
                        : 'Con el turno activo, verás una burbuja de TaxbelUrbano cuando salgas de la app. Así no pierdes servicios nuevos.'),
                style: TextStyle(
                  fontSize: 14,
                  height: 1.45,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
              ),
              const SizedBox(height: 14),
              _benefitRow(
                Iconsax.notification_copy,
                'Alertas de servicio aunque estés en otra app',
                isDark: isDark,
              ),
              const SizedBox(height: 8),
              _benefitRow(
                Iconsax.mouse_copy,
                'Un toque para volver al mapa y aceptar viajes',
                isDark: isDark,
              ),
              const SizedBox(height: 8),
              _benefitRow(
                Iconsax.shield_tick_copy,
                'Solo mientras tu turno está activo',
                isDark: isDark,
              ),
              const SizedBox(height: 12),
              Text(
                'En la siguiente pantalla elige «Permitir» o «Mostrar sobre otras apps».',
                style: TextStyle(
                  fontSize: 12,
                  height: 1.35,
                  color: isDark ? Colors.white54 : Colors.black54,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Ahora no'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
              ),
              child: const Text('Activar burbuja'),
            ),
          ],
        );
      },
    ) ??
        false;
    } finally {
      _dialogVisible = false;
    }

    if (continuar != true) {
      await _recordDeclined();
      return;
    }
    if (!context.mounted) return;

    final granted = await DriverOverlayService.instance.requestPermissionIfNeeded();
    if (granted) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyHomePromptDone, true);
      return;
    }

    if (!context.mounted) return;
    final abrirAjustes = await showDialog<bool>(
      context: context,
      useRootNavigator: true,
      builder: (ctx) => AlertDialog(
        title: const Text('Permiso necesario'),
        content: const Text(
          'Para mostrar la burbuja, activa «Mostrar sobre otras apps» para TaxbelUrbano en los ajustes del teléfono.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Abrir ajustes'),
          ),
        ],
      ),
    );

    if (abrirAjustes == true) {
      await openAppSettings();
    } else {
      await _recordDeclined();
    }
  }

  static Widget _benefitRow(
    IconData icon,
    String text, {
    required bool isDark,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.accent),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13,
              height: 1.35,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
        ),
      ],
    );
  }

  static Future<void> _recordDeclined() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyLastDeclinedMs, DateTime.now().millisecondsSinceEpoch);
  }
}
