import 'package:flutter/material.dart';

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
    return Row(
      children: [
        Expanded(
          child: _ServiceTypeButton(
            type: 'taxi',
            icon: Icons.local_taxi,
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
            icon: Icons.shopping_bag,
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

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? (type == 'taxi' ? Colors.deepOrange : Colors.green.shade600)
              : (isDark ? Colors.grey.shade800 : Colors.grey.shade100),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? (type == 'taxi' ? Colors.deepOrange : Colors.green.shade600)
                : (isDark ? Colors.grey.shade700 : Colors.grey.shade300),
            width: 2,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 22,
              color: isSelected
                  ? Colors.white
                  : (isDark ? Colors.grey.shade400 : Colors.grey.shade700),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
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
                    fontSize: 10,
                    color: isSelected
                        ? Colors.white.withOpacity(0.9)
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
