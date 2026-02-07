import 'package:flutter/material.dart';
import 'package:intellitaxi/features/rides/data/servicio_activo_model.dart';
import 'package:intellitaxi/core/theme/app_colors.dart';

/// Widget que muestra la información del servicio activo para el conductor
class ServicioActivoInfo extends StatelessWidget {
  final ServicioActivo servicio;
  final VoidCallback onViewDetails;

  const ServicioActivoInfo({
    super.key,
    required this.servicio,
    required this.onViewDetails,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey.shade800 : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.accent,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.accent.withOpacity(0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.local_taxi,
                color: AppColors.accent,
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Servicio en curso',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      _getEstadoText(servicio.estado.estado),
                      style: TextStyle(
                        fontSize: 12,
                        color: _getEstadoColor(servicio.estado.estado),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onViewDetails,
                icon: const Icon(Icons.arrow_forward_ios, size: 18),
              ),
            ],
          ),
          const Divider(height: 24),
          _InfoItem(
            icon: Icons.person,
            label: 'Pasajero',
            value: 'Pasajero',
          ),
          const SizedBox(height: 8),
          _InfoItem(
            icon: Icons.location_on,
            label: 'Origen',
            value: servicio.origenAddress,
            maxLines: 2,
          ),
          const SizedBox(height: 8),
          _InfoItem(
            icon: Icons.location_on,
            label: 'Destino',
            value: servicio.destinoAddress,
            maxLines: 2,
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onViewDetails,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Ver detalles del servicio',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getEstadoText(String estado) {
    switch (estado) {
      case 'aceptado':
        return 'En camino al origen';
      case 'en_origen':
        return 'En el origen';
      case 'en_curso':
        return 'En curso';
      case 'en_destino':
        return 'En el destino';
      default:
        return estado;
    }
  }

  Color _getEstadoColor(String estado) {
    switch (estado) {
      case 'aceptado':
        return Colors.blue;
      case 'en_origen':
        return Colors.orange;
      case 'en_curso':
        return Colors.green;
      case 'en_destino':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }
}

class _InfoItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final int maxLines;

  const _InfoItem({
    required this.icon,
    required this.label,
    required this.value,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: Colors.grey.shade600),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
            text: TextSpan(
              style: DefaultTextStyle.of(context).style,
              children: [
                TextSpan(
                  text: '$label: ',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
                TextSpan(
                  text: value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
