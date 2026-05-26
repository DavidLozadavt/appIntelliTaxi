import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:intellitaxi/core/theme/app_colors.dart';
import 'package:intellitaxi/features/conductor/utils/solicitud_display_helper.dart';
import 'package:intellitaxi/shared/widgets/standard_button.dart';

/// Panel inferior del viaje activo del conductor (pasajero, ruta, acciones).
class ConductorServicioBottomPanel extends StatelessWidget {
  const ConductorServicioBottomPanel({
    super.key,
    required this.servicio,
    required this.estadoUi,
    required this.nombrePasajero,
    this.fotoPasajeroUrl,
    required this.onLlamar,
    required this.onChat,
    required this.onAccionPrincipal,
    required this.onCancelar,
    this.isLoading = false,
  });

  final Map<String, dynamic> servicio;
  final String estadoUi;
  final String nombrePasajero;
  final String? fotoPasajeroUrl;
  final VoidCallback onLlamar;
  final VoidCallback onChat;
  final VoidCallback onAccionPrincipal;
  final VoidCallback onCancelar;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final enCurso = estadoUi == 'en_curso';
    final llegue = estadoUi == 'llegue';
    final soloDestino = enCurso || llegue;
    final recogidaActiva = !soloDestino;

    final etiqueta = enCurso
        ? 'VIAJE EN CURSO'
        : (llegue ? 'ESPERANDO PASAJERO' : 'IR A RECOGIDA');

    final nombreRecogida = SolicitudDisplayHelper.pickupName(servicio);
    final nombreDestino = SolicitudDisplayHelper.destinationName(servicio);
    final subtituloRecogida = SolicitudDisplayHelper.pickupSubtitle(servicio);
    final subtituloDestino = SolicitudDisplayHelper.destinationSubtitle(servicio);

  final accion = _accionPrincipal(estadoUi);

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _BarraPasajero(
                  nombre: nombrePasajero,
                  fotoUrl: fotoPasajeroUrl,
                  isDark: isDark,
                  onLlamar: onLlamar,
                  onChat: onChat,
                ),
                const SizedBox(height: 12),
                _RutaUnificada(
                  etiqueta: etiqueta,
                  soloDestino: soloDestino,
                  recogidaActiva: recogidaActiva,
                  nombreRecogida: nombreRecogida,
                  subtituloRecogida: subtituloRecogida,
                  nombreDestino: nombreDestino,
                  subtituloDestino: subtituloDestino,
                  isDark: isDark,
                ),
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
                StandardButton(
                  text: accion.label,
                  icon: accion.icon,
                  onPressed: onAccionPrincipal,
                  isLoading: isLoading,
                  width: double.infinity,
                  height: 60,
                ),
              if (estadoUi != 'en_curso' &&
                  estadoUi != 'finalizado' &&
                  estadoUi != 'cancelado') ...[
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: onCancelar,
                  icon: Icon(Iconsax.close_circle, color: Colors.red.shade600, size: 20),
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

class _BarraPasajero extends StatelessWidget {
  const _BarraPasajero({
    required this.nombre,
    this.fotoUrl,
    required this.isDark,
    required this.onLlamar,
    required this.onChat,
  });

  final String nombre;
  final String? fotoUrl;
  final bool isDark;
  final VoidCallback onLlamar;
  final VoidCallback onChat;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (fotoUrl != null && fotoUrl!.isNotEmpty)
          CircleAvatar(
            radius: 22,
            backgroundImage: NetworkImage(fotoUrl!),
            onBackgroundImageError: (_, _) {},
          )
        else
          const CircleAvatar(
            radius: 22,
            backgroundColor: AppColors.primary,
            child: Icon(Icons.person, color: Colors.white, size: 24),
          ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            nombre,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
        ),
        _AccionRapida(
          icon: Iconsax.call,
          color: AppColors.green,
          onTap: onLlamar,
          tooltip: 'Llamar',
        ),
        const SizedBox(width: 6),
        _AccionRapida(
          icon: Iconsax.messages_copy,
          color: AppColors.accent,
          onTap: onChat,
          tooltip: 'Mensaje',
        ),
      ],
    );
  }
}

