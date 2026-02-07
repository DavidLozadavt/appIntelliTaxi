import 'package:flutter/material.dart';

/// Widget que agrupa los botones flotantes del conductor (centrar, refrescar, etc)
class ConductorActionButtons extends StatelessWidget {
  final VoidCallback onCenterLocation;
  final VoidCallback? onRefresh;
  final bool showRefresh;

  const ConductorActionButtons({
    super.key,
    required this.onCenterLocation,
    this.onRefresh,
    this.showRefresh = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Botón de centrar ubicación
        FloatingActionButton.small(
          heroTag: 'center_location',
          onPressed: onCenterLocation,
          backgroundColor: Colors.white,
          child: const Icon(Icons.my_location, color: Colors.deepOrange),
        ),
        
        // Botón de refrescar (opcional)
        if (showRefresh && onRefresh != null) ...[
          const SizedBox(height: 8),
          FloatingActionButton.small(
            heroTag: 'refresh',
            onPressed: onRefresh,
            backgroundColor: Colors.white,
            child: const Icon(Icons.refresh, color: Colors.blue),
          ),
        ],
      ],
    );
  }
}
