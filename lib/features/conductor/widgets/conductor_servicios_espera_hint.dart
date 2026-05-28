import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:intellitaxi/core/theme/app_colors.dart';

/// Aviso bajo «Llegando» cuando hay servicios solo en la pestaña En espera.
class ConductorServiciosEsperaHint extends StatelessWidget {
  const ConductorServiciosEsperaHint({
    super.key,
    required this.cantidad,
    required this.onVerEnEspera,
    this.onDismiss,
  });

  final int cantidad;
  final VoidCallback onVerEnEspera;
  final VoidCallback? onDismiss;

  static const double alturaEstimada = 44;

  @override
  Widget build(BuildContext context) {
    if (cantidad <= 0) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final label = cantidad == 1
        ? '1 servicio en espera'
        : '$cantidad servicios en espera';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onVerEnEspera,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.accent.withValues(alpha: isDark ? 0.18 : 0.1),
            border: Border(
              bottom: BorderSide(
                color: AppColors.accent.withValues(alpha: 0.35),
              ),
            ),
          ),
          child: Row(
            children: [
              Icon(
                Iconsax.timer_1_copy,
                size: 18,
                color: isDark ? AppColors.accent : Colors.orange.shade800,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '$label · Toca para ver',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ),
              if (onDismiss != null)
                IconButton(
                  onPressed: onDismiss,
                  icon: const Icon(Icons.close, size: 18),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                  visualDensity: VisualDensity.compact,
                )
              else
                Icon(
                  Icons.chevron_right,
                  size: 20,
                  color: isDark ? Colors.white54 : Colors.black45,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
