import 'package:flutter/material.dart';
import 'package:intellitaxi/core/widgets/app_loading_indicator.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:intellitaxi/core/theme/app_colors.dart';
import 'package:intellitaxi/features/chat/widgets/chat_badge_wrap.dart';
import 'package:intellitaxi/features/conductor/utils/solicitud_display_helper.dart';
import 'package:intellitaxi/features/conductor/widgets/origen_servicio_badge.dart';
import 'package:intellitaxi/shared/widgets/whatsapp_brand_icon.dart';
import 'package:intellitaxi/shared/optimized_image_widgets.dart';
/// Panel inferior del viaje activo del conductor (contacto, ruta, acciones).
class ConductorServicioBottomPanel extends StatelessWidget {
  const ConductorServicioBottomPanel({
    super.key,
    required this.servicio,
    required this.estadoUi,
    required this.nombrePasajero,
    this.telefonoPasajero,
    this.etiquetaOrigen,
    this.esGestionadoPorIa = false,
    this.fotoPasajeroUrl,
    required this.onLlamar,
    required this.onWhatsApp,
    required this.onCopiarTelefono,
    required this.onChat,
    required this.onAccionPrincipal,
    required this.onRechazar,
    this.onNavegarAlPin,
    this.servicioId,
    this.isLoading = false,
    this.scrollController,
    this.topInset = 0,
  });

  final Map<String, dynamic> servicio;
  final String estadoUi;
  final String nombrePasajero;
  final String? telefonoPasajero;
  final String? etiquetaOrigen;
  final bool esGestionadoPorIa;
  final String? fotoPasajeroUrl;
  final VoidCallback onLlamar;
  final VoidCallback onWhatsApp;
  final VoidCallback onCopiarTelefono;
  final VoidCallback onChat;
  final VoidCallback onAccionPrincipal;
  final VoidCallback onRechazar;
  final VoidCallback? onNavegarAlPin;
  final int? servicioId;
  final bool isLoading;
  final ScrollController? scrollController;
  final double topInset;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final enCurso = estadoUi == 'en_curso';
    final llegue = estadoUi == 'llegue';
    final soloDestino = enCurso || llegue;

    final recogidaClara =
        SolicitudDisplayHelper.direccionClara(servicio, destino: false);
    final destinoClara = SolicitudDisplayHelper.hasDestination(servicio)
        ? SolicitudDisplayHelper.direccionClara(servicio, destino: true)
        : (principal: '', detalle: '');
    final recogidaHeadline = recogidaClara.principal;
    final destinoHeadline = destinoClara.principal;
    final subtituloRecogida = recogidaClara.detalle;
    final subtituloDestino = destinoClara.detalle;

    final telefono = telefonoPasajero?.trim() ?? '';
    final canalOrigen =
        SolicitudDisplayHelper.etiquetaOrigenServicio(servicio);
    final accion = _accionPrincipal(estadoUi);
    final muestraDestino = SolicitudDisplayHelper.hasDestination(servicio);
    final tieneContenidoRuta = recogidaHeadline.trim().isNotEmpty ||
        (muestraDestino && destinoHeadline.isNotEmpty);

    final calificacion = _calificacionPasajero(servicio);

    final puedeRechazar = estadoUi != 'en_curso' &&
        estadoUi != 'finalizado' &&
        estadoUi != 'cancelado';

