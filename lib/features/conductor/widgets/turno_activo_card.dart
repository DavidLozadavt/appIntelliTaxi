import 'package:flutter/material.dart';
import 'package:intellitaxi/features/conductor/data/turno_model.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

/// Widget que muestra la información del turno activo del conductor
class TurnoActivoCard extends StatelessWidget {
  final TurnoActivo turno;
  final VoidCallback onFinalizarTurno;

  const TurnoActivoCard({
    super.key,
    required this.turno,
    required this.onFinalizarTurno,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final horaInicio = turno.horaInicio;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey.shade800 : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.green.shade600,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Iconsax.tick_circle_copy,
                color: Colors.green.shade600,
                size: 24,
              ),
              const SizedBox(width: 8),
              const Text(
                'Turno activo',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: onFinalizarTurno,
                icon: const Icon(Iconsax.close_circle_copy, size: 18),
                label: const Text('Finalizar'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.red,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _InfoRow(
            icon: Iconsax.clock_copy,
            label: 'Inicio:',
            value: horaInicio,
          ),
          const SizedBox(height: 8),
          _InfoRow(
            icon: Iconsax.car_copy,
            label: 'Vehículo:',
            value: turno.vehiculo?.placa ?? 'No especificado',
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey.shade600),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
