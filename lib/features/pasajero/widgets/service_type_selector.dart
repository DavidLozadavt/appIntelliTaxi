import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:intellitaxi/core/theme/app_colors.dart';

/// Widget para seleccionar el tipo de servicio (Taxi o Domicilio)
class ServiceTypeSelector extends StatelessWidget {
  final String selectedType;
  final Function(String) onTypeChanged;

  const ServiceTypeSelector({
    super.key,
    required this.selectedType,
    required this.onTypeChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.08)
            : AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          Expanded(
            child: _ServiceTypeButton(
              type: 'taxi',
              icon: Iconsax.car_copy,
              title: 'Taxi',
              subtitle: 'Viaje rápido',
              isSelected: selectedType == 'taxi',
              onTap: () => onTypeChanged('taxi'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _ServiceTypeButton(
              type: 'domicilio',
              icon: Iconsax.shopping_bag_copy,
              title: 'Domicilio',
              subtitle: 'Envío rápido',
              isSelected: selectedType == 'domicilio',
              onTap: () => onTypeChanged('domicilio'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ServiceTypeButton extends StatelessWidget {
  final String type;
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  const _ServiceTypeButton({
    required this.type,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final activeColor = type == 'taxi' ? AppColors.primary : AppColors.secondary;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? activeColor.withValues(alpha: isDark ? 0.18 : 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
          border: isSelected
              ? Border.all(color: activeColor.withValues(alpha: 0.12))
              : null,
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: activeColor.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.white.withValues(alpha: 0.2)
                    : (isDark
                          ? Colors.white.withValues(alpha: 0.08)
                          : Colors.white.withValues(alpha: 0.7)),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 18,
                color: isSelected
                    ? Colors.white
                    : (isDark ? Colors.grey.shade400 : Colors.grey.shade700),
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isSelected
                        ? Colors.white
                        : (isDark
                              ? Colors.grey.shade300
                              : Colors.grey.shade800),
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 9.5,
                    color: isSelected
                        ? Colors.white.withValues(alpha: 0.72)
                        : (isDark
                              ? Colors.grey.shade500
                              : Colors.grey.shade600),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
