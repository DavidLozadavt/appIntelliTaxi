import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:intellitaxi/core/theme/app_colors.dart';
import 'package:intellitaxi/features/conductor/utils/solicitud_display_helper.dart';

class SolicitudServicioCard extends StatefulWidget {
  final Map<String, dynamic> solicitud;
  final VoidCallback onAceptar;
  final VoidCallback? onRechazar;
  final int? segundosRestantes;
  final bool destacada;
  /// Metadatos para lista «En espera» (distancia al conductor, antigüedad, precio).
  final String? distanciaDesdeMi;
  final String? tiempoPublicado;
  final double? precioOfertado;
  final bool marginExterno;

  const SolicitudServicioCard({
    super.key,
    required this.solicitud,
    required this.onAceptar,
    this.onRechazar,
    this.segundosRestantes,
    this.destacada = false,
    this.distanciaDesdeMi,
    this.tiempoPublicado,
    this.precioOfertado,
    this.marginExterno = true,
  });

  @override
  State<SolicitudServicioCard> createState() => _SolicitudServicioCardState();
}

class _SolicitudServicioCardState extends State<SolicitudServicioCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 350),
      vsync: this,
    );

    _scaleAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _dismiss(VoidCallback callback) {
    _controller.reverse().then((_) => callback());
  }

  Widget _infoChip({
    required IconData icon,
    required String label,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.08)
            : color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white.withValues(alpha: 0.9) : color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationBlock({
    required String label,
    required String title,
    required String subtitle,
    required Color labelColor,
    required bool isDark,
    required bool titleLarge,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: labelColor,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          title,
          style: TextStyle(
            fontSize: titleLarge ? 22 : 18,
            fontWeight: FontWeight.w800,
            height: 1.2,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        if (subtitle.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            subtitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade600,
              height: 1.25,
            ),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final origenNombre = SolicitudDisplayHelper.pickupName(widget.solicitud);
    final origenSub = SolicitudDisplayHelper.pickupSubtitle(widget.solicitud);
    final barrio = SolicitudDisplayHelper.barrioFromPayload(widget.solicitud);
    final destinoNombre =
        SolicitudDisplayHelper.destinationName(widget.solicitud);
    final destinoSub =
        SolicitudDisplayHelper.destinationSubtitle(widget.solicitud);
    final muestraDestino = SolicitudDisplayHelper.hasDestination(widget.solicitud) &&
        !SolicitudDisplayHelper.isPlaceholderDestino(destinoNombre);
    final segundosRestantes = widget.segundosRestantes ?? 0;
    final enRiesgo = segundosRestantes <= 7;
    final distanciaMi = widget.distanciaDesdeMi?.trim() ?? '';
    final tiempoPub = widget.tiempoPublicado?.trim() ?? '';
    final precio = widget.precioOfertado;
    final tieneMeta =
        distanciaMi.isNotEmpty || tiempoPub.isNotEmpty || (precio != null && precio > 0);
    final viajeDist = SolicitudDisplayHelper.tripDistanceText(widget.solicitud);
    final viajeDur = SolicitudDisplayHelper.tripDurationText(widget.solicitud);

    return SlideTransition(
      position: _slideAnimation,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          margin: widget.marginExterno
              ? const EdgeInsets.symmetric(horizontal: 12, vertical: 8)
              : EdgeInsets.zero,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: widget.destacada
                  ? AppColors.accent
                  : Colors.black.withValues(alpha: 0.08),
              width: widget.destacada ? 2.5 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.14),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (barrio != null &&
                              barrio.toLowerCase() !=
                                  origenNombre.toLowerCase()) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.accent.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                barrio.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.4,
                                  color: isDark
                                      ? AppColors.accent
                                      : Colors.orange.shade900,
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                          ],
                          _buildLocationBlock(
                            label: 'RECOGIDA',
                            title: origenNombre,
                            subtitle: origenSub,
                            labelColor: AppColors.accent,
                            isDark: isDark,
                            titleLarge: widget.destacada,
                          ),
                        ],
                      ),
                    ),
                    if (segundosRestantes > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: enRiesgo
                              ? Colors.red
                              : Colors.black.withValues(alpha: 0.75),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${segundosRestantes}s',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                      )
                    else if (tiempoPub.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.accent.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: AppColors.accent.withValues(alpha: 0.35),
                          ),
                        ),
                        child: Text(
                          tiempoPub,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: isDark ? AppColors.accent : Colors.orange.shade900,
                          ),
                        ),
                      ),
                  ],
                ),
                if (muestraDestino) ...[
                  const SizedBox(height: 14),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 18),
                        child: Icon(
                          Iconsax.location,
                          size: 18,
                          color: Colors.red.shade400,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildLocationBlock(
                          label: 'DESTINO',
                          title: destinoNombre,
                          subtitle: destinoSub,
                          labelColor: Colors.red.shade400,
                          isDark: isDark,
                          titleLarge: false,
                        ),
                      ),
                    ],
                  ),
                ],
                if (viajeDist.isNotEmpty || viajeDur.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      if (viajeDist.isNotEmpty) ...[
                        Icon(
                          Iconsax.routing,
                          size: 16,
                          color: Colors.grey.shade600,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          viajeDist,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                      if (viajeDist.isNotEmpty && viajeDur.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Text(
                            '·',
                            style: TextStyle(color: Colors.grey.shade500),
                          ),
                        ),
                      if (viajeDur.isNotEmpty)
                        Text(
                          viajeDur,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Colors.grey.shade700,
                          ),
                        ),
                    ],
                  ),
                ],
                if (tieneMeta) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      if (distanciaMi.isNotEmpty)
                        _infoChip(
                          icon: Iconsax.gps,
                          label: distanciaMi,
                          color: AppColors.accent,
                          isDark: isDark,
                        ),
                      if (precio != null && precio > 0)
                        _infoChip(
                          icon: Iconsax.dollar_circle,
                          label: '\$${precio.toStringAsFixed(0)}',
                          color: Colors.green.shade700,
                          isDark: isDark,
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    if (widget.onRechazar != null) ...[
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _dismiss(widget.onRechazar!),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 14,
                            ),
                            side: const BorderSide(color: Colors.red, width: 1.5),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              'Rechazar',
                              maxLines: 1,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Colors.red,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => _dismiss(widget.onAceptar),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Iconsax.tick_circle_copy, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Aceptar',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