    return SingleChildScrollView(
      controller: scrollController,
      physics: const AlwaysScrollableScrollPhysics(
        parent: ClampingScrollPhysics(),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 4 + topInset, 16, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : const Color(0xFFD1D5DB),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            _PasajeroHeader(
              nombre: nombrePasajero,
              telefono: telefono,
              fotoUrl: fotoPasajeroUrl,
              esGestionadoPorIa: esGestionadoPorIa,
              calificacion: calificacion,
              isDark: isDark,
              onCopiarTelefono: onCopiarTelefono,
              onChat: esGestionadoPorIa ? null : onChat,
              insignia: canalOrigen == null
                  ? null
                  : OrigenServicioBadge(
                      solicitud: servicio,
                      onDark: isDark,
                      compact: true,
                    ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: telefono.isEmpty ? null : onLlamar,
                    icon: const Icon(Iconsax.call, size: 18),
                    label: const Text(
                      'Llamar',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor:
                          isDark ? Colors.white : const Color(0xFF1F2937),
                      minimumSize: const Size(0, 42),
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      side: BorderSide(
                        color: isDark
                            ? Colors.white24
                            : const Color(0xFFE5E7EB),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ChatUnreadBadge(
                  servicioId: servicioId ?? 0,
                  child: Material(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                    child: InkWell(
                      onTap: onChat,
                      borderRadius: BorderRadius.circular(14),
                      child: const SizedBox(
                        width: 46,
                        height: 42,
                        child: Icon(
                          Iconsax.messages_copy,
                          color: AppColors.primary,
                          size: 22,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: telefono.isEmpty ? null : onWhatsApp,
                    icon: const WhatsAppBrandIcon(
                      size: 18,
                      solid: false,
                      color: Colors.white,
                    ),
                    label: const Text(
                      'WhatsApp',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF1FA855),
                      foregroundColor: Colors.white,
                      minimumSize: const Size(0, 42),
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (tieneContenidoRuta) ...[
              const SizedBox(height: 12),
              _ItinerarioCard(
                recogidaTitulo: recogidaHeadline,
                recogidaDetalle: subtituloRecogida,
                destinoTitulo: destinoHeadline,
                destinoDetalle: subtituloDestino,
                muestraDestino: muestraDestino && destinoHeadline.isNotEmpty,
                estadoDestino: soloDestino ? 'En curso' : 'En espera',
                isDark: isDark,
                onAbrirGps: onNavegarAlPin,
              ),
            ],
            if (accion != null) ...[
              const SizedBox(height: 12),
              _BotonAccionPrincipal(
                label: accion.label,
                icon: accion.icon,
                isLoading: isLoading,
                onPressed: onAccionPrincipal,
                palpita: llegue && !isLoading,
              ),
            ],
            if (puedeRechazar)
              TextButton.icon(
                onPressed: onRechazar,
                icon: Icon(
                  Iconsax.close_circle,
                  color: Colors.red.shade400,
                  size: 16,
                ),
                label: Text(
                  'Rechazar o cancelar servicio',
                  style: TextStyle(
                    color: Colors.red.shade400,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(vertical: 6),
                ),
              ),
            SizedBox(height: MediaQuery.paddingOf(context).bottom + 4),
          ],
        ),
      ),
    );
  }

  static String? _calificacionPasajero(Map<String, dynamic> servicio) {
    final pasajero = servicio['pasajero'];
    final raw = servicio['pasajero_calificacion'] ??
        servicio['calificacion_pasajero'] ??
        (pasajero is Map ? pasajero['calificacion'] : null);
    if (raw == null) return null;
    final texto = raw.toString().trim();
    final valor = double.tryParse(texto);
    if (valor == null || valor <= 0) return null;
    return valor.toStringAsFixed(1);
  }

  _AccionPrincipal? _accionPrincipal(String estado) {
    switch (estado) {
      case 'aceptado':
      case 'en_camino':
        return _AccionPrincipal('LLEGUÉ AL PUNTO DE RECOGIDA', Iconsax.tick_circle);
      case 'llegue':
        return _AccionPrincipal('INICIAR VIAJE', Iconsax.play_circle);
      case 'en_curso':
        return _AccionPrincipal('FINALIZAR VIAJE', Iconsax.flag);
      default:
        return null;
    }
  }
}

class _AccionPrincipal {
  const _AccionPrincipal(this.label, this.icon);
  final String label;
  final IconData icon;
}

class _BotonAccionPrincipal extends StatefulWidget {
  const _BotonAccionPrincipal({
    required this.label,
    required this.icon,
    required this.isLoading,
    required this.onPressed,
    required this.palpita,
  });

  final String label;
  final IconData icon;
  final bool isLoading;
  final VoidCallback onPressed;
  final bool palpita;

  @override
  State<_BotonAccionPrincipal> createState() => _BotonAccionPrincipalState();
}

class _BotonAccionPrincipalState extends State<_BotonAccionPrincipal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _syncPulse();
  }

  @override
  void didUpdateWidget(covariant _BotonAccionPrincipal oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.palpita != widget.palpita) {
      _syncPulse();
    }
  }

  void _syncPulse() {
    if (widget.palpita) {
      _pulse.repeat(reverse: true);
    } else {
      _pulse
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final boton = SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: widget.isLoading ? null : widget.onPressed,
        icon: widget.isLoading
            ? const AppBrandLoaderCompact(
                ringSize: 22,
                theme: AppLoaderTheme.dark,
              )
            : Icon(widget.icon, size: 22),
        label: Text(
          widget.label,
          textAlign: TextAlign.center,
          maxLines: 2,
          softWrap: true,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 50),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );

    if (!widget.palpita) return boton;

    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, child) {
        final t = _pulse.value;
        return Transform.scale(
          scale: 1 + (t * 0.045),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.22 + (t * 0.28)),
                  blurRadius: 10 + (t * 16),
                  spreadRadius: 1 + (t * 4),
                ),
              ],
            ),
            child: child,
          ),
        );
      },
      child: boton,
    );
  }
}

