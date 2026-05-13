import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intellitaxi/core/services/connectivity_provider.dart';
import 'package:intellitaxi/core/theme/app_colors.dart';
import 'package:intellitaxi/core/widgets/app_loading_indicator.dart';

class NoConnectionScreen extends StatelessWidget {
  const NoConnectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final connectivity = context.read<ConnectivityProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFFF8F1F4),
      body: Stack(
        children: [
          Positioned(
            top: -90,
            left: -50,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.brandWine.withValues(alpha: 0.14),
              ),
            ),
          ),
          Positioned(
            bottom: -120,
            right: -70,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.brandWineLight.withValues(alpha: 0.10),
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFFFFFFFF),
                          Color(0xFFF6E7ED),
                        ],
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
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [
                                  AppColors.brandWine,
                                  AppColors.brandWineLight,
                                ],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.brandWine.withValues(alpha: 0.22),
                                  blurRadius: 24,
                                  offset: const Offset(0, 14),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.wifi_off_rounded,
                              size: 56,
                              color: AppColors.white,
                            ),
                          ),
                          const SizedBox(height: 28),
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
                              'Estado de red',
                              style: theme.textTheme.labelLarge?.copyWith(
                                color: AppColors.brandWine,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),
                          Text(
                            'Sin conexion a internet',
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF2D1220),
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Revisa tu red para seguir usando IntelliTaxi. Apenas vuelva la conexion, retomaremos automaticamente.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              height: 1.5,
                              color: const Color(0xFF6C5460),
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 26),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              AppLoadingIndicator(
                                size: 24,
                                strokeWidth: 2.6,
                                color: AppColors.brandWine,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Buscando reconexion...',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: AppColors.brandWine,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 28),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.brandWine,
                                foregroundColor: AppColors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                              ),
                              onPressed: connectivity.checkNow,
                              icon: const Icon(Icons.refresh_rounded),
                              label: const Text('Reintentar'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
