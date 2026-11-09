import 'package:flutter/material.dart';
import 'package:intellitaxi/core/geo/barrios/barrio.dart';
import 'package:intellitaxi/core/theme/app_colors.dart';
import 'package:intellitaxi/features/pasajero/data/service_pin.dart';

class BarrioReferenciaPanel extends StatelessWidget {
  const BarrioReferenciaPanel({
    super.key,
    required this.title,
    required this.pin,
    required this.onCambiarBarrio,
    required this.onElegirCandidato,
  });

  final String title;
  final ServicePin pin;
  final VoidCallback onCambiarBarrio;
  final ValueChanged<Barrio> onElegirCandidato;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final barrio = pin.barrioNombre;
    final needsChoice = pin.necesitaElegirBarrio;
    final candidates = pin.resolve?.candidates ?? const <Barrio>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.6,
            color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Chip(
              avatar: Icon(
                pin.barrioPorConfirmar ? Icons.help_outline : Icons.place,
                size: 18,
                color: pin.barrioPorConfirmar
                    ? Colors.orange.shade800
                    : AppColors.green,
              ),
              label: Text(
                'Barrio: $barrio',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              backgroundColor: pin.barrioPorConfirmar
                  ? Colors.orange.withValues(alpha: 0.12)
                  : AppColors.green.withValues(alpha: 0.12),
              side: BorderSide.none,
            ),
            TextButton(
              onPressed: onCambiarBarrio,
              child: const Text('Cambiar'),
            ),
          ],
        ),
        if (needsChoice && candidates.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            'El pin está cerca del límite. Elige el barrio:',
            style: TextStyle(
              fontSize: 12.5,
              color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 4),
          for (final candidate in candidates)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                pin.elegido?.id == candidate.id
                    ? Icons.check_circle
                    : Icons.circle_outlined,
                color: AppColors.primary,
              ),
              title: Text(
                candidate.nombre,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: candidate.comuna == null
                  ? null
                  : Text('Comuna ${candidate.comuna}'),
              onTap: () => onElegirCandidato(candidate),
            ),
        ],
      ],
    );
  }
}