class _PasajeroHeader extends StatelessWidget {
  const _PasajeroHeader({
    required this.nombre,
    required this.telefono,
    required this.fotoUrl,
    required this.esGestionadoPorIa,
    required this.calificacion,
    required this.isDark,
    required this.onCopiarTelefono,
    required this.onChat,
    this.insignia,
  });

  final String nombre;
  final String telefono;
  final String? fotoUrl;
  final bool esGestionadoPorIa;
  final String? calificacion;
  final bool isDark;
  final VoidCallback onCopiarTelefono;
  final VoidCallback? onChat;
  final Widget? insignia;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SafeCircleAvatar(
          radius: 24,
          imageUrl: fotoUrl,
          backgroundColor: esGestionadoPorIa
              ? Colors.deepPurple.shade700
              : AppColors.primary,
          fallback: Icon(
            esGestionadoPorIa ? Iconsax.cpu : Icons.person,
            color: Colors.white,
            size: 26,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                esGestionadoPorIa ? 'CLIENTE' : 'PASAJERO',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                  color: Colors.grey.shade500,
                ),
              ),
              Text(
                nombre,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 17,
                  height: 1.15,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : const Color(0xFF111827),
                ),
              ),
              if (telefono.isNotEmpty)
                InkWell(
                  onTap: onCopiarTelefono,
                  onLongPress: onChat,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Row(
                      children: [
                        const Icon(
                          Iconsax.call,
                          size: 14,
                          color: AppColors.green,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            telefono,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF374151),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              if (calificacion != null)
                Row(
                  children: [
                    const Icon(
                      Icons.star_rounded,
                      size: 16,
                      color: Color(0xFFF5B400),
                    ),
                    Text(
                      calificacion!,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
        if (insignia != null) ...[
          const SizedBox(width: 8),
          insignia!,
        ],
      ],
    );
  }
}

class _ItinerarioCard extends StatelessWidget {
  const _ItinerarioCard({
    required this.recogidaTitulo,
    required this.recogidaDetalle,
    required this.destinoTitulo,
    required this.destinoDetalle,
    required this.muestraDestino,
    required this.estadoDestino,
    required this.isDark,
    required this.onAbrirGps,
  });

  final String recogidaTitulo;
  final String recogidaDetalle;
  final String destinoTitulo;
  final String destinoDetalle;
  final bool muestraDestino;
  final String estadoDestino;
  final bool isDark;
  final VoidCallback? onAbrirGps;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.05)
            : const Color(0xFFF7F7F8),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ITINERARIO DEL VIAJE',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
              color: Colors.grey.shade500,
            ),
          ),
          const SizedBox(height: 8),
          _ParadaItinerario(
            color: AppColors.primary,
            etiqueta: 'Punto de recogida',
            titulo: recogidaTitulo,
            detalle: recogidaDetalle,
            isDark: isDark,
            trailing: onAbrirGps == null
                ? null
                : TextButton.icon(
                    onPressed: onAbrirGps,
                    icon: const Icon(Iconsax.gps, size: 16),
                    label: const Text('Abrir GPS'),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF6D28D9),
                      backgroundColor: const Color(0xFFF3EEFF),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      textStyle: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                  ),
          ),
          if (muestraDestino) ...[
            Padding(
              padding: const EdgeInsets.only(left: 7, top: 2, bottom: 2),
              child: Container(
                width: 2,
                height: 10,
                color: const Color(0xFFE5E7EB),
              ),
            ),
            _ParadaItinerario(
              color: const Color(0xFF22C55E),
              etiqueta: 'Punto de llegada',
              titulo: destinoTitulo,
              detalle: destinoDetalle,
              isDark: isDark,
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white10 : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: Text(
                  estadoDestino,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey.shade600,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ParadaItinerario extends StatelessWidget {
  const _ParadaItinerario({
    required this.color,
    required this.etiqueta,
    required this.titulo,
    required this.detalle,
    required this.isDark,
    required this.trailing,
  });

  final Color color;
  final String etiqueta;
  final String titulo;
  final String detalle;
  final bool isDark;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: color, width: 4),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                etiqueta,
                style: TextStyle(
                  color: color,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(left: 26, top: 2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                titulo,
                softWrap: true,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  height: 1.15,
                  color: isDark ? Colors.white : const Color(0xFF111827),
                ),
              ),
              if (detalle.trim().isNotEmpty)
                Text(
                  detalle,
                  softWrap: true,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.25,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white70 : const Color(0xFF6B7280),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

