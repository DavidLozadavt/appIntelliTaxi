/// Textos de solicitud orientados a lectura rápida al volante.
class SolicitudDisplayHelper {
  SolicitudDisplayHelper._();

  static const String _pickupPlaceholder = 'Dirección de recogida no disponible';
  static const String _destinoPlaceholder = 'Destino no especificado';

  /// Unifica payload Pusher/API (anidado, camelCase, snake_case, inglés/español).
  static Map<String, dynamic> normalizeSolicitudMap(Map<String, dynamic> raw) {
    final m = Map<String, dynamic>.from(raw);

    for (final key in const ['servicio', 'solicitud', 'data', 'ride']) {
      final nested = m[key];
      if (nested is Map) {
        m.addAll(Map<String, dynamic>.from(nested));
      }
    }

    // Coordenadas: snake_case (socket), camelCase (servicioMovil / API Laravel).
    m['origen_lat'] ??=
        m['origenLat'] ?? m['origin_lat'] ?? m['originLat'] ?? m['lat_origen'];
    m['origen_lng'] ??=
        m['origenLng'] ?? m['origin_lng'] ?? m['originLng'] ?? m['lng_origen'];
    m['destino_lat'] ??= m['destinoLat'] ??
        m['destination_lat'] ??
        m['destinationLat'] ??
        m['lat_destino'];
    m['destino_lng'] ??= m['destinoLng'] ??
        m['destination_lng'] ??
        m['destinationLng'] ??
        m['lng_destino'];

    // Nombre del lugar (ej. "Aguas Vivas", "Casa Rosada") — columnas origenName/destinoName.
    m['origen_name'] ??= m['origenName'] ??
        m['origin_name'] ??
        m['originName'] ??
        m['origen_nombre'];
    m['destino_name'] ??= m['destinoName'] ??
        m['destination_name'] ??
        m['destinationName'] ??
        m['destino_nombre'];

    // Dirección completa — columnas origenAddress/destinoAddress.
    m['origen_address'] ??= m['origenAddress'] ??
        m['origin_address'] ??
        m['originAddress'] ??
        m['direccion_origen'];
    m['destino_address'] ??= m['destinoAddress'] ??
        m['destination_address'] ??
        m['destinationAddress'] ??
        m['direccion_destino'];

    // Socket legacy: "origen"/"destino" son direcciones, NO nombres de lugar.
    final legacyOrigen = m['origen']?.toString().trim();
    if (legacyOrigen != null &&
        legacyOrigen.isNotEmpty &&
        (m['origen_address'] == null ||
            m['origen_address'].toString().trim().isEmpty)) {
      m['origen_address'] = legacyOrigen;
    }
    final legacyDestino = m['destino']?.toString().trim();
    if (legacyDestino != null &&
        legacyDestino.isNotEmpty &&
        (m['destino_address'] == null ||
            m['destino_address'].toString().trim().isEmpty)) {
      m['destino_address'] = legacyDestino;
    }

    m['distancia_metros'] ??= m['distanciaMetros'] ?? m['distance_value'];
    m['distancia_texto'] ??= m['distanciaTexto'] ?? m['distance'];
    m['duracion_segundos'] ??= m['duracionSegundos'] ?? m['duration_value'];
    m['duracion_texto'] ??= m['duracionTexto'] ?? m['duration'];

    m['origen_servicio'] ??= m['origenServicio'];
    m['telefono_llamada'] ??=
        m['telefonoLlamada'] ?? m['telefono_llamada_servicio'];
    m['overlay_expira_en'] ??= m['overlayExpiraEn'];
    m['dentro_radio_accion'] ??= m['dentroRadioAccion'];

    final barrio = barrioFromPayload(m);
    if (barrio != null) {
      m['origen_barrio'] = compactBarrio(barrio);
    }

    return m;
  }

  /// Etiqueta corta para `origen_servicio` (WHATSAPP, LLAMADA, APP_MOVIL, …).
  static String? etiquetaOrigenServicio(Map<String, dynamic> data) {
    final raw =
        (data['origen_servicio'] ?? data['origenServicio'])?.toString().trim();
    if (raw == null || raw.isEmpty) return null;
    switch (raw.toUpperCase()) {
      case 'WHATSAPP':
        return 'WhatsApp';
      case 'LLAMADA':
        return 'Llamada';
      case 'APP_MOVIL':
      case 'APP_MOVIL_PASAJERO':
        return 'App móvil';
      case 'APP_WEB':
        return 'Web';
      default:
        return raw.replaceAll('_', ' ');
    }
  }

