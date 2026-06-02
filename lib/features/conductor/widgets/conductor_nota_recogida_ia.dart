import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:intellitaxi/features/conductor/utils/oferta_exclusiva_display.dart';

/// Aviso cuando un servicio gestionado por IA no trae GPS de recogida.
class ConductorNotaRecogidaIaSinGps extends StatelessWidget {
  const ConductorNotaRecogidaIaSinGps({
    super.key,
    this.onDarkBackground = false,
    this.margin = const EdgeInsets.only(top: 12),
  });

  final bool onDarkBackground;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    final isDark = onDarkBackground;
    final bg = isDark
        ? Colors.amber.withValues(alpha: 0.12)
        : Colors.amber.shade50;
    final border = isDark
        ? Colors.amber.withValues(alpha: 0.45)
        : Colors.amber.shade200;
    final iconColor = isDark ? Colors.amber.shade200 : Colors.amber.shade900;
    final textColor = isDark ? Colors.amber.shade50 : Colors.amber.shade900;

    return Container(
      width: double.infinity,
      margin: margin,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Iconsax.info_circle, size: 18, color: iconColor),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              OfertaExclusivaDisplay.notaRecogidaSinCoordenadas,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                height: 1.35,
                color: textColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
