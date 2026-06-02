import 'package:intellitaxi/features/conductor/utils/conductor_servicio_pasajero_helper.dart';
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

  /// Línea gris inferior sin repetir barrio ni título ya mostrados arriba.
  String get direccionVisible => OfertaExclusivaDisplay.direccionSinDuplicar(
        barrio: barrio,
        titulo: titulo,
        direccion: direccion,
      );
}

abstract final class OfertaExclusivaDisplay {
  static const String notaRecogidaSinCoordenadas =
      'Sin GPS: la IA pudo equivocarse. Acepta y confirma con el cliente por teléfono.';

  /// Aviso en oferta/tarjeta: servicio IA sin GPS de recogida (tras dejar de cargar).
  static bool mostrarNotaRecogidaSinCoordenadas(
    Map<String, dynamic> data, {
    bool cargandoDireccion = false,
  }) {
    if (cargandoDireccion) return false;
    final n = SolicitudDisplayHelper.normalizeSolicitudMap(data);
    if (!ConductorServicioPasajeroHelper.esGestionadoPorIa(n)) return false;
    return !SolicitudDisplayHelper.tieneCoordenadasRecogidaValidas(n);
  }

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
    // Sin GPS no hay reverse geocode: evitar spinner infinito.
    if (!tieneCoords) return false;
    return SolicitudDisplayHelper.necesitaEnriquecimientoGeocode(n);
  }

  /// Texto cuando no hay barrio/calle tras geocode (o el API no trae coords).
  static String tituloRecogidaFallback(Map<String, dynamic> data) {
    final n = SolicitudDisplayHelper.normalizeSolicitudMap(data);
    final hint = SolicitudDisplayHelper.pickupCoordinatesHint(n);
    if (hint != null) return hint;
    final addr = n['origen_address']?.toString().trim() ??
        n['origen']?.toString().trim();
    if (addr != null && addr.isNotEmpty) {
      return SolicitudDisplayHelper.formatReadablePlaceName(addr);
    }
    if (!SolicitudDisplayHelper.hasDestination(n)) {
      return 'Servicio sin destino fijo';
    }
    return 'Dirección no disponible';
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
      direccion: direccionSinDuplicar(
        barrio: barrio,
        titulo: titulo,
        direccion: direccion,
      ),
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
      direccion: direccionSinDuplicar(
        barrio: barrio,
        titulo: titulo,
        direccion: direccion,
      ),
    );
  }

  /// Quita barrio/título ya visibles en la tarjeta (evita «Comuna 7» dos veces).
  static String direccionSinDuplicar({
    String? barrio,
    required String titulo,
    required String direccion,
  }) {
    var d = direccion.trim();
    if (d.isEmpty) return '';

    final b = barrio?.trim() ?? '';
    final t = titulo.trim();

    if (_igualLugar(d, b) || _igualLugar(d, t)) return '';

    if (t.isNotEmpty) d = _quitarSegmentos(d, t);
    if (b.isNotEmpty) d = _quitarSegmentos(d, b);

    d = d.replaceAll(RegExp(r'^[·,\s]+|[·,\s]+$'), '').trim();
    if (d.isEmpty) return '';
    if (_igualLugar(d, b) || _igualLugar(d, t)) return '';
    if (b.isNotEmpty &&
        t.isNotEmpty &&
        (_igualLugar(d, '$t, $b') || _igualLugar(d, '$t · $b'))) {
      return '';
    }
    if (b.isNotEmpty && t.isNotEmpty && _contieneLugar(d, b) && _contieneLugar(d, t)) {
      return '';
    }
    return d;
  }

  static String _norm(String value) =>
      value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  static bool _igualLugar(String a, String b) {
    if (a.isEmpty || b.isEmpty) return false;
    return _norm(a) == _norm(b);
  }

  static bool _contieneLugar(String haystack, String needle) {
    final h = _norm(haystack);
    final n = _norm(needle);
    if (n.isEmpty) return false;
    return h == n || h.contains(n);
  }

  static String _quitarSegmentos(String texto, String segmento) {
    if (segmento.isEmpty) return texto;
    final seg = segmento.trim();
    var t = texto.trim();
    if (_igualLugar(t, seg)) return '';

    final partes = t
        .split(RegExp(r'\s*[·,]\s*'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    if (partes.length > 1) {
      final restantes = partes.where((p) => !_igualLugar(p, seg)).toList();
      if (restantes.isEmpty) return '';
      return restantes.join(' · ');
    }

    final lower = t.toLowerCase();
    final segLower = seg.toLowerCase();
    if (lower.startsWith('$segLower,')) {
      t = t.substring(seg.length + 1).trim();
    } else if (lower.endsWith(', $segLower')) {
      t = t.substring(0, t.length - seg.length - 2).trim();
    }
    return _igualLugar(t, seg) ? '' : t;
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
