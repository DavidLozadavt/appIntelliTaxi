import 'package:flutter/material.dart';

/// Modal que se muestra mientras se busca un conductor disponible
class WaitingForDriverDialog extends StatelessWidget {
  final bool isDelivery;

  const WaitingForDriverDialog({
    super.key,
    this.isDelivery = false,
  });

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false,
      child: Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
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
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
