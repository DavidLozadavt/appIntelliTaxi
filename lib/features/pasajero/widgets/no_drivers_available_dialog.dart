import 'package:flutter/material.dart';
import 'package:intellitaxi/core/theme/app_colors.dart';

class NoDriversAvailableDialog extends StatelessWidget {
  final String? message;
  final VoidCallback? onRetry;
  final VoidCallback? onClose;

  const NoDriversAvailableDialog({
    super.key,
    this.message,
    this.onRetry,
    this.onClose,
  });

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
    final description =
        (message != null && message!.trim().isNotEmpty)
            ? message!.trim()
            : 'No encontramos carros disponibles en este momento.';

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
                      Icons.local_taxi_rounded,
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
                          'Sin carros disponibles',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: titleColor,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          description,
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
                      'Puedes intentar esto:',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: titleColor,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '• Espera un momento y vuelve a solicitar.',
                      style: TextStyle(color: bodyColor),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '• Verifica que tu punto de recogida esté correcto.',
                      style: TextStyle(color: bodyColor),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '• En horas de alta demanda puede tardar más.',
                      style: TextStyle(color: bodyColor),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onClose ?? () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: BorderSide(color: infoBorder),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('Cerrar'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: onRetry,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('Reintentar'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
