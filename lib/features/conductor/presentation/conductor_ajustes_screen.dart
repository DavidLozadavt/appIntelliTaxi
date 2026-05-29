import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:intellitaxi/core/theme/app_colors.dart';
import 'package:intellitaxi/features/conductor/widgets/conductor_keep_screen_on_tile.dart';

/// Ajustes del conductor (pantalla, sonidos, etc.).
class ConductorAjustesScreen extends StatelessWidget {
  const ConductorAjustesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : const Color(0xFFF6F4F5),
      appBar: AppBar(
        title: const Text(
          'Ajustes',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
        children: [
          _sectionTitle(context, 'Pantalla'),
          _settingsCard(
            isDark: isDark,
            children: const [
              ConductorKeepScreenOnTile(),
            ],
          ),
          const SizedBox(height: 24),
          _sectionTitle(context, 'Notificaciones'),
          _settingsCard(
            isDark: isDark,
            children: [
              ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Iconsax.music_filter_copy,
                    color: AppColors.accent,
                    size: 22,
                  ),
                ),
                title: const Text(
                  'Sonido de servicios',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  'Tono al recibir una nueva solicitud',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark
                        ? Colors.grey.shade400
                        : Colors.grey.shade600,
                  ),
                ),
                trailing: Icon(
                  Iconsax.arrow_right_3_copy,
                  size: 18,
                  color: Colors.grey.shade400,
                ),
                onTap: () =>
                    Navigator.pushNamed(context, '/conductor-sonido-servicios'),
              ),
            ],
          ),
          // Modo descanso oculto temporalmente.
          // const SizedBox(height: 24),
          // _sectionTitle(context, 'Turno'),
          // _settingsCard(
          //   isDark: isDark,
          //   children: const [
          //     ConductorDescansoSwitch(),
          //   ],
          // ),
        ],
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String label) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
          color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
        ),
      ),
    );
  }

  Widget _settingsCard({
    required bool isDark,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.grey.shade200,
        ),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: children,
      ),
    );
  }
}
