import 'package:flutter/material.dart';
import 'package:intellitaxi/features/pasajero/services/places_service.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:intellitaxi/core/theme/app_colors.dart';

/// Widget reutilizable para campos de búsqueda de ubicación (origen/destino)
class LocationSearchField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final Color iconColor;
  final List<PlacePrediction> predictions;
  final bool isSearching;
  final Function(PlacePrediction) onSelectPrediction;
  final VoidCallback onClear;
  final FocusNode? focusNode;
  final VoidCallback? onTap;

  const LocationSearchField({
    super.key,
    required this.controller,
    required this.label,
    required this.icon,
    required this.iconColor,
    required this.predictions,
    required this.isSearching,
    required this.onSelectPrediction,
    required this.onClear,
    this.focusNode,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.04)
                : AppColors.primary.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: controller.text.isNotEmpty
                  ? AppColors.primary.withValues(alpha: 0.18)
                  : (isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : AppColors.primary.withValues(alpha: 0.08)),
              width: 1.1,
            ),
          ),
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 14),
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : AppColors.primary.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: iconColor, size: 22),
                ),
              ),
              Expanded(
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  onTap: onTap,
                  style: TextStyle(
                    color: theme.textTheme.bodyLarge?.color,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: InputDecoration(
                    labelText: label.toUpperCase(),
                    labelStyle: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.9,
                      color: isDark
                          ? Colors.grey.shade400
                          : AppColors.primary.withValues(alpha: 0.7),
                    ),
                    hintText: label == 'Origen'
                        ? 'Tu ubicación actual'
                        : '¿A dónde vamos?',
                    hintStyle: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade500,
                    ),
                    suffixIcon: controller.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Iconsax.close_circle_copy),
                            onPressed: onClear,
                            color: AppColors.primary.withValues(alpha: 0.7),
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 16,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        if (isSearching)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          ),

        if (!isSearching && predictions.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 8),
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isDark
                    ? Colors.grey.shade700
                    : AppColors.primary.withValues(alpha: 0.12),
                width: 1,
              ),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: predictions.length > 5 ? 5 : predictions.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final prediction = predictions[index];
                return ListTile(
                  leading: Icon(
                    Iconsax.location_copy,
                    color: Colors.grey.shade600,
                  ),
                  title: Text(
                    prediction.mainText,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  subtitle: Text(
                    prediction.secondaryText,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  onTap: () => onSelectPrediction(prediction),
                );
              },
            ),
          ),
      ],
    );
  }
}
