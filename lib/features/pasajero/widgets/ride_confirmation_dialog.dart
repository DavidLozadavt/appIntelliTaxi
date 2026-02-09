import 'package:flutter/material.dart';
import 'package:intellitaxi/features/rides/data/trip_location.dart';
import 'package:intellitaxi/features/rides/services/routes_service.dart';

/// Diálogo de confirmación de viaje/domicilio
class RideConfirmationDialog extends StatelessWidget {
  final String serviceType;
  final TripLocation origin;
  final TripLocation destination;
  final RouteInfo routeInfo;
  final VoidCallback onConfirm;

  const RideConfirmationDialog({
    super.key,
    required this.serviceType,
    required this.origin,
    required this.destination,
    required this.routeInfo,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    final isDelivery = serviceType == 'domicilio';

    return AlertDialog(
      title: Text(isDelivery ? 'Confirmar domicilio' : 'Confirmar viaje'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isDelivery ? Icons.shopping_bag : Icons.local_taxi,
                color: isDelivery ? Colors.green.shade600 : Colors.deepOrange,
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                isDelivery ? 'Servicio de domicilio' : 'Servicio de taxi',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const Divider(height: 24),
          Text('Origen: ${origin.name}'),
          const SizedBox(height: 8),
          Text('Destino: ${destination.name}'),
          const Divider(height: 24),
          Text('Distancia: ${routeInfo.distance}'),
          Text('Duración: ${routeInfo.duration}'),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.speed, color: Colors.blue.shade700, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'El cobro se realizará según taxímetro',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.blue.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: onConfirm,
          style: ElevatedButton.styleFrom(
            backgroundColor: isDelivery
                ? Colors.orange.shade600
                : Colors.green.shade600,
          ),
          child: const Text('Confirmar'),
        ),
      ],
    );
  }
}
