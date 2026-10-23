import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:intellitaxi/core/theme/app_colors.dart';
import 'package:intellitaxi/features/conductor/utils/solicitud_display_helper.dart';

/// Marca el canal por el que entró el servicio: llamada, WhatsApp o app móvil.
class OrigenServicioBadge extends StatelessWidget {
  const OrigenServicioBadge({
    super.key,
    required this.solicitud,
    this.compact = false,
    this.onDark = false,
    this.mostrarTelefono = false,
  });

  final Map<String, dynamic> solicitud;
  final bool compact;
  final bool onDark;
  final bool mostrarTelefono;

  @override
  Widget build(BuildContext context) {
    final etiqueta = SolicitudDisplayHelper.etiquetaOrigenServicio(solicitud);
    if (etiqueta == null || etiqueta.isEmpty) return const SizedBox.shrink();

    final estilo = _estiloDe(etiqueta);
    final texto = compact ? estilo.corto : etiqueta;
    final telefono = mostrarTelefono && estilo.muestraTelefono
        ? SolicitudDisplayHelper.telefonoLlamadaVisible(solicitud)
        : null;
    final label = telefono == null ? texto : '$texto · $telefono';
    final fg = onDark ? estilo.fgDark : estilo.fg;
    final bg = onDark ? estilo.bgDark : estilo.bg;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 8,
        vertical: compact ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: fg.withValues(alpha: onDark ? 0.55 : 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          estilo.icono(compact ? 11 : 13, fg),
          SizedBox(width: compact ? 3 : 5),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: compact ? 10 : 12,
              fontWeight: FontWeight.w800,
              height: 1.1,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}

class _EstiloOrigen {
  _EstiloOrigen({
    required this.icono,
    required this.fg,
    required this.bg,
    required this.fgDark,
    required this.bgDark,
    required this.corto,
    required this.muestraTelefono,
  });

  final Widget Function(double size, Color color) icono;
  final Color fg;
  final Color bg;
  final Color fgDark;
  final Color bgDark;
  final String corto;
  final bool muestraTelefono;
}

_EstiloOrigen _estiloDe(String etiqueta) {
  switch (etiqueta) {
    case 'WhatsApp':
      return _EstiloOrigen(
        icono: (size, color) => FaIcon(
          FontAwesomeIcons.whatsapp,
          size: size,
          color: color,
        ),
        fg: const Color(0xFF075E54),
        bg: const Color(0xFF25D366).withValues(alpha: 0.18),
        fgDark: const Color(0xFF25D366),
        bgDark: const Color(0xFF25D366).withValues(alpha: 0.16),
        corto: 'WhatsApp',
        muestraTelefono: true,
      );
    case 'Llamada':
      return _EstiloOrigen(
        icono: (size, color) => Icon(Iconsax.call, size: size, color: color),
        fg: const Color(0xFF0D47A1),
        bg: const Color(0xFF1565C0).withValues(alpha: 0.12),
        fgDark: const Color(0xFF90CAF9),
        bgDark: const Color(0xFF1565C0).withValues(alpha: 0.22),
        corto: 'Llamada',
        muestraTelefono: true,
      );
    case 'App móvil':
      return _EstiloOrigen(
        icono: (size, color) =>
            Icon(Iconsax.mobile_copy, size: size, color: color),
        fg: AppColors.brandWine,
        bg: AppColors.accent.withValues(alpha: 0.12),
        fgDark: AppColors.brandWineLight,
        bgDark: AppColors.accent.withValues(alpha: 0.28),
        corto: 'App',
        muestraTelefono: false,
      );
    case 'Web':
      return _EstiloOrigen(
        icono: (size, color) =>
            Icon(Icons.language_rounded, size: size, color: color),
        fg: Colors.deepPurple.shade800,
        bg: Colors.deepPurple.withValues(alpha: 0.12),
        fgDark: Colors.deepPurple.shade200,
        bgDark: Colors.deepPurple.withValues(alpha: 0.25),
        corto: 'Web',
        muestraTelefono: true,
      );
    default:
      return _EstiloOrigen(
        icono: (size, color) =>
            Icon(Iconsax.info_circle, size: size, color: color),
        fg: Colors.black87,
        bg: Colors.black.withValues(alpha: 0.06),
        fgDark: Colors.white70,
        bgDark: Colors.white.withValues(alpha: 0.08),
        corto: etiqueta,
        muestraTelefono: false,
      );
  }
}
