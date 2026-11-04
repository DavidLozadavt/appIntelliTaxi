import 'package:flutter/material.dart';
import 'package:intellitaxi/core/widgets/app_loading_indicator.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:intellitaxi/core/theme/app_colors.dart';

/// Botón de pedir: título a la izquierda, ETA a la derecha.
class RideRequestFloatingCta extends StatelessWidget {
  final String label;
  final String? trailing;
  final VoidCallback? onPressed;
  final bool isLoading;
  final Color color;

  const RideRequestFloatingCta({
    super.key,
    required this.label,
    this.trailing,
    required this.onPressed,
    this.isLoading = false,
    this.color = AppColors.primary,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !isLoading;

    return Material(
      color: enabled ? color : Colors.grey.shade500,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: enabled ? onPressed : null,
        borderRadius: BorderRadius.circular(18),
        child: SizedBox(
          height: 56,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                if (isLoading)
                  const AppBrandLoaderCompact(
                    ringSize: 22,
                    theme: AppLoaderTheme.dark,
                  )
                else
                  const Icon(Iconsax.car_copy, color: Colors.white, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (trailing != null && trailing!.isNotEmpty && !isLoading) ...[
                  Text(
                    trailing!,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.92),
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 2),
                  const Icon(
                    Icons.chevron_right,
                    color: Colors.white,
                    size: 22,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
