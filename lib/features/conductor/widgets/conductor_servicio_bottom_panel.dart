import 'package:flutter/material.dart';
import 'package:intellitaxi/core/widgets/app_loading_indicator.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:intellitaxi/core/theme/app_colors.dart';
import 'package:intellitaxi/features/chat/widgets/chat_badge_wrap.dart';
import 'package:intellitaxi/features/conductor/utils/solicitud_display_helper.dart';
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
    required this.onCancelar,
    this.servicioId,
    this.isLoading = false,
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
  final VoidCallback onCancelar;
  final int? servicioId;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final enCurso = estadoUi == 'en_curso';
    final llegue = estadoUi == 'llegue';
    final soloDestino = enCurso || llegue;
    final recogidaActiva = !soloDestino;

    final etiquetaEstado = enCurso
        ? 'VIAJE EN CURSO'
        : (llegue ? 'ESPERANDO PASAJERO' : null);

    final recogidaHeadline =
        SolicitudDisplayHelper.pickupHeadline(servicio);
    final destinoHeadline = SolicitudDisplayHelper.hasDestination(servicio)
        ? SolicitudDisplayHelper.destinationHeadline(servicio)
        : '';
    final detalleRecogida =
        SolicitudDisplayHelper.pickupDetailForDriver(servicio);
    final subtituloRecogida = detalleRecogida.trim().isNotEmpty
        ? detalleRecogida
        : SolicitudDisplayHelper.pickupSubtitle(servicio);
    final subtituloDestino =
        SolicitudDisplayHelper.destinationSubtitle(servicio);

    final telefono = telefonoPasajero?.trim() ?? '';
    final accion = _accionPrincipal(estadoUi);
    final muestraDestino = SolicitudDisplayHelper.hasDestination(servicio);
    final tieneContenidoRuta =
        !soloDestino || (muestraDestino && destinoHeadline.isNotEmpty);

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _EstadoYOrigenBar(
                  etiquetaEstado: etiquetaEstado,
                  etiquetaOrigen: etiquetaOrigen,
                  esGestionadoPorIa: esGestionadoPorIa,
                  soloDestino: soloDestino,
                ),
                const SizedBox(height: 10),
                _ContactoCard(
                  nombre: nombrePasajero,
                  telefono: telefono,
                  fotoUrl: fotoPasajeroUrl,
                  esGestionadoPorIa: esGestionadoPorIa,
                  isDark: isDark,
                  onLlamar: onLlamar,
                  onWhatsApp: onWhatsApp,
                  onCopiarTelefono: onCopiarTelefono,
                  onChat: onChat,
                  servicioId: servicioId,
                  compacto: true,
                ),
                if (tieneContenidoRuta) ...[
                  const SizedBox(height: 10),
                  _RutaCard(
                    soloDestino: soloDestino,
                    recogidaActiva: recogidaActiva,
                    recogidaHeadline: recogidaHeadline,
                    subtituloRecogida: subtituloRecogida,
                    destinoHeadline: destinoHeadline,
                    subtituloDestino: subtituloDestino,
                    muestraDestino: muestraDestino,
                    isDark: isDark,
                    destacada: recogidaActiva || soloDestino,
                  ),
                ],
              ],
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            4,
            16,
            12 + MediaQuery.paddingOf(context).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (accion != null)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: isLoading ? null : onAccionPrincipal,
                    icon: isLoading
                        ? const AppBrandLoaderCompact(
                            ringSize: 22,
                            theme: AppLoaderTheme.dark,
                          )
                        : Icon(accion.icon, size: 22),
                    label: Text(
                      accion.label,
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
                      minimumSize: const Size(double.infinity, 56),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              if (estadoUi != 'en_curso' &&
                  estadoUi != 'finalizado' &&
                  estadoUi != 'cancelado') ...[
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: onCancelar,
                  icon: Icon(
                    Iconsax.close_circle,
                    color: Colors.red.shade600,
                    size: 20,
                  ),
                  label: Text(
                    'Cancelar servicio',
                    style: TextStyle(
                      color: Colors.red.shade600,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
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

class _EstadoYOrigenBar extends StatelessWidget {
  const _EstadoYOrigenBar({
    this.etiquetaEstado,
    this.etiquetaOrigen,
    required this.esGestionadoPorIa,
    required this.soloDestino,
  });

  final String? etiquetaEstado;
  final String? etiquetaOrigen;
  final bool esGestionadoPorIa;
  final bool soloDestino;

  @override
  Widget build(BuildContext context) {
    final tieneEstado =
        etiquetaEstado != null && etiquetaEstado!.trim().isNotEmpty;
    final tieneOrigen =
        etiquetaOrigen != null && etiquetaOrigen!.trim().isNotEmpty;
    if (!tieneEstado && !tieneOrigen) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (tieneEstado)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: soloDestino ? AppColors.green : AppColors.accent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              etiquetaEstado!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
            ),
          ),
        if (tieneOrigen) ...[
          SizedBox(height: tieneEstado ? 6 : 0),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: esGestionadoPorIa
                  ? Colors.deepPurple.withValues(alpha: 0.18)
                  : Colors.blue.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: esGestionadoPorIa
                    ? Colors.deepPurple.withValues(alpha: 0.45)
                    : Colors.blue.withValues(alpha: 0.35),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  esGestionadoPorIa ? Iconsax.cpu : Iconsax.building,
                  size: 14,
                  color: esGestionadoPorIa
                      ? Colors.deepPurple.shade300
                      : Colors.blue.shade700,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    etiquetaOrigen ?? '',
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: esGestionadoPorIa
                          ? Colors.deepPurple.shade200
                          : Colors.blue.shade800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _ContactoCard extends StatelessWidget {
  const _ContactoCard({
    required this.nombre,
    required this.telefono,
    this.fotoUrl,
    required this.esGestionadoPorIa,
    required this.isDark,
    required this.onLlamar,
    required this.onWhatsApp,
    required this.onCopiarTelefono,
    required this.onChat,
    this.servicioId,
    this.compacto = false,
  });

  final String nombre;
  final String telefono;
  final String? fotoUrl;
  final bool esGestionadoPorIa;
  final bool isDark;
  final VoidCallback onLlamar;
  final VoidCallback onWhatsApp;
  final VoidCallback onCopiarTelefono;
  final VoidCallback onChat;
  final int? servicioId;
  final bool compacto;

  @override
  Widget build(BuildContext context) {
    final tieneTelefono = telefono.isNotEmpty;

    return Container(
      padding: EdgeInsets.all(compacto ? 10 : 12),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.06)
            : Colors.black.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              SafeCircleAvatar(
                radius: 22,
                imageUrl: fotoUrl,
                backgroundColor: esGestionadoPorIa
                    ? Colors.deepPurple.shade700
                    : AppColors.primary,
                fallback: Icon(
                  esGestionadoPorIa ? Iconsax.cpu : Icons.person,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      esGestionadoPorIa ? 'CLIENTE' : 'PASAJERO',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.4,
                        color: AppColors.accent,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      nombre,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
              _AccionRapida(
                icon: Iconsax.call,
                color: AppColors.green,
                onTap: onLlamar,
                tooltip: 'Llamar',
                enabled: tieneTelefono,
              ),
              const SizedBox(width: 6),
              _WhatsAppAccionRapida(
                onTap: onWhatsApp,
                enabled: tieneTelefono,
              ),
              const SizedBox(width: 6),
              if (!esGestionadoPorIa)
                _AccionRapida(
                  icon: Iconsax.messages_copy,
                  color: AppColors.accent,
                  onTap: onChat,
                  tooltip: 'Chat en app',
                  servicioIdBadge: servicioId,
                ),
            ],
          ),
          if (tieneTelefono || !compacto) ...[
            SizedBox(height: compacto ? 8 : 10),
            Material(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.white,
              borderRadius: BorderRadius.circular(10),
              child: InkWell(
                onTap: tieneTelefono ? onCopiarTelefono : null,
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: compacto ? 10 : 12,
                    vertical: compacto ? 8 : 10,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Iconsax.call,
                        size: compacto ? 16 : 18,
                        color: tieneTelefono
                            ? AppColors.green
                            : Colors.grey.shade500,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (!compacto)
                              Text(
                                'Teléfono de contacto',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            if (!compacto) const SizedBox(height: 2),
                            Text(
                              tieneTelefono ? telefono : 'No disponible',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: compacto ? 15 : 17,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.3,
                                color: tieneTelefono
                                    ? (isDark
                                        ? Colors.white
                                        : Colors.black87)
                                    : Colors.grey.shade500,
                              ),
                            ),
                            if (compacto && tieneTelefono)
                              Text(
                                'Toca para copiar',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (tieneTelefono)
                        IconButton(
                          onPressed: onCopiarTelefono,
                          icon: Icon(
                            Iconsax.copy,
                            size: compacto ? 18 : 20,
                          ),
                          tooltip: 'Copiar teléfono',
                          visualDensity: VisualDensity.compact,
                          color: AppColors.accent,
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
          if (tieneTelefono) ...[
            SizedBox(height: compacto ? 8 : 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onWhatsApp,
                style: FilledButton.styleFrom(
                  backgroundColor: WhatsAppBrandIcon.brandGreen,
                  foregroundColor: Colors.white,
                  minimumSize: Size(double.infinity, compacto ? 50 : 52),
                  padding: EdgeInsets.symmetric(vertical: compacto ? 11 : 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: WhatsAppBrandIcon(size: compacto ? 20 : 18, solid: false),
                label: Text(
                  'Escribir por WhatsApp',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: compacto ? 16 : 15,
                  ),
                ),
              ),
            ),
            if (!compacto) ...[
              const SizedBox(height: 4),
              Text(
                'Toca el número arriba para copiarlo',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _WhatsAppAccionRapida extends StatelessWidget {
  const _WhatsAppAccionRapida({
    required this.onTap,
    this.enabled = true,
  });

  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(12),
        child: Tooltip(
          message: 'WhatsApp',
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Opacity(
              opacity: enabled ? 1 : 0.45,
              child: const WhatsAppBrandIcon(size: 32, solid: true),
            ),
          ),
        ),
      ),
    );
  }
}

class _AccionRapida extends StatelessWidget {
  const _AccionRapida({
    required this.icon,
    required this.color,
    required this.onTap,
    required this.tooltip,
    this.servicioIdBadge,
    this.enabled = true,
  });

  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final String tooltip;
  final int? servicioIdBadge;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    Widget iconWidget = Icon(
      icon,
      color: enabled ? color : Colors.grey.shade500,
      size: 24,
    );
    if (servicioIdBadge != null && servicioIdBadge! > 0) {
      iconWidget = ChatUnreadBadge(
        servicioId: servicioIdBadge!,
        child: iconWidget,
      );
    }

    return Material(
      color: (enabled ? color : Colors.grey).withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(12),
        child: Tooltip(
          message: tooltip,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: iconWidget,
          ),
        ),
      ),
    );
  }
}

class _RutaCard extends StatelessWidget {
  const _RutaCard({
    required this.soloDestino,
    required this.recogidaActiva,
    required this.recogidaHeadline,
    required this.subtituloRecogida,
    required this.destinoHeadline,
    required this.subtituloDestino,
    required this.muestraDestino,
    required this.isDark,
    this.destacada = false,
  });

  final bool soloDestino;
  final bool recogidaActiva;
  final String recogidaHeadline;
  final String subtituloRecogida;
  final String destinoHeadline;
  final String subtituloDestino;
  final bool muestraDestino;
  final bool isDark;
  final bool destacada;

  @override
  Widget build(BuildContext context) {
    final accentColor = soloDestino ? AppColors.green : AppColors.accent;
    return Container(
      padding: EdgeInsets.fromLTRB(14, destacada ? 14 : 12, 14, destacada ? 14 : 14),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: destacada ? 0.08 : 0.05)
            : Colors.black.withValues(alpha: destacada ? 0.05 : 0.03),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: accentColor.withValues(alpha: destacada ? 0.55 : 0.3),
          width: destacada ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!soloDestino) ...[
            _ParadaViaje(
              icon: Iconsax.location_add,
              color: AppColors.accent,
              headline: recogidaHeadline,
              detalle: subtituloRecogida,
              activa: recogidaActiva,
              isDark: isDark,
            ),
            if (muestraDestino && destinoHeadline.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.only(left: 10, top: 8, bottom: 8),
                child: Container(
                  width: 2,
                  height: 16,
                  color: Colors.grey.withValues(alpha: 0.35),
                ),
              ),
              _ParadaViaje(
                icon: Iconsax.location,
                color: AppColors.green,
                headline: destinoHeadline,
                detalle: subtituloDestino,
                activa: false,
                isDark: isDark,
              ),
            ],
          ] else if (muestraDestino && destinoHeadline.isNotEmpty)
            _ParadaViaje(
              icon: Iconsax.location,
              color: AppColors.green,
              headline: destinoHeadline,
              detalle: subtituloDestino,
              activa: true,
              isDark: isDark,
            ),
        ],
      ),
    );
  }
}

class _ParadaViaje extends StatelessWidget {
  const _ParadaViaje({
    required this.icon,
    required this.color,
    required this.headline,
    required this.detalle,
    required this.activa,
    required this.isDark,
  });

  final IconData icon;
  final Color color;
  final String headline;
  final String detalle;
  final bool activa;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                headline,
                softWrap: true,
                style: TextStyle(
                  fontSize: activa ? 17 : 15,
                  fontWeight: FontWeight.w800,
                  height: 1.25,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              if (detalle.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  detalle,
                  softWrap: true,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    height: 1.3,
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.72)
                        : Colors.black54,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
