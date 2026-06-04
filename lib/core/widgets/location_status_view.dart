import 'package:flutter/material.dart';
import 'package:intellitaxi/core/widgets/app_loading_indicator.dart';

class LocationStatusView extends StatelessWidget {
  final bool isLoading;
  final String message;
  final VoidCallback onRetry;
  final String actionLabel;
  final IconData actionIcon;
  final String loadingTitle;
  final String unavailableTitle;

  const LocationStatusView({
    super.key,
    required this.isLoading,
    required this.message,
    required this.onRetry,
    this.actionLabel = 'Reintentar conexión',
    this.actionIcon = Icons.refresh_rounded,
    this.loadingTitle = 'Conectando GPS',
    this.unavailableTitle = 'Ubicación no disponible',
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            colorScheme.primary.withValues(alpha: 0.08),
            colorScheme.surface,
          ],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isLoading
                      ? [
                          colorScheme.primary.withValues(alpha: 0.22),
                          colorScheme.primary.withValues(alpha: 0.08),
                        ]
                      : [
                          colorScheme.outlineVariant.withValues(alpha: 0.22),
                          colorScheme.outlineVariant.withValues(alpha: 0.08),
                        ],
                ),
                boxShadow: isLoading
                    ? [
                        BoxShadow(
                          color: colorScheme.primary.withValues(alpha: 0.2),
                          blurRadius: 30,
                          spreadRadius: 10,
                        ),
                      ]
                    : [],
              ),
              child: Center(
                child: Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isLoading
                        ? colorScheme.primary.withValues(alpha: 0.16)
                        : colorScheme.outlineVariant.withValues(alpha: 0.16),
                  ),
                  child: Center(
                    child: isLoading
                        ? const AppBrandLoader(ringSize: 72)
                        : Icon(
                            Icons.location_off_rounded,
                            size: 45,
                            color: colorScheme.onSurfaceVariant,
                          ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
            Text(
              isLoading ? loadingTitle : unavailableTitle,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
                letterSpacing: -0.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                message,
                style: TextStyle(
                  fontSize: 15,
                  color: colorScheme.onSurfaceVariant,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 32),
            if (!isLoading) ...[
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: colorScheme.primary.withValues(alpha: 0.28),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: onRetry,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorScheme.primary,
                    foregroundColor: colorScheme.onPrimary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 40,
                      vertical: 18,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(actionIcon, size: 22),
                      const SizedBox(width: 10),
                      Text(
                        actionLabel,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