  /// Teléfono a mostrar en solicitudes telefónicas (`pasajero_id` puede ser 0).
  static String? telefonoLlamadaVisible(Map<String, dynamic> data) {
    final t = (data['telefono_llamada'] ??
            data['telefonoLlamada'] ??
            data['pasajero_telefono'])
        ?.toString()
        .trim();
    if (t == null || t.isEmpty) return null;
    return t;
  }

  static String? _firstNonEmpty(
    Map<String, dynamic> data,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = data[key]?.toString().trim();
      if (value != null && value.isNotEmpty) return value;
    }
    return null;
  }

  static String? _pickupNameRaw(Map<String, dynamic> data) {
    return _firstNonEmpty(data, const [
      'origen_name',
      'origenName',
      'origen_nombre',
      'origin_name',
      'originName',
    ]);
  }

  static String? _pickupAddressRaw(Map<String, dynamic> data) {
    return _firstNonEmpty(data, const [
      'origen_address',
      'origenAddress',
      'origin_address',
      'originAddress',
      'origen',
      'direccion_origen',
      'pickup_address',
    ]);
  }

  static String? _destinationNameRaw(Map<String, dynamic> data) {
    return _firstNonEmpty(data, const [
      'destino_name',
      'destinoName',
      'destino_nombre',
      'destination_name',
      'destinationName',
    ]);
  }

  static String? _destinationAddressRaw(Map<String, dynamic> data) {
    return _firstNonEmpty(data, const [
      'destino_address',
      'destinoAddress',
      'destination_address',
      'destinationAddress',
      'destino',
      'direccion_destino',
    ]);
  }

  static String? barrioFromPayload(Map<String, dynamic> data) {
    for (final key in const [
      'origen_barrio',
      'barrio_origen',
      'barrio',
      'neighborhood',
      'zona_origen',
    ]) {
      final value = data[key]?.toString().trim();
      if (value != null && value.isNotEmpty && !_looksLikeFullAddress(value)) {
        return compactBarrio(value);
      }
    }
    final zona = data['zona']?.toString().trim();
    if (zona != null && zona.isNotEmpty && !_looksLikeFullAddress(zona)) {
      return compactBarrio(zona);
    }
    return null;
  }

  static String compactBarrio(String? value) {
    if (value == null || value.trim().isEmpty) return '';
    final parts = value
        .trim()
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    if (parts.isEmpty) return value.trim();
    return parts.first;
  }

  /// Convierte una dirección completa en un "nombre corto" legible para alertas.
  ///
  /// Heurísticas:
  /// - Si contiene " - " tomamos la primera parte (ej. "Casa Rosada - E.S.E. ...")
  /// - Si no, usamos la primera parte antes de coma (ej. "Aguas Vivas, Popayán, ...")
  static String placeNameFromAddress(String value) {
    final cleaned = value.trim();
    final beforeDash = cleaned.split(' - ').first.trim();
    final candidate = beforeDash.isNotEmpty ? beforeDash : cleaned;
    return compactBarrio(candidate);
  }

  static bool _looksLikeFullAddress(String value) {
    final commas = ','.allMatches(value).length;
    return commas >= 2 || value.length > 55;
  }

  /// Calle/número (Carrera 38, Cl. 16 #17-11) — no usar como título si hay barrio.
  static bool looksLikeStreetAddress(String value) {
    final v = value.trim().toLowerCase();
    if (v.isEmpty) return false;
    if (RegExp(
      r'^(calle|cl\.?|cll\.?|cra\.?|carrera|kr\.?|kra\.?|avenida|av\.?|diag\.?|diagonal|transversal|tv\.?|#)',
    ).hasMatch(v)) {
      return true;
    }
    if (RegExp(r'##').hasMatch(value)) return true;
    if (RegExp(r'\d{1,5}\s*[-#]').hasMatch(v)) return true;
    return false;
  }

  static bool isPlaceholderPickup(String value) {
    final v = value.trim().toLowerCase();
    return v.isEmpty ||
        v == _pickupPlaceholder.toLowerCase() ||
        v == 'origen no especificado' ||
        v == 'origen' ||
        v == 'sin origen';
  }

  static bool isPlaceholderDestino(String value) {
    final v = value.trim().toLowerCase();
    return v.isEmpty ||
        v == _destinoPlaceholder.toLowerCase() ||
        v == 'destino' ||
        v == 'sin destino' ||
        v == 'a convenir';
  }

  /// Nombre principal de recogida: comercio/zona; barrio; calle.
  static String pickupName(Map<String, dynamic> data) {
    final n = normalizeSolicitudMap(data);
    final barrio = barrioFromPayload(n);
    final name = _pickupNameRaw(n);
    final addr = _pickupAddressRaw(n);

    if (name != null &&
        !isPlaceholderPickup(name) &&
        !looksLikeStreetAddress(name)) {
      return name.trim();
    }

    if (barrio != null && barrio.isNotEmpty) {
      if (name == null ||
          isPlaceholderPickup(name) ||
          looksLikeStreetAddress(name) ||
          _normalizeCompare(name) == _normalizeCompare(addr ?? '')) {
        return barrio;
      }
      if (!_normalizeCompare(name).contains(_normalizeCompare(barrio))) {
        return name;
      }
      return barrio;
    }

    if (name != null && !isPlaceholderPickup(name)) {
      if (!looksLikeStreetAddress(name)) return name;
      final fromAddr = addr != null && !isPlaceholderPickup(addr)
          ? placeNameFromAddress(addr)
          : null;
      if (fromAddr != null &&
          fromAddr.isNotEmpty &&
          !looksLikeStreetAddress(fromAddr)) {
        return fromAddr;
      }
      return name;
    }

    if (addr != null && !isPlaceholderPickup(addr)) {
      return placeNameFromAddress(addr);
    }
    return _pickupPlaceholder;
  }

  /// Título principal en tarjeta del conductor (calle/número, no solo barrio).
  /// Origen listo para mostrar/navegar sin reverse geocode (API o Places).
  static bool tieneOrigenCompletoParaMapa(Map<String, dynamic> data) {
    final n = normalizeSolicitudMap(data);
    final name = _pickupNameRaw(n)?.trim();
    final addr = _pickupAddressRaw(n)?.trim();

    if (addr != null &&
        !isPlaceholderPickup(addr) &&
        addr.length >= 10 &&
        (addr.contains(',') || RegExp(r'\d').hasMatch(addr))) {
      return true;
    }
    if (name != null &&
        !isPlaceholderPickup(name) &&
        looksLikeStreetAddress(name)) {
      return true;
    }
    return false;
  }

  /// Destino listo o viaje sin destino fijo.
  static bool tieneDestinoCompletoParaMapa(Map<String, dynamic> data) {
    final n = normalizeSolicitudMap(data);
    if (!hasDestination(n)) return true;

    final name = _destinationNameRaw(n)?.trim();
    final addr = _destinationAddressRaw(n)?.trim();
    if (addr != null &&
        !isPlaceholderDestino(addr) &&
        addr.length >= 8) {
      return true;
    }
    if (name != null && !isPlaceholderDestino(name)) return true;
    return false;
  }

  /// Nombre de referencia (mall, droguería), no calle ni placeholder.
  static bool tieneNombreLugarRecogida(Map<String, dynamic> data) {
    final name = _pickupNameRaw(normalizeSolicitudMap(data));
    if (name == null || isPlaceholderPickup(name)) return false;
    return !looksLikeStreetAddress(name);
  }

  static bool necesitaEnriquecimientoGeocode(
    Map<String, dynamic> solicitud, {
    bool forzarBarrio = false,
  }) {
    if (!tieneOrigenCompletoParaMapa(solicitud)) return true;
    if (!tieneNombreLugarRecogida(solicitud)) return true;
    if (!tieneDestinoCompletoParaMapa(solicitud)) return true;
    final barrio = barrioFromPayload(normalizeSolicitudMap(solicitud));
    if ((barrio == null || barrio.isEmpty) && forzarBarrio) return true;
    return false;
  }

  /// Título en tarjeta/alerta: punto de referencia primero; calle como respaldo.
  static String pickupTitleForDriver(Map<String, dynamic> data) {
    final n = normalizeSolicitudMap(data);
    final name = _pickupNameRaw(n);
    final addr = _pickupAddressRaw(n);

    if (name != null &&
        !isPlaceholderPickup(name) &&
        !looksLikeStreetAddress(name)) {
      return name.trim();
    }

    if (name != null &&
        !isPlaceholderPickup(name) &&
        looksLikeStreetAddress(name)) {
      return name.trim();
    }

    if (addr != null && !isPlaceholderPickup(addr)) {
      final first = addr.split(',').first.trim();
      if (looksLikeStreetAddress(first) || RegExp(r'\d').hasMatch(first)) {
        return first;
      }
      if (!looksLikeStreetAddress(pickupName(n))) {
        return addr.split(',').take(2).join(', ');
      }
    }

    if (name != null && !isPlaceholderPickup(name)) return name.trim();
    return pickupName(n);
  }

  /// Subtítulo conductor: barrio + dirección si difiere del título.
  static String pickupDetailForDriver(Map<String, dynamic> data) {
    final n = normalizeSolicitudMap(data);
    final title = pickupTitleForDriver(n);
    final barrio = barrioFromPayload(n);
    final addr = _pickupAddressRaw(n);
    final parts = <String>[];
    if (barrio != null &&
        barrio.isNotEmpty &&
        !_normalizeCompare(title).contains(_normalizeCompare(barrio))) {
      parts.add(barrio);
    }
    if (addr != null &&
        !isPlaceholderPickup(addr) &&
        _normalizeCompare(addr) != _normalizeCompare(title) &&
        !_normalizeCompare(addr).startsWith(_normalizeCompare(title))) {
      parts.add(addr.trim());
    }
    return parts.join(' · ');
  }

  static String? pickupCoordinatesHint(Map<String, dynamic> data) {
    final lat = parseCoordinate(data['origen_lat']);
    final lng = parseCoordinate(data['origen_lng']);
    if (lat == null || lng == null) return null;
    if (lat.abs() < 0.0001 && lng.abs() < 0.0001) return null;
    return '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}';
  }

  /// Nombres en MAYÚSCULAS (API) → lectura natural en pantalla.
  static String formatReadablePlaceName(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return s;

    final letters = s.replaceAll(RegExp(r'[^A-Za-zÁÉÍÓÚÑáéíóúñÜü]'), '');
    if (letters.length < 6 || letters != letters.toUpperCase()) return s;

    const keepUpper = {'de', 'del', 'la', 'las', 'el', 'los', 'y', 'e'};
    return s
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .map((word) {
          final lower = word.toLowerCase();
          if (keepUpper.contains(lower)) return lower;
          if (word.length <= 2) return word.toUpperCase();
          return '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}';
        })
        .join(' ');
  }

  /// Título legible al volante: «Recogida en Aguas Vivas».
  static String pickupHeadline(Map<String, dynamic> data) {
    final place = pickupName(data);
    if (isPlaceholderPickup(place)) {
      final barrio = barrioFromPayload(normalizeSolicitudMap(data));
      if (barrio != null && barrio.isNotEmpty) {
        return 'Recogida en ${formatReadablePlaceName(barrio)}';
      }
      return 'Nueva recogida';
    }
    return 'Recogida en ${formatReadablePlaceName(place)}';
  }

  /// Título de destino: «Destino en Hospital Susana López».
  static String destinationHeadline(Map<String, dynamic> data) {
    if (!hasDestination(data)) return '';
    final place = destinationName(data);
    if (isPlaceholderDestino(place)) return 'Destino en mapa';
    return 'Destino en ${formatReadablePlaceName(place)}';
  }

  /// Calle / dirección completa cuando difiere del nombre (subtítulo).
  static String pickupSubtitle(Map<String, dynamic> data) {
    final n = normalizeSolicitudMap(data);
    final name = pickupName(data);
    final addr = _pickupAddressRaw(n);
    if (addr == null || isPlaceholderPickup(addr)) return '';
    if (_normalizeCompare(addr) == _normalizeCompare(name)) return '';
    return addr;
  }

  /// Nombre principal del destino (ej. "Casa Rosada - E.S.E. Popayán").
  static String destinationName(Map<String, dynamic> data) {
    final n = normalizeSolicitudMap(data);
    final name = _destinationNameRaw(n);
    if (name != null && !isPlaceholderDestino(name)) return name;

    final addr = _destinationAddressRaw(n);
    if (addr != null && !isPlaceholderDestino(addr)) {
      return placeNameFromAddress(addr);
    }
    return _destinoPlaceholder;
  }

  static String destinationSubtitle(Map<String, dynamic> data) {
    final n = normalizeSolicitudMap(data);
    final name = destinationName(data);
    final addr = _destinationAddressRaw(n);
    if (addr == null || isPlaceholderDestino(addr)) return '';
    if (_normalizeCompare(addr) == _normalizeCompare(name)) return '';
    return addr;
  }

  static String _normalizeCompare(String value) {
    return value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  }

  /// Compatibilidad: devuelve el nombre principal, no la calle.
  static String pickupAddress(Map<String, dynamic> data) => pickupName(data);

  static String destinationAddress(Map<String, dynamic> data) =>
      destinationName(data);

  static bool hasDestination(Map<String, dynamic> data) {
    final n = normalizeSolicitudMap(data);
    final name = _destinationNameRaw(n);
    if (name != null && !isPlaceholderDestino(name)) return true;

    final addr = _destinationAddressRaw(n);
    if (addr != null && !isPlaceholderDestino(addr)) return true;

    final lat = parseCoordinate(n['destino_lat']);
    final lng = parseCoordinate(n['destino_lng']);
    return lat != null &&
        lng != null &&
        (lat.abs() > 0.0001 || lng.abs() > 0.0001);
  }

  static String notificationTitle(Map<String, dynamic> data) {
    final origen = pickupName(data);
    if (!isPlaceholderPickup(origen)) {
      if (origen.length <= 48) return origen;
      return '${origen.substring(0, 45)}…';
    }
    final barrio = barrioFromPayload(data);
    if (barrio != null) return 'Recogida · $barrio';
    return 'Nueva solicitud';
  }

  static String notificationBody(Map<String, dynamic> data) {
    final origen = pickupName(data);
    final origenSub = pickupSubtitle(data);
    final destino = destinationName(data);
    final destinoSub = destinationSubtitle(data);
    final buffer = StringBuffer();

    if (!isPlaceholderPickup(origen)) {
      buffer.writeln('Recogida: $origen');
      if (origenSub.isNotEmpty) buffer.writeln(origenSub);
    }
    if (hasDestination(data) && !isPlaceholderDestino(destino)) {
      buffer.write('Destino: $destino');
      if (destinoSub.isNotEmpty) buffer.write('\n$destinoSub');
    } else if (hasDestination(data)) {
      buffer.write('Con destino en mapa');
    }

    final text = buffer.toString().trim();
    return text.isEmpty ? 'Toca para ver el servicio' : text;
  }

  static double? parseCoordinate(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString().replaceAll(',', '.'));
  }

  /// Distancia del trayecto (origen → destino), si viene en el payload.
  static String tripDistanceText(Map<String, dynamic> data) {
    final n = normalizeSolicitudMap(data);
    final t = n['distancia_texto']?.toString().trim();
    if (t != null && t.isNotEmpty) return t;
    final km = n['distancia_km'] ?? n['distanciaKm'];
    if (km != null) {
      final v = parseCoordinate(km);
      if (v != null && v > 0) return '${v.toStringAsFixed(1)} km trayecto';
    }
    return '';
  }

  /// Duración estimada del trayecto.
  static String tripDurationText(Map<String, dynamic> data) {
    final n = normalizeSolicitudMap(data);
    final t = n['duracion_texto']?.toString().trim();
    if (t != null && t.isNotEmpty) return t;
    final seg = n['duracion_segundos'] ?? n['duracionSegundos'];
    if (seg != null) {
      final s = int.tryParse(seg.toString());
      if (s != null && s > 0) {
        if (s < 60) return '$s s';
        return '${s ~/ 60} min';
      }
    }
    return '';
  }
}
