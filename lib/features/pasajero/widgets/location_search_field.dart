import 'package:flutter/material.dart';
import 'package:intellitaxi/features/rides/services/places_service.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

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
            color: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
              width: 1,
            ),
          ),
          child: TextField(
            controller: controller,
            style: TextStyle(color: theme.textTheme.bodyLarge?.color),
            decoration: InputDecoration(
              hintText: label,
              hintStyle: TextStyle(
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
              ),
              prefixIcon: Icon(icon, color: iconColor),
              suffixIcon: controller.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Iconsax.close_circle_copy),
                      onPressed: onClear,
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
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
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
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
