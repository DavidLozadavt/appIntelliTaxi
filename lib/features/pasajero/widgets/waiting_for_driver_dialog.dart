import 'package:flutter/material.dart';
import 'package:intellitaxi/core/widgets/app_loading_indicator.dart';

/// Modal que se muestra mientras se busca un conductor disponible
class WaitingForDriverDialog extends StatelessWidget {
  final bool isDelivery;
  final VoidCallback? onCancel;

  const WaitingForDriverDialog({
    super.key,
    this.isDelivery = false,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const AppLoadingIndicator(size: 48),
              const SizedBox(height: 24),
              Text(
                isDelivery
                    ? '🚚 Buscando conductor disponible...'
                    : '🚕 Buscando conductor disponible...',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Esto puede tomar unos segundos',
                style: TextStyle(color: Colors.grey[600], fontSize: 14),
                textAlign: TextAlign.center,
              ),
              if (onCancel != null) ...[
                const SizedBox(height: 20),
                TextButton.icon(
                  onPressed: onCancel,
                  icon: const Icon(Icons.close, size: 18),
                  label: const Text('Cancelar'),
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
