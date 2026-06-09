import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:intellitaxi/core/theme/app_colors.dart';
import 'package:intellitaxi/features/conductor/utils/oferta_exclusiva_display.dart';
import 'package:intellitaxi/features/taxi/utils/servicio_espera_timer.dart';
import 'package:intellitaxi/features/conductor/utils/solicitud_display_helper.dart';
import 'package:intellitaxi/features/conductor/widgets/conductor_nota_recogida_ia.dart';

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
  /// Lista «En espera»: menos padding y tipografía más pequeña.
  final bool compact;
  /// Panel mapa (3–4 tarjetas visibles): una línea de destino y menos espacio.
  final bool denseList;

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
    this.compact = false,
    this.denseList = false,
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

  Widget? _denseTrailingBadge({
    required bool isDark,
    required int segundosRestantes,
    required bool enRiesgo,
    required String tiempoPub,
    required String distanciaMi,
    required double? precio,
  }) {
    if (segundosRestantes > 0) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: enRiesgo ? Colors.red : Colors.black.withValues(alpha: 0.75),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          ServicioEsperaTimer.formatearCuentaRegresiva(segundosRestantes),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 14,
          ),
        ),
      );
    }
    if (tiempoPub.isNotEmpty) {
      return Text(
        tiempoPub,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w800,
          color: isDark ? AppColors.accent : Colors.orange.shade900,
        ),
      );
    }
    if (distanciaMi.isNotEmpty) {
      return Text(
        distanciaMi,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: Colors.grey.shade600,
        ),
      );
    }
    if (precio != null && precio > 0) {
      return Text(
        '\$${precio.toStringAsFixed(0)}',
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w800,
          color: Colors.green.shade700,
        ),
      );
    }
    return null;
  }

  Widget _buildDenseActionButtons({required bool compact}) {
    const btnHeight = 34.0;
    final btnStyle = ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(Size(0, btnHeight)),
      maximumSize: const WidgetStatePropertyAll(Size(double.infinity, btnHeight)),
      padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 8)),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
    );

    return SizedBox(
      height: btnHeight,
      child: Row(
        children: [
          if (widget.onRechazar != null) ...[
            Expanded(
              child: OutlinedButton(
                onPressed: () => _dismiss(widget.onRechazar!),
                style: btnStyle.merge(
                  OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.red, width: 1.5),
                    foregroundColor: Colors.red,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                child: const Text(
                  'Rechazar',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            SizedBox(width: compact ? 6 : 8),
          ],
          Expanded(
            child: ElevatedButton(
              onPressed: () => _dismiss(widget.onAceptar),
              style: btnStyle.merge(
                ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Iconsax.tick_circle_copy, size: 18),
                  SizedBox(width: 6),
                  Text(
                    'Aceptar',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDenseListContent({
    required bool isDark,
    required String recogidaHeadline,
    required String origenSub,
    required String destinoHeadline,
    required String destinoSub,
    required bool muestraDestino,
    required String viajeDist,
    required String viajeDur,
    required int segundosRestantes,
    required bool enRiesgo,
    required String tiempoPub,
    required String distanciaMi,
    required double? precio,
    required bool compact,
  }) {
    final badge = _denseTrailingBadge(
      isDark: isDark,
      segundosRestantes: segundosRestantes,
      enRiesgo: enRiesgo,
      tiempoPub: tiempoPub,
      distanciaMi: distanciaMi,
      precio: precio,
    );

    return Column(
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
                  Text(
                    recogidaHeadline,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      height: 1.15,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  if (origenSub.isNotEmpty) ...[
                    const SizedBox(height: 1),
                    Text(
                      origenSub,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        height: 1.1,
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.78)
                            : Colors.black54,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (badge != null) ...[const SizedBox(width: 8), badge],
          ],
        ),
        if (muestraDestino && destinoHeadline.isNotEmpty) ...[
          const SizedBox(height: 3),
          Text(
            destinoHeadline,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              height: 1.12,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.9)
                  : Colors.black87,
            ),
          ),
          if (destinoSub.isNotEmpty) ...[
            const SizedBox(height: 1),
            Text(
              destinoSub,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                height: 1.1,
                color: isDark
                    ? Colors.white.withValues(alpha: 0.75)
                    : Colors.black45,
              ),
            ),
          ],
        ],
        if ((viajeDist.isNotEmpty || viajeDur.isNotEmpty) &&
            destinoSub.isEmpty) ...[
          const SizedBox(height: 3),
          Text(
            [
              if (viajeDist.isNotEmpty) viajeDist,
              if (viajeDur.isNotEmpty) viajeDur,
            ].join(' · '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
        ],
        const SizedBox(height: 3),
        _buildDenseActionButtons(compact: compact),
      ],
    );
  }

  Widget _infoChip({
    required IconData icon,
    required String label,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: widget.compact ? 8 : 10,
        vertical: widget.compact ? 4 : 6,
      ),
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
    final c = widget.compact;
    final dense = widget.denseList && c;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label.isNotEmpty) ...[
          Text(
            label,
            style: TextStyle(
              fontSize: c ? 10 : 11,
              fontWeight: FontWeight.w700,
              color: labelColor,
              letterSpacing: 0.5,
            ),
          ),
          SizedBox(height: c ? 2 : 4),
        ],
        Text(
          title,
          softWrap: true,
          style: TextStyle(
            fontSize: dense ? 14 : (c ? 16 : (titleLarge ? 22 : 18)),
            fontWeight: FontWeight.w800,
            height: 1.25,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        if (subtitle.isNotEmpty && !c) ...[
          const SizedBox(height: 4),
          Text(
            subtitle,
            softWrap: true,
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
    final compact = widget.compact;
    final dense = widget.denseList && compact;
    final denseEtiquetas = dense
        ? OfertaExclusivaDisplay.etiquetasListaDense(widget.solicitud)
        : null;
    final origenNombre = denseEtiquetas != null
        ? denseEtiquetas.titulo
        : compact
        ? SolicitudDisplayHelper.pickupPlaceLabel(widget.solicitud)
        : SolicitudDisplayHelper.pickupTitleForDriver(widget.solicitud);
    var origenSub = dense
        ? (denseEtiquetas?.subtitulo ?? '')
        : SolicitudDisplayHelper.pickupDetailForDriver(widget.solicitud);
    if (!dense && origenSub.isEmpty) {
      origenSub = SolicitudDisplayHelper.pickupSubtitle(widget.solicitud);
    }
    final coordsHint =
        SolicitudDisplayHelper.pickupCoordinatesHint(widget.solicitud);
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
    final canalOrigen =
        SolicitudDisplayHelper.etiquetaOrigenServicio(widget.solicitud);
    final telefonoLlamada =
        SolicitudDisplayHelper.telefonoLlamadaVisible(widget.solicitud);
    final mostrarAvisoSinMapa =
        OfertaExclusivaDisplay.mostrarAvisoSinMapa(widget.solicitud);
    final textoAvisoSinMapa =
        OfertaExclusivaDisplay.avisoSinMapaTexto(widget.solicitud);
    final titleLarge = widget.destacada && !compact;
    final cardFill = dense
        ? (isDark ? const Color(0xFF262626) : Colors.white)
        : (isDark ? const Color(0xFF1A1A1A) : Colors.white);
    final cardBorder = dense
        ? (isDark
            ? Colors.white.withValues(alpha: 0.14)
            : Colors.black.withValues(alpha: 0.08))
        : (widget.destacada
            ? AppColors.accent
            : Colors.black.withValues(alpha: 0.08));

    final cardBody = Padding(
          padding: dense
              ? const EdgeInsets.fromLTRB(10, 5, 10, 5)
              : compact
              ? const EdgeInsets.fromLTRB(12, 10, 12, 11)
              : const EdgeInsets.fromLTRB(16, 14, 16, 16),
          child: dense
              ? _buildDenseListContent(
                  isDark: isDark,
                  recogidaHeadline: origenNombre,
                  origenSub: origenSub,
                  destinoHeadline: muestraDestino
                      ? SolicitudDisplayHelper.destinationPlaceLabel(
                          widget.solicitud,
                        )
                      : '',
                  destinoSub: destinoSub,
                  muestraDestino: muestraDestino,
                  viajeDist: viajeDist,
                  viajeDur: viajeDur,
                  segundosRestantes: segundosRestantes,
                  enRiesgo: enRiesgo,
                  tiempoPub: tiempoPub,
                  distanciaMi: distanciaMi,
                  precio: precio,
                  compact: compact,
                )
              : Column(
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
                          if (!compact &&
                              barrio != null &&
                              barrio.toLowerCase() !=
                                  origenNombre.toLowerCase()) ...[
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: compact ? 8 : 10,
                                vertical: compact ? 2 : 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.accent.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                barrio.toUpperCase(),
                                style: TextStyle(
                                  fontSize: compact ? 10 : 12,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.4,
                                  color: isDark
                                      ? AppColors.accent
                                      : Colors.orange.shade900,
                                ),
                              ),
                            ),
                            SizedBox(height: compact ? 6 : 10),
                          ],
                          if (canalOrigen != null &&
                              canalOrigen != 'App móvil') ...[
                            Row(
                              children: [
                                Icon(
                                  canalOrigen == 'WhatsApp'
                                      ? Iconsax.message
                                      : Iconsax.call,
                                  size: 14,
                                  color: AppColors.accent,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  telefonoLlamada != null
                                      ? '$canalOrigen · $telefonoLlamada'
                                      : canalOrigen,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: isDark
                                        ? Colors.white70
                                        : Colors.black54,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: compact ? 6 : 8),
                          ],
                          _buildLocationBlock(
                            label: compact ? '' : 'UBICACIÓN',
                            title: origenNombre,
                            subtitle: origenSub,
                            labelColor: AppColors.accent,
                            isDark: isDark,
                            titleLarge: titleLarge,
                          ),
                          if (mostrarAvisoSinMapa && textoAvisoSinMapa.isNotEmpty)
                            ConductorAvisoSinMapa(
                              mensaje: textoAvisoSinMapa,
                              margin: const EdgeInsets.only(top: 10),
                            ),
                          if (coordsHint != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              'GPS: $coordsHint',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade600,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                          ],
                          if (compact &&
                              origenSub.isNotEmpty &&
                              origenSub.toLowerCase() !=
                                  origenNombre.toLowerCase()) ...[
                            const SizedBox(height: 4),
                            Text(
                              origenSub,
                              softWrap: true,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                height: 1.2,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (segundosRestantes > 0)
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: compact ? 8 : 12,
                          vertical: compact ? 5 : 8,
                        ),
                        decoration: BoxDecoration(
                          color: enRiesgo
                              ? Colors.red
                              : Colors.black.withValues(alpha: 0.75),
                          borderRadius: BorderRadius.circular(compact ? 8 : 12),
                        ),
                        child: Text(
                          ServicioEsperaTimer.formatearCuentaRegresiva(
                            segundosRestantes,
                          ),
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: compact ? 14 : 16,
                          ),
                        ),
                      )
                    else if (tiempoPub.isNotEmpty)
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: compact ? 8 : 10,
                          vertical: compact ? 4 : 6,
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
                  SizedBox(height: compact ? 8 : 14),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: EdgeInsets.only(top: compact ? 14 : 18),
                        child: Icon(
                          Iconsax.location,
                          size: compact ? 15 : 18,
                          color: Colors.red.shade400,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: _buildLocationBlock(
                          label: compact ? '' : 'DESTINO',
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
                  SizedBox(height: compact ? 6 : 10),
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
                  SizedBox(height: compact ? 6 : 12),
                  Wrap(
                    spacing: compact ? 6 : 8,
                    runSpacing: compact ? 4 : 6,
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
                SizedBox(height: compact ? 10 : 16),
                Row(
                  children: [
                    if (widget.onRechazar != null) ...[
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _dismiss(widget.onRechazar!),
                          style: OutlinedButton.styleFrom(
                            padding: EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: compact ? 10 : 14,
                            ),
                            side: const BorderSide(color: Colors.red, width: 1.5),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            visualDensity: VisualDensity.compact,
                          ),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              'Rechazar',
                              maxLines: 1,
                              style: TextStyle(
                                fontSize: compact ? 13 : 15,
                                fontWeight: FontWeight.bold,
                                color: Colors.red,
                              ),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: compact ? 8 : 12),
                    ],
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => _dismiss(widget.onAceptar),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(
                            vertical: compact ? 10 : 14,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          elevation: 0,
                          visualDensity: VisualDensity.compact,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Iconsax.tick_circle_copy,
                              size: compact ? 17 : 20,
                            ),
                            SizedBox(width: compact ? 6 : 8),
                            Text(
                              'Aceptar',
                              style: TextStyle(
                                fontSize: compact ? 14 : 16,
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
    );

    final card = Container(
      margin: widget.marginExterno
          ? const EdgeInsets.symmetric(horizontal: 12, vertical: 8)
          : EdgeInsets.zero,
      clipBehavior: dense ? Clip.hardEdge : Clip.none,
      decoration: BoxDecoration(
        color: cardFill,
        borderRadius: BorderRadius.circular(
          dense ? 10 : (compact ? 16 : 20),
        ),
        border: Border.all(
          color: cardBorder,
          width: widget.destacada && !dense ? (compact ? 2 : 2.5) : 1,
        ),
        boxShadow: compact
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.14),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
      ),
      child: cardBody,
    );

    if (dense) return card;

    return SlideTransition(
      position: _slideAnimation,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: card,
      ),
    );
  }
}
