import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:intellitaxi/core/theme/app_colors.dart';

/// Taxi o Domicilio, como tarjetas sueltas (no un segmento).
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
    return Row(
      children: [
        Expanded(
          child: _ServiceTypeButton(
            icon: Iconsax.car_copy,
            title: 'Taxi',
            subtitle: 'Viaje rápido',
            isSelected: selectedType == 'taxi',
            onTap: () => onTypeChanged('taxi'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _ServiceTypeButton(
            icon: Iconsax.shopping_bag_copy,
            title: 'Domicilio',
            subtitle: 'Envío rápido',
            isSelected: selectedType == 'domicilio',
            onTap: () => onTypeChanged('domicilio'),
          ),
        ),
      ],
    );
  }
}

class _ServiceTypeButton extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  const _ServiceTypeButton({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final wine = AppColors.primary;
    final card = isSelected
        ? wine.withValues(alpha: isDark ? 0.22 : 0.10)
        : (isDark ? Colors.white.withValues(alpha: 0.06) : Colors.white);
    final titleColor = isSelected
        ? (isDark ? Colors.white : wine)
        : (isDark ? Colors.grey.shade200 : const Color(0xFF2A2A2A));
    final subtitleColor = isSelected
        ? (isDark ? Colors.white70 : wine.withValues(alpha: 0.72))
        : (isDark ? Colors.grey.shade500 : Colors.grey.shade600);

    return Material(
      color: card,
      elevation: isSelected ? 0 : (isDark ? 0 : 0.4),
      shadowColor: Colors.black.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 12, 10, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isSelected
                  ? wine.withValues(alpha: isDark ? 0.0 : 0.06)
                  : (isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : const Color(0xFFE8E8E8)),
            ),
          ),
          child: Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? wine
                          : (isDark
                                ? Colors.white.withValues(alpha: 0.08)
                                : const Color(0xFFF3F3F3)),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      icon,
                      size: 20,
                      color: isSelected
                          ? Colors.white
                          : (isDark
                                ? Colors.grey.shade400
                                : Colors.grey.shade700),
                    ),
                  ),
                  if (isSelected)
                    Positioned(
                      top: -2,
                      right: -2,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: wine,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        height: 1.1,
                        color: titleColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: subtitleColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
