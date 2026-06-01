import 'package:intellitaxi/features/conductor/utils/solicitud_display_helper.dart';

/// Textos de recogida/destino para pantalla oferta exclusiva.
class OfertaUbicacionVista {
  const OfertaUbicacionVista({
    this.barrio,
    required this.titulo,
    required this.direccion,
  });

  final String? barrio;
  final String titulo;
  final String direccion;

  bool get tieneContenido =>
      titulo.trim().isNotEmpty ||
      (direccion.trim().isNotEmpty) ||
      (barrio != null && barrio!.trim().isNotEmpty);

  bool get tieneDireccionLegible {
    if (barrio != null && barrio!.trim().isNotEmpty) return true;
    return titulo.trim().isNotEmpty &&
        !OfertaExclusivaDisplay._tituloVacio(titulo);
  }
}

abstract final class OfertaExclusivaDisplay {
  /// Mientras llega geocoding o el payload aún no trae barrio/calle.
  static bool mostrarCargandoDireccion(Map<String, dynamic> data) {
    final v = recogida(data);
    if (v.tieneDireccionLegible) return false;
    final n = SolicitudDisplayHelper.normalizeSolicitudMap(data);
    final lat = SolicitudDisplayHelper.parseCoordinate(n['origen_lat']);
    final lng = SolicitudDisplayHelper.parseCoordinate(n['origen_lng']);
    final tieneCoords = lat != null &&
        lng != null &&
        (lat.abs() > 0.0001 || lng.abs() > 0.0001);
    if (!tieneCoords &&
        !SolicitudDisplayHelper.necesitaEnriquecimientoGeocode(n)) {
      return false;
    }
    return true;
  }

  static OfertaUbicacionVista recogida(Map<String, dynamic> data) {
    final n = SolicitudDisplayHelper.normalizeSolicitudMap(data);
    var barrio = _barrioLegible(SolicitudDisplayHelper.barrioFromPayload(n));
    var titulo = SolicitudDisplayHelper.formatReadablePlaceName(
      SolicitudDisplayHelper.pickupTitleForDriver(n),
    );

    if (_tituloVacio(titulo)) {
      titulo = SolicitudDisplayHelper.formatReadablePlaceName(
        SolicitudDisplayHelper.pickupHeadline(n),
      );
    }
    if (_tituloVacio(titulo)) {
      final split = _splitOrigenDestino(n['origen']?.toString());
      if (split != null) {
        titulo = split.$1;
        barrio ??= split.$2;
      }
    }

    var direccion = _direccionRecogida(n, titulo: titulo, barrio: barrio);
    if (direccion.isEmpty) {
      final addr = n['origen_address']?.toString() ??
          n['origen']?.toString() ??
          '';
      if (addr.contains(',') && !_tituloVacio(titulo)) {
        direccion = addr.trim();
      }
    }

    return OfertaUbicacionVista(
      barrio: barrio,
      titulo: titulo,
      direccion: direccion,
    );
  }

  static bool _tituloVacio(String titulo) {
    if (titulo.trim().isEmpty) return true;
    if (SolicitudDisplayHelper.isPlaceholderPickup(titulo)) return true;
    return titulo.toLowerCase() == 'punto de recogida' ||
        titulo.toLowerCase() == 'nueva recogida';
  }

  static (String, String)? _splitOrigenDestino(String? texto) {
    if (texto == null || !texto.contains(',')) return null;
    final partes =
        texto.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    if (partes.isEmpty) return null;
    final calle = SolicitudDisplayHelper.formatReadablePlaceName(partes.first);
    final barrio = partes.length > 1
        ? SolicitudDisplayHelper.formatReadablePlaceName(
            partes.sublist(1).join(', '),
          )
        : '';
    return (calle, barrio);
  }

  static OfertaUbicacionVista? destino(Map<String, dynamic> data) {
    final n = SolicitudDisplayHelper.normalizeSolicitudMap(data);
    final nombre = SolicitudDisplayHelper.destinationName(n);
    if (SolicitudDisplayHelper.isPlaceholderDestino(nombre)) return null;

    final barrio = _barrioLegible(
      n['destino_barrio']?.toString() ??
          n['barrio_destino']?.toString(),
    );
    final titulo = SolicitudDisplayHelper.formatReadablePlaceName(nombre);
    final addr = n['destino_address']?.toString() ??
        n['destino_direccion']?.toString() ??
        n['direccion_destino']?.toString();
    var direccion = '';
    if (addr != null && addr.trim().isNotEmpty) {
      direccion = SolicitudDisplayHelper.routeAddressSubtitle(addr.trim());
    } else {
      final dest = n['destino']?.toString().trim() ?? '';
      if (dest.contains(',') && dest != titulo) {
        direccion = SolicitudDisplayHelper.routeAddressSubtitle(dest);
      }
    }
    return OfertaUbicacionVista(
      barrio: barrio,
      titulo: titulo,
      direccion: direccion,
    );
  }

  /// Texto natural para TTS (oferta exclusiva conductor).
  static String textoParaVoz(OfertaUbicacionVista recogida) {
    final partes = <String>[];
    final b = recogida.barrio?.trim() ?? '';
    final t = recogida.titulo.trim();
    final d = recogida.direccion.trim();
    if (b.isNotEmpty) partes.add(b);
    if (t.isNotEmpty && t.toLowerCase() != b.toLowerCase()) partes.add(t);
    if (d.isNotEmpty) partes.add(d);
    return partes.join(', ');
  }

  static String distanciaTexto(double? km) {
    if (km == null || km <= 0) return '';
    if (km < 1) {
      final m = (km * 1000).round();
      return m >= 1000 ? 'A ${km.toStringAsFixed(1)} km' : 'A $m m de ti';
    }
    return 'A ${km.toStringAsFixed(1)} km de ti';
  }

  static String? _barrioLegible(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    return SolicitudDisplayHelper.formatReadablePlaceName(raw.trim());
  }

  static String _direccionRecogida(
    Map<String, dynamic> n, {
    required String titulo,
    String? barrio,
  }) {
    final parts = <String>[];
    final addr = SolicitudDisplayHelper.pickupDetailForDriver(n);
    if (addr.isNotEmpty) {
      for (final p in addr.split('·')) {
        final t = p.trim();
        if (t.isEmpty) continue;
        if (barrio != null &&
            SolicitudDisplayHelper.formatReadablePlaceName(t) == barrio) {
          continue;
        }
        if (t == titulo) continue;
        parts.add(t);
      }
    }

    final origen = n['origen']?.toString().trim() ?? '';
    if (parts.isEmpty && origen.isNotEmpty && origen != titulo) {
      if (origen.contains(',')) {
        final split = origen.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty);
        for (final p in split) {
          if (p == titulo || p == barrio) continue;
          parts.add(SolicitudDisplayHelper.routeAddressSubtitle(p));
        }
        if (parts.isEmpty) {
          parts.add(SolicitudDisplayHelper.routeAddressSubtitle(origen));
        }
      } else if (origen != titulo) {
        parts.add(origen);
      }
    }

    if (parts.isEmpty && titulo.isNotEmpty && !SolicitudDisplayHelper.isPlaceholderPickup(titulo)) {
      final origenAddr = n['origen_address']?.toString() ??
          n['origen_direccion']?.toString();
      if (origenAddr != null && origenAddr.trim().isNotEmpty) {
        return SolicitudDisplayHelper.routeAddressSubtitle(origenAddr.trim());
      }
    }

    return parts.join(' · ');
  }
}