class _AccionRapida extends StatelessWidget {
  const _AccionRapida({
    required this.icon,
    required this.color,
    required this.onTap,
    required this.tooltip,
  });

  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Tooltip(
          message: tooltip,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Icon(icon, color: color, size: 24),
          ),
        ),
      ),
    );
  }
}

class _RutaUnificada extends StatelessWidget {
  const _RutaUnificada({
    required this.etiqueta,
    required this.soloDestino,
    required this.recogidaActiva,
    required this.nombreRecogida,
    required this.subtituloRecogida,
    required this.nombreDestino,
    required this.subtituloDestino,
    required this.isDark,
  });

  final String etiqueta;
  final bool soloDestino;
  final bool recogidaActiva;
  final String nombreRecogida;
  final String subtituloRecogida;
  final String nombreDestino;
  final String subtituloDestino;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.06)
            : Colors.black.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: (soloDestino ? AppColors.green : AppColors.accent)
              .withValues(alpha: 0.35),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: soloDestino ? AppColors.green : AppColors.accent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              etiqueta,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.6,
              ),
            ),
          ),
          const SizedBox(height: 14),
          if (!soloDestino) ...[
            _ParadaRuta(
              icon: Iconsax.location_add,
              label: 'RECOGIDA',
              nombre: nombreRecogida,
              subtitulo: subtituloRecogida,
              color: AppColors.accent,
              activa: recogidaActiva,
              isDark: isDark,
            ),
            Padding(
              padding: const EdgeInsets.only(left: 11, top: 6, bottom: 6),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  width: 2,
                  height: 18,
                  color: Colors.grey.withValues(alpha: 0.35),
                ),
              ),
            ),
            _ParadaRuta(
              icon: Iconsax.location,
              label: 'DESTINO',
              nombre: nombreDestino,
              subtitulo: subtituloDestino,
              color: AppColors.green,
              activa: false,
              resaltada: true,
              isDark: isDark,
            ),
          ] else
            _ParadaRuta(
              icon: Iconsax.location,
              label: 'DESTINO',
              nombre: nombreDestino,
              subtitulo: subtituloDestino,
              color: AppColors.green,
              activa: true,
              isDark: isDark,
            ),
        ],
      ),
    );
  }
}

class _ParadaRuta extends StatelessWidget {
  const _ParadaRuta({
    required this.icon,
    required this.label,
    required this.nombre,
    required this.subtitulo,
    required this.color,
    required this.activa,
    required this.isDark,
    this.resaltada = false,
  });

  final IconData icon;
  final String label;
  final String nombre;
  final String subtitulo;
  final Color color;
  final bool activa;
  final bool isDark;
  final bool resaltada;

  @override
  Widget build(BuildContext context) {
    final mostrarGrande = activa;
    final bordeVisible = activa || resaltada;

    return Container(
      padding: EdgeInsets.all(bordeVisible ? 12 : 0),
      decoration: bordeVisible
          ? BoxDecoration(
              color: color.withValues(alpha: isDark ? 0.14 : 0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: color.withValues(alpha: activa ? 0.55 : 0.35),
                width: activa ? 2 : 1.2,
              ),
            )
          : null,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: mostrarGrande ? 22 : 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: color,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  nombre,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: mostrarGrande ? 28 : 16,
                    fontWeight: mostrarGrande ? FontWeight.w900 : FontWeight.w700,
                    height: 1.12,
                    color: activa
                        ? (isDark ? Colors.white : Colors.black87)
                        : (isDark ? Colors.grey.shade400 : Colors.grey.shade700),
                  ),
                ),
                if (subtitulo.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitulo,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: mostrarGrande ? 14 : 12,
                      fontWeight: FontWeight.w500,
                      height: 1.25,
                      color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
