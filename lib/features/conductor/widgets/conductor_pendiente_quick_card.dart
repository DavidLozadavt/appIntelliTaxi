import 'package:flutter/material.dart';
import 'package:intellitaxi/core/theme/app_colors.dart';
import 'package:intellitaxi/features/conductor/utils/solicitud_display_helper.dart';

/// Tarjeta horizontal compacta para aceptar rápido al volante.
class ConductorPendienteQuickCard extends StatelessWidget {
  final Map<String, dynamic> solicitud;
  final String? distanciaDesdeMi;
  final String? tiempoPublicado;
  final int? segundosRestantes;
  final VoidCallback onAceptar;
  final VoidCallback? onDescartar;
  final bool anchoCompleto;

  const ConductorPendienteQuickCard({
    super.key,
    required this.solicitud,
    this.distanciaDesdeMi,
    this.tiempoPublicado,
    this.segundosRestantes,
    required this.onAceptar,
    this.onDescartar,
    this.anchoCompleto = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final origen = SolicitudDisplayHelper.pickupName(solicitud);
    final destino = SolicitudDisplayHelper.destinationName(solicitud);
    final muestraDestino = SolicitudDisplayHelper.hasDestination(solicitud) &&
        !SolicitudDisplayHelper.isPlaceholderDestino(destino);
    final enRiesgo = (segundosRestantes ?? 0) > 0 && segundosRestantes! <= 7;

    return Container(
      width: anchoCompleto ? double.infinity : 272,
      margin: EdgeInsets.only(right: anchoCompleto ? 0 : 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF252525) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: enRiesgo
              ? Colors.red.shade400
              : AppColors.accent.withValues(alpha: 0.35),
          width: enRiesgo ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  origen,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
              ),
              if (segundosRestantes != null && segundosRestantes! > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: enRiesgo ? Colors.red : Colors.black87,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${segundosRestantes}s',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
          if (muestraDestino) ...[
            const SizedBox(height: 2),
            Text(
              '→ $destino',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            children: [
              if (distanciaDesdeMi != null && distanciaDesdeMi!.isNotEmpty)
                _miniChip(distanciaDesdeMi!),
              if (tiempoPublicado != null && tiempoPublicado!.isNotEmpty)
                _miniChip(tiempoPublicado!),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: onAceptar,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    'ACEPTAR',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                  ),
                ),
              ),
              if (onDescartar != null) ...[
                const SizedBox(width: 6),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: onDescartar,
                  icon: Icon(Icons.close, color: Colors.grey.shade600),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }
}
