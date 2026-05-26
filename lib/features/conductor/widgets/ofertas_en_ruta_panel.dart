import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:provider/provider.dart';
import 'package:intellitaxi/core/theme/app_colors.dart';
import 'package:intellitaxi/features/conductor/providers/conductor_home_provider.dart';
import 'package:intellitaxi/features/conductor/utils/solicitud_display_helper.dart';

/// Listado de ofertas cercanas al destino del viaje actual (conductor ocupado).
class OfertasEnRutaPanel extends StatefulWidget {
  final double haciaLat;
  final double haciaLng;
  final int? excluirServicioId;
  final void Function(Map<String, dynamic> solicitud, String solicitudId)
      onAceptar;
  final void Function(String solicitudId) onRechazar;
  final void Function(Map<String, dynamic> solicitud)? onLlamar;

  const OfertasEnRutaPanel({
    super.key,
    required this.haciaLat,
    required this.haciaLng,
    this.excluirServicioId,
    required this.onAceptar,
    required this.onRechazar,
    this.onLlamar,
  });

  @override
  State<OfertasEnRutaPanel> createState() => _OfertasEnRutaPanelState();
}

class _OfertasEnRutaPanelState extends State<OfertasEnRutaPanel> {
  bool _expandido = false;

  String _idOferta(Map<String, dynamic> s) {
    return s['_local_id']?.toString() ??
        s['solicitud_id']?.toString() ??
        s['servicio_id']?.toString() ??
        s['id']?.toString() ??
        '';
  }

  String? _telefonoOferta(Map<String, dynamic> s) {
    for (final key in const [
      'pasajero_telefono',
      'telefono_pasajero',
      'telefono',
    ]) {
      final v = s[key]?.toString().trim();
      if (v != null && v.isNotEmpty) return v;
    }
    final pasajero = s['pasajero'];
    if (pasajero is Map) {
      for (final key in const ['telefono', 'phone', 'celular']) {
        final v = pasajero[key]?.toString().trim();
        if (v != null && v.isNotEmpty) return v;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ConductorHomeProvider>(
      builder: (context, provider, _) {
        final ofertas = provider.solicitudesEnRuta(
          haciaLat: widget.haciaLat,
          haciaLng: widget.haciaLng,
          excluirServicioId: widget.excluirServicioId,
        );

        if (ofertas.isEmpty) return const SizedBox.shrink();

        final visibles = _expandido ? ofertas : ofertas.take(2).toList();

        return Material(
          elevation: 8,
          borderRadius: BorderRadius.circular(16),
          color: Theme.of(context).cardColor.withValues(alpha: 0.97),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              InkWell(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
                onTap: () => setState(() => _expandido = !_expandido),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.accent.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Iconsax.routing_2,
                          color: AppColors.accent,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Ofertas en tu ruta (${ofertas.length})',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                              ),
                            ),
                            Text(
                              _expandido
                                  ? 'Toca para minimizar'
                                  : 'Hacia el sector donde vas',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        _expandido
                            ? Icons.keyboard_arrow_up
                            : Icons.keyboard_arrow_down,
                        color: AppColors.accent,
                      ),
                    ],
                  ),
                ),
              ),
              if (_expandido && ofertas.length > 2)
                Divider(height: 1, color: Colors.grey.shade300),
              ...visibles.map((solicitud) {
                final id = _idOferta(solicitud);
                if (id.isEmpty) return const SizedBox.shrink();
                final segundos = provider.obtenerSegundosRestantes(id);
                final telefono = _telefonoOferta(solicitud);
                return _OfertaCompactaTile(
                  solicitud: solicitud,
                  segundosRestantes: segundos,
                  onAceptar: () => widget.onAceptar(solicitud, id),
                  onRechazar: () => widget.onRechazar(id),
                  onLlamar: telefono != null && widget.onLlamar != null
                      ? () => widget.onLlamar!(solicitud)
                      : null,
                );
              }),
              if (!_expandido && ofertas.length > 2)
                TextButton(
                  onPressed: () => setState(() => _expandido = true),
                  child: Text('Ver ${ofertas.length - 2} más'),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _OfertaCompactaTile extends StatelessWidget {
  final Map<String, dynamic> solicitud;
  final int? segundosRestantes;
  final VoidCallback onAceptar;
  final VoidCallback onRechazar;
  final VoidCallback? onLlamar;

  const _OfertaCompactaTile({
    required this.solicitud,
    this.segundosRestantes,
    required this.onAceptar,
    required this.onRechazar,
    this.onLlamar,
  });

  @override
  Widget build(BuildContext context) {
    final barrio = SolicitudDisplayHelper.pickupName(solicitud);
    final calle = SolicitudDisplayHelper.pickupSubtitle(solicitud);
    final km = solicitud['distancia_hacia_ruta_km'];

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      barrio,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Colors.orange.shade900,
                        height: 1.2,
                      ),
                    ),
                    if (calle != null && calle.isNotEmpty)
                      Text(
                        calle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey.shade700,
                          height: 1.2,
                        ),
                    ),
                    if (km != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          '~${(km is num ? km.toDouble() : double.tryParse(km.toString()) ?? 0).toStringAsFixed(1)} km hacia tu ruta',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (segundosRestantes != null && segundosRestantes! > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: segundosRestantes! <= 7
                        ? Colors.red
                        : Colors.black87,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${segundosRestantes}s',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              IconButton(
                onPressed: onRechazar,
                icon: const Icon(Icons.close, color: Colors.red),
                tooltip: 'Descartar',
              ),
              if (onLlamar != null) ...[
                IconButton(
                  onPressed: onLlamar,
                  icon: const Icon(Iconsax.call, color: AppColors.green),
                  tooltip: 'Llamar',
                ),
              ],
              const SizedBox(width: 4),
              Expanded(
                child: FilledButton(
                  onPressed: onAceptar,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  child: const Text(
                    'Aceptar',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
