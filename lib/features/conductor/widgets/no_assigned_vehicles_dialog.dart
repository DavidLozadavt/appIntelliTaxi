import 'package:flutter/material.dart';
import 'package:intellitaxi/core/theme/app_colors.dart';

class NoAssignedVehiclesDialog extends StatelessWidget {
  const NoAssignedVehiclesDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final surfaceColor =
        isDark ? AppColors.darkCard : theme.colorScheme.surface;
    final titleColor = isDark ? AppColors.darkOnSurface : AppColors.primary;
    final bodyColor =
        isDark
            ? AppColors.darkOnSurface.withValues(alpha: 0.78)
            : Colors.black87;
    final infoBackground =
        isDark
            ? AppColors.primaryDark.withValues(alpha: 0.34)
            : AppColors.primary.withValues(alpha: 0.08);
    final infoBorder =
        isDark
            ? AppColors.secondary.withValues(alpha: 0.38)
            : AppColors.secondary.withValues(alpha: 0.24);

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      backgroundColor: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 30,
              offset: const Offset(0, 16),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AppColors.primary.withValues(alpha: 0.18),
                          AppColors.secondary.withValues(alpha: 0.32),
                        ],
                      ),
                    ),
                    child: const Icon(
                      Icons.no_crash_rounded,
                      color: AppColors.primary,
                      size: 30,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'No tienes vehiculos asignados',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: titleColor,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Aun no tienes un vehiculo disponible para iniciar turno desde esta cuenta.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: bodyColor,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: infoBackground,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: infoBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Que puedes hacer:',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: titleColor,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '• Contacta al administrador para que te asigne uno.',
                      style: TextStyle(color: bodyColor),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '• Revisa en "Mis vehiculos" si ya fue cargado.',
                      style: TextStyle(color: bodyColor),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '• Si acabas de recibirlo, intenta nuevamente en unos segundos.',
                      style: TextStyle(color: bodyColor),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Entendido'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
