import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:intellitaxi/core/theme/app_colors.dart';

/// Usuario autenticado sin rol conductor/pasajero asignado.
class NoRoleAssignedView extends StatelessWidget {
  const NoRoleAssignedView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final titleColor = isDark ? AppColors.darkOnSurface : const Color(0xFF2D1220);
    final bodyColor = isDark ? Colors.white70 : const Color(0xFF6C5460);
    final cardTop = isDark ? AppColors.darkCard : const Color(0xFFFFFFFF);
    final cardBottom = isDark ? AppColors.darkSurface : const Color(0xFFF6E7ED);

    return Stack(
      children: [
        Positioned(
          top: -70,
          right: -40,
          child: Container(
            width: 180,
            height: 180,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.brandWine.withValues(alpha: isDark ? 0.12 : 0.10),
            ),
          ),
        ),
        Positioned(
          bottom: -90,
          left: -50,
          child: Container(
            width: 220,
            height: 220,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.brandWineLight.withValues(alpha: isDark ? 0.08 : 0.08),
            ),
          ),
        ),
        Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [cardTop, cardBottom],
                  ),
                  borderRadius: BorderRadius.circular(32),
                  border: Border.all(
                    color: AppColors.brandWine.withValues(alpha: 0.12),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.brandWine.withValues(alpha: 0.10),
                      blurRadius: 28,
                      offset: const Offset(0, 18),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 32, 24, 28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 112,
                        height: 112,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.brandWine.withValues(alpha: 0.10),
                          border: Border.all(
                            color: AppColors.brandWine.withValues(alpha: 0.18),
                          ),
                        ),
                        child: const Icon(
                          Icons.sentiment_dissatisfied_rounded,
                          size: 56,
                          color: AppColors.brandWine,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.brandWine.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          'Sin rol activo',
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: AppColors.brandWine,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        '¡Ups!',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: titleColor,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'No tienes un rol activo en TaxbelUrbano',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: titleColor,
                          height: 1.35,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Tu cuenta está registrada, pero aún no tiene permisos '
                        'para operar como conductor o pasajero.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          height: 1.5,
                          color: bodyColor,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 22),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.brandWine.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: AppColors.brandWine.withValues(alpha: 0.10),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Iconsax.user_tag,
                              size: 22,
                              color: AppColors.brandWine.withValues(alpha: 0.85),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Comunícate con un administrador para que active '
                                'tu rol y puedas usar la app.',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  height: 1.45,
                                  color: bodyColor,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
