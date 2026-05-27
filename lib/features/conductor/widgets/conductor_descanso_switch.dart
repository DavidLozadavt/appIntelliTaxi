import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intellitaxi/core/theme/app_colors.dart';
import 'package:intellitaxi/features/conductor/providers/conductor_home_provider.dart';

/// Switch de modo descanso (drawer del conductor).
class ConductorDescansoSwitch extends StatelessWidget {
  const ConductorDescansoSwitch({super.key});

  static const Color _amber = Color(0xFFF59E0B);
  static const Color _amberDeep = Color(0xFFD97706);

  static Future<void> toggle(
    BuildContext context, {
    required bool activar,
  }) async {
    final provider = context.read<ConductorHomeProvider>();

    if (activar && !provider.enDescanso) {
      final confirmar = await showDialog<bool>(
        context: context,
        builder: (ctx) {
          final isDark = Theme.of(ctx).brightness == Brightness.dark;
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Text('¿Entrar en modo descanso?'),
            content: Text(
              'Tu turno seguirá activo, pero no recibirás solicitudes '
              'ni aparecerás en el mapa de pasajeros.',
              style: TextStyle(
                color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                height: 1.4,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: FilledButton.styleFrom(backgroundColor: _amber),
                child: const Text('Sí, descansar'),
              ),
            ],
          );
        },
      );
      if (confirmar != true || !context.mounted) return;
    }

    final ok = await provider.setModoDescanso(activar);
    if (!context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    if (ok) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            provider.enDescanso
                ? 'Modo descanso activado. Turno sigue activo.'
                : 'Ya puedes recibir servicios otra vez.',
          ),
          backgroundColor: provider.enDescanso ? _amber : Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );
    } else {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            provider.lastDescansoError ??
                'No se pudo cambiar el modo descanso',
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ConductorHomeProvider>(
      builder: (context, provider, _) {
        if (!provider.puedeUsarModoDescanso && !provider.enDescanso) {
          return const SizedBox.shrink();
        }

        final isDark = Theme.of(context).brightness == Brightness.dark;
        final enDescanso = provider.enDescanso;
        final loading = provider.cambiandoDescanso;
        final enabled =
            (provider.puedeUsarModoDescanso || enDescanso) && !loading;

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: enDescanso
                ? _amber.withValues(alpha: isDark ? 0.18 : 0.14)
                : (isDark
                      ? Colors.white.withValues(alpha: 0.06)
                      : AppColors.primary.withValues(alpha: 0.06)),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: enDescanso
                  ? _amber.withValues(alpha: 0.45)
                  : Colors.black.withValues(alpha: 0.06),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Icon(
                  enDescanso ? Icons.nightlight_round : Icons.coffee_outlined,
                  size: 22,
                  color: enDescanso
                      ? _amberDeep
                      : (isDark ? Colors.white70 : AppColors.primary),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        enDescanso ? 'En descanso' : 'Modo descanso',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      Text(
                        enDescanso
                            ? 'Sin solicitudes · Oculto en mapa'
                            : 'Pausa servicios sin cerrar turno',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark
                              ? Colors.grey.shade500
                              : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                if (loading)
                  const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  Switch.adaptive(
                    value: enDescanso,
                    onChanged: enabled
                        ? (value) => toggle(context, activar: value)
                        : null,
                    activeThumbColor: Colors.white,
                    activeTrackColor: _amber,
                    inactiveThumbColor: isDark ? Colors.grey.shade300 : null,
                    inactiveTrackColor: isDark
                        ? Colors.grey.shade700
                        : Colors.grey.shade300,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
