import 'package:flutter/material.dart';

/// Chip de barrio/zona actual del conductor en el header del mapa.
class ConductorHomeZonaChip extends StatelessWidget {
  const ConductorHomeZonaChip({
    super.key,
    required this.zona,
    this.labelPrefix = 'Tu zona',
  });

  final String zona;
  final String labelPrefix;

  @override
  Widget build(BuildContext context) {
    final trimmed = zona.trim();
    if (trimmed.isEmpty) return const SizedBox.shrink();

    return Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.sizeOf(context).width - 60,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.location_on,
            size: 12,
            color: Colors.white.withValues(alpha: 0.95),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              '$labelPrefix: $trimmed',
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.95),
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
