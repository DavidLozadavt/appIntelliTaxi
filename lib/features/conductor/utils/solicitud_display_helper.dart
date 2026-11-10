import 'package:intellitaxi/core/geo/place_precision.dart';

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

    // Dirección completa — columnas origenAddress/destinoAddress (+ alias API telefónico).
    m['origen_address'] ??= m['origenAddress'] ??
        m['origin_address'] ??
        m['originAddress'] ??
        m['direccion_origen'] ??
        m['origen_direccion'] ??
        m['origenDireccion'] ??
        m['direccionOrigen'] ??
        m['punto_recogida'] ??
        m['ubicacion_recogida'] ??
        m['recogida'];
    m['destino_address'] ??= m['destinoAddress'] ??
        m['destination_address'] ??
        m['destinationAddress'] ??
        m['direccion_destino'] ??
        m['destino_direccion'] ??
        m['destinoDireccion'] ??
        m['direccionDestino'];

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

    _splitUbicacionTextoEnMapa(m, esOrigen: true);
    _splitUbicacionTextoEnMapa(m, esOrigen: false);

    m['distancia_metros'] ??= m['distanciaMetros'] ?? m['distance_value'];
    m['distancia_texto'] ??= m['distanciaTexto'] ?? m['distance'];
    m['duracion_segundos'] ??= m['duracionSegundos'] ?? m['duration_value'];
    m['duracion_texto'] ??= m['duracionTexto'] ?? m['duration'];

    m['origen_servicio'] ??= m['origenServicio'];
    m['telefono_llamada'] ??=
        m['telefonoLlamada'] ?? m['telefono_llamada_servicio'];
    m['overlay_expira_en'] ??= m['overlayExpiraEn'];

    m['origen_coordenadas_validas'] ??= m['origenCoordenadasValidas'];
    m['aviso_sin_mapa'] ??= m['avisoSinMapa'];
    m['codigo_origen'] ??= m['codigoOrigen'];

    final barrio = barrioFromPayload(m);
    if (barrio != null) {
      m['origen_barrio'] = compactBarrio(barrio);
    }

    return m;
  }

  /// Separa «calle, barrio» cuando el API manda todo en un solo campo.
  static void _splitUbicacionTextoEnMapa(
    Map<String, dynamic> m, {
    required bool esOrigen,
  }) {
    final texto = (esOrigen
            ? m['origen_address'] ?? m['origen']
            : m['destino_address'] ?? m['destino'])
        ?.toString()
        .trim();
    if (texto == null || texto.isEmpty || !texto.contains(',')) return;

    final partes = texto
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    if (partes.isEmpty) return;

    final calle = partes.first;
    final resto = partes.length > 1 ? partes.sublist(1).join(', ') : '';
    final barrioKey = esOrigen ? 'origen_barrio' : 'destino_barrio';
    final addrKey = esOrigen ? 'origen_address' : 'destino_address';
    final barrioActual = m[barrioKey]?.toString().trim() ?? '';
    final addrActual = m[addrKey]?.toString().trim() ?? '';

    if (barrioActual.isEmpty) {
      m[addrKey] = calle;
      if (resto.isNotEmpty) m[barrioKey] = compactBarrio(resto);
    } else if (addrActual.isEmpty || addrActual == texto) {
      m[addrKey] = calle;
    }
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
      'origen_direccion',
      'origenDireccion',
      'direccion_origen',
      'direccionOrigen',
      'punto_recogida',
      'ubicacion_recogida',
      'recogida',
      'origen',
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

  static String? referenciaFromPayload(
    Map<String, dynamic> data, {
    bool destino = false,
  }) {
    return _firstNonEmpty(
      data,
      destino
          ? const [
              'destino_referencia',
              'destination_referencia',
              'referencia_destino',
            ]
          : const [
              'origen_referencia',
              'origin_referencia',
              'referencia',
              'referencia_origen',
            ],
    );
  }

  static String? barrioFromPayload(Map<String, dynamic> data) {
    for (final key in const [
      'origen_barrio',
      'barrio_origen',
      'barrio',
      'neighborhood',
      'zona_origen',
      'zona_recogida',
      'comuna_origen',
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

  /// Compacta el texto de barrio para mostrarlo: toma la parte antes de la
  /// primera coma y normaliza el nombre.
  ///
  /// «Barrio solidaridad, Comuna 7» → «Solidaridad»
  /// «Ciudad jardin» → «Ciudad Jardín»
  static String compactBarrio(String? value) {
    if (value == null || value.trim().isEmpty) return '';
    final parts = value
        .trim()
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '';
    return PlacePrecision.normalizeNeighborhood(parts.first);
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

  /// Quita sufijo geográfico redundante (Popayán, Cauca, Colombia) y bloques `(…)`.
  static String streetLineSinCiudad(String address) {
    var s = address.trim();
    if (s.isEmpty) return s;

    s = s.replaceAll(RegExp(r'\s*\([^)]*\)'), '').trim();

    final parts = s
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    if (parts.length <= 1) return s;

    final kept = <String>[];
    for (var i = 0; i < parts.length; i++) {
      if (i > 0 && _esSufijoGeografico(parts[i])) break;
      kept.add(parts[i]);
    }
    return kept.isEmpty ? parts.first : kept.join(', ');
  }

  static bool _esSufijoGeografico(String part) {
    final p = _normalizarGeoToken(part);
    if (p.isEmpty) return false;
    if (RegExp(r'^colo\b').hasMatch(p)) return true;
    if (p.contains('popayan')) return true;
    if (p == 'cauca' || p.endsWith(' cauca')) return true;
    if (p.contains('colombia')) return true;
    return false;
  }

  static String _normalizarGeoToken(String value) {
    return value
        .toLowerCase()
        .trim()
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u');
  }

  static bool _esSoloGeografico(String line) {
    final parts = line
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    if (parts.isEmpty) return true;
    return parts.every(_esSufijoGeografico);
  }

  /// Subtítulo de calle en tarjetas / panel de viaje (sin Popayán, Cauca, Colombia).
  static String routeAddressSubtitle(String address) {
    final line = streetLineSinCiudad(address);
    if (line.isEmpty || _esSoloGeografico(line)) return '';
    return line;
  }

  /// Dirección lista para el conductor: lugar grande y solo el contexto útil.
  ///
  /// De «Estadio Ciro López, Carrera 4A, Ciudad jardin, Comuna 3, Perímetro
  /// Urbano Popayán, Popayán, Centro, Cauca, RAP Pacífico, 190002, Colombia»
  /// deja «Estadio Ciro López» y «Carrera 4A · Ciudad Jardín · Comuna 3 · Centro».
  static ({String principal, String detalle}) direccionClara(
    Map<String, dynamic> data, {
    required bool destino,
  }) {
    final partes = (_textoMasCompleto(data, destino: destino) ?? '')
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    final utiles = <String>[];
    final contexto = <String>[];
    for (final parte in partes) {
      if (_esRuidoDireccion(parte)) continue;
      final limpio = _presentarParte(parte);
      if (_esCiudadConocida(parte) || _esDepartamento(parte)) {
        if (!_contieneIgual(contexto, limpio)) contexto.add(limpio);
        continue;
      }
      if (!_contieneIgual(utiles, limpio)) utiles.add(limpio);
    }

    var principal = utiles.isEmpty ? '' : utiles.first;
    final detallePartes = utiles.length <= 1
        ? <String>[]
        : _detalleEnOrden(utiles.sublist(1), callePrimero: true);

    final nombre = _nombreLugar(data, destino: destino);
    if (nombre != null &&
        (principal.isEmpty || looksLikeStreetAddress(principal)) &&
        !_contieneIgual([principal, ...detallePartes], nombre)) {
      if (principal.isNotEmpty) detallePartes.insert(0, principal);
      principal = nombre;
    }

    if (principal.isEmpty && contexto.isNotEmpty) {
      principal = contexto.removeAt(0);
    }
    if (principal.isEmpty) {
      principal = destino ? 'Punto de llegada' : 'Punto de recogida';
    }

    final referencia = referenciaFromPayload(data, destino: destino)?.trim();
    if (referencia != null &&
        referencia.isNotEmpty &&
        !_contieneIgual([principal, ...detallePartes], referencia)) {
      detallePartes.add(_presentarParte(referencia));
    }

    final detalle = detallePartes.isNotEmpty
        ? detallePartes.take(4).join(' · ')
        : contexto.take(2).join(', ');
    return (principal: principal, detalle: detalle);
  }

  static List<String> _detalleEnOrden(
    List<String> partes, {
    required bool callePrimero,
  }) {
    if (!callePrimero) return partes;
    final calles = partes.where(looksLikeStreetAddress).toList();
    final resto = partes.where((p) => !looksLikeStreetAddress(p)).toList();
    return [...calles, ...resto];
  }

  static String? _textoMasCompleto(
    Map<String, dynamic> data, {
    required bool destino,
  }) {
    const origen = [
      'origen',
      'origen_address',
      'origenAddress',
      'origin_address',
      'originAddress',
      'direccion_origen',
      'origen_direccion',
      'punto_recogida',
    ];
    const llegada = [
      'destino',
      'destino_address',
      'destinoAddress',
      'destination_address',
      'destinationAddress',
      'direccion_destino',
      'destino_direccion',
    ];
    String? mejor;
    for (final key in destino ? llegada : origen) {
      final valor = data[key]?.toString().trim() ?? '';
      if (valor.isEmpty) continue;
      if (mejor == null || valor.length > mejor.length) mejor = valor;
    }
    return mejor;
  }

  static String? _nombreLugar(
    Map<String, dynamic> data, {
    required bool destino,
  }) {
    final raw = destino
        ? _firstNonEmpty(data, const [
            'destino_name',
            'destinoName',
            'destino_nombre',
            'destination_name',
          ])
        : _firstNonEmpty(data, const [
            'origen_name',
            'origenName',
            'origen_nombre',
            'origin_name',
          ]);
    if (raw == null) return null;
    final nombre = _presentarParte(raw);
    if (nombre.isEmpty || looksLikeStreetAddress(nombre)) return null;
    if (destino ? isPlaceholderDestino(nombre) : isPlaceholderPickup(nombre)) {
      return null;
    }
    return nombre;
  }

  static bool _esRuidoDireccion(String part) {
    final p = _normalizarGeoToken(part);
    if (p.isEmpty) return true;
    if (RegExp(r'^\d{4,8}$').hasMatch(p)) return true;
    if (p == 'colombia' || p.startsWith('colombia ')) return true;
    if (p.contains('perimetro')) return true;
    if (p == 'rap pacifico' || p.startsWith('rap ')) return true;
    return false;
  }

  static bool _esCiudadConocida(String part) {
    return _normalizarGeoToken(part) == 'popayan';
  }

  static bool _esDepartamento(String part) {
    return _normalizarGeoToken(part) == 'cauca';
  }

  static bool _contieneIgual(List<String> partes, String valor) {
    final objetivo = _normalizeCompare(valor);
    if (objetivo.isEmpty) return false;
    return partes.any((p) => _normalizeCompare(p) == objetivo);
  }

  static String _presentarParte(String part) {
    final t = part.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (t.isEmpty) return t;
    final letters = t.replaceAll(RegExp(r'[^A-Za-zÁÉÍÓÚáéíóúÑñÜü]'), '');
    if (letters.length < 2) return t;
    final uniforme =
        letters == letters.toLowerCase() || letters == letters.toUpperCase();
    if (!uniforme) return t;
    const menores = {'de', 'del', 'la', 'las', 'el', 'los', 'y', 'e'};
    return t
        .split(' ')
        .map((word) {
          final lower = word.toLowerCase();
          if (menores.contains(lower)) return lower;
          if (word.isEmpty) return word;
          return '${lower[0].toUpperCase()}${lower.substring(1)}';
        })
        .join(' ');
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
        v == 'sin origen' ||
        v == 'mi ubicación' ||
        v == 'mi ubicacion' ||
        v == 'ubicación actual' ||
        v == 'ubicacion actual' ||
        v == 'nueva recogida' ||
        v == 'punto de recogida' ||
        v == 'nueva solicitud';
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
    final n = normalizeSolicitudMap(solicitud);
    if (referenciaFromPayload(n) != null ||
        (barrioFromPayload(n) != null &&
            n['origen_barrio_id'] != null)) {
      return false;
    }
    if (!tieneOrigenCompletoParaMapa(solicitud)) return true;
    if (!tieneNombreLugarRecogida(solicitud)) return true;
    if (!tieneDestinoCompletoParaMapa(solicitud)) return true;
    final barrio = barrioFromPayload(normalizeSolicitudMap(solicitud));
    if ((barrio == null || barrio.isEmpty) && forzarBarrio) return true;
    // La dirección y el barrio no coinciden: puede ser una calle que Google
    // inventó ("Cl 15 # 37-222" sin ciudad, en un punto sin calle mapeada).
    // Hay que verificarla contra las coordenadas antes de mostrarla.
    if (barrio != null && barrio.isNotEmpty) {
      if (!direccionCoincideConBarrio(solicitud, esOrigen: true)) return true;
      if (!direccionCoincideConBarrio(solicitud, esOrigen: false)) return true;
    }
    return false;
  }

  /// ¿La dirección del payload concuerda con el barrio que trae?
  ///
  /// Si la dirección menciona el barrio ("Cra 5 #12-34, Las Palmas, ...") es
  /// consistente. Si no lo menciona puede ser una calle sintetizada por
  /// Google en zonas sin cobertura, y hay que verificarla contra el punto.
  static bool direccionCoincideConBarrio(
    Map<String, dynamic> data, {
    required bool esOrigen,
  }) {
    final n = normalizeSolicitudMap(data);
    final barrio = barrioFromPayload(n);
    if (barrio == null || barrio.trim().isEmpty) return true;

    final direccion =
        (esOrigen ? _pickupAddressRaw(n) : _destinationAddressRaw(n))
            ?.trim() ??
        '';
    if (direccion.isEmpty) return true;

    return direccion.toLowerCase().contains(barrio.trim().toLowerCase());
  }

  /// Título al volante: barrio (nunca una calle inventada por el geocoder).
  static String pickupTitleForDriver(Map<String, dynamic> data) {
    final n = normalizeSolicitudMap(data);
    final barrio = barrioFromPayload(n);
    if (barrio != null && barrio.isNotEmpty) return barrio;

    final name = _pickupNameRaw(n);
    if (name != null &&
        !isPlaceholderPickup(name) &&
        !looksLikeStreetAddress(name)) {
      return name.trim();
    }

    return 'Barrio por confirmar';
  }

  /// Subtítulo conductor: referencia del cliente. Nunca una calle autogenerada.
  static String pickupDetailForDriver(Map<String, dynamic> data) {
    final n = normalizeSolicitudMap(data);
    final referencia = referenciaFromPayload(n)?.trim();
    if (referencia != null && referencia.isNotEmpty) return referencia;
    return '';
  }

  static const double _epsilonCoord = 1e-6;

  static const String avisoSinMapaPorDefecto =
      'No hay punto en el mapa. Confirma la dirección con el pasajero o el operador.';

  /// Origen con pin / navegación GPS (`origen_coordenadas_validas` o lat/lng).
  static bool origenTieneMapa(Map<String, dynamic> data) {
    final n = normalizeSolicitudMap(data);
    if (n.containsKey('origen_coordenadas_validas')) {
      return n['origen_coordenadas_validas'] == true;
    }
    final lat = parseCoordinate(n['origen_lat']);
    final lng = parseCoordinate(n['origen_lng']);
    if (lat == null || lng == null) return false;
    return lat.abs() > _epsilonCoord || lng.abs() > _epsilonCoord;
  }

  /// Mensaje informativo cuando el backend marca origen sin mapa.
  static String? avisoSinMapa(Map<String, dynamic> data) {
    final n = normalizeSolicitudMap(data);
    if (origenTieneMapa(n)) return null;
    final raw = n['aviso_sin_mapa']?.toString().trim();
    if (raw != null && raw.isNotEmpty) return raw;
    return avisoSinMapaPorDefecto;
  }

  /// GPS de recogida usable en mapa / geocoding inverso.
  static bool tieneCoordenadasRecogidaValidas(Map<String, dynamic> data) =>
      origenTieneMapa(data);

  static String? pickupCoordinatesHint(Map<String, dynamic> data) {
    if (!tieneCoordenadasRecogidaValidas(data)) return null;
    final lat = parseCoordinate(data['origen_lat'])!;
    final lng = parseCoordinate(data['origen_lng'])!;
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

  /// Solo el nombre del lugar (tarjeta compacta: ya dice RECOGIDA / DESTINO).
  static String pickupPlaceLabel(Map<String, dynamic> data) {
    final n = normalizeSolicitudMap(data);
    final title = pickupTitleForDriver(n);
    if (!isPlaceholderPickup(title) &&
        title.trim().isNotEmpty &&
        title != _pickupPlaceholder) {
      return formatReadablePlaceName(title);
    }
    final addr = _pickupAddressRaw(n);
    if (addr != null && !isPlaceholderPickup(addr)) {
      return formatReadablePlaceName(placeNameFromAddress(addr));
    }
    final barrio = barrioFromPayload(n);
    if (barrio != null && barrio.isNotEmpty) {
      return formatReadablePlaceName(barrio);
    }
    return 'Punto de recogida';
  }

  static String destinationPlaceLabel(Map<String, dynamic> data) {
    if (!hasDestination(data)) return '';
    final place = destinationName(data);
    if (isPlaceholderDestino(place)) return 'Destino en mapa';
    return formatReadablePlaceName(place);
  }

  /// Título legible al volante (nombre del lugar, sin prefijo).
  static String pickupHeadline(Map<String, dynamic> data) {
    final tituloConductor = pickupTitleForDriver(data);
    if (!isPlaceholderPickup(tituloConductor) &&
        tituloConductor.trim().isNotEmpty &&
        tituloConductor != _pickupPlaceholder) {
      return formatReadablePlaceName(tituloConductor);
    }

    final place = pickupName(data);
    if (isPlaceholderPickup(place) || place == _pickupPlaceholder) {
      final barrio = barrioFromPayload(normalizeSolicitudMap(data));
      if (barrio != null && barrio.isNotEmpty) {
        return formatReadablePlaceName(barrio);
      }
      final hint = pickupCoordinatesHint(data);
      if (hint != null) return hint;
      return 'Nueva recogida';
    }
    return formatReadablePlaceName(place);
  }

  /// Título de destino (nombre del lugar, sin prefijo).
  static String destinationHeadline(Map<String, dynamic> data) {
    if (!hasDestination(data)) return '';
    final n = normalizeSolicitudMap(data);
    final barrio = _firstNonEmpty(n, const [
      'destino_barrio',
      'barrio_destino',
      'destination_barrio',
    ]);
    if (barrio != null && barrio.isNotEmpty) {
      return formatReadablePlaceName(compactBarrio(barrio));
    }
    final place = destinationName(data);
    if (isPlaceholderDestino(place) || looksLikeStreetAddress(place)) {
      return 'Barrio por confirmar';
    }
    return formatReadablePlaceName(place);
  }

  /// Barrio y calle de recogida (todos los alias: `origen`, `origen_address`, etc.).
  static ({String barrio, String direccion}) barrioYDireccionRecogida(
    Map<String, dynamic> data,
  ) {
    final n = normalizeSolicitudMap(data);
    var barrio = '';
    final barrioRaw = barrioFromPayload(n);
    if (barrioRaw != null && barrioRaw.isNotEmpty) {
      barrio = formatReadablePlaceName(barrioRaw);
    }

    var direccion = '';
    final raw = _pickupAddressRaw(n);
    if (raw != null && !isPlaceholderPickup(raw)) {
      if (looksLikeStreetAddress(raw)) {
        final line = routeAddressSubtitle(raw);
        direccion = formatReadablePlaceName(
          line.isNotEmpty ? line : raw.split(',').first.trim(),
        );
      } else if (barrio.isEmpty) {
        barrio = formatReadablePlaceName(placeNameFromAddress(raw));
      } else {
        final line = routeAddressSubtitle(raw);
        if (line.isNotEmpty &&
            _normalizeCompare(line) != _normalizeCompare(barrio)) {
          direccion = formatReadablePlaceName(line);
        }
      }
    }

    if (direccion.isEmpty) {
      final titulo = pickupTitleForDriver(n);
      if (titulo.isNotEmpty &&
          !isPlaceholderPickup(titulo) &&
          looksLikeStreetAddress(titulo)) {
        direccion = formatReadablePlaceName(titulo);
      } else if (barrio.isEmpty &&
          titulo.isNotEmpty &&
          !isPlaceholderPickup(titulo)) {
        barrio = formatReadablePlaceName(titulo);
      }
    }

    return (barrio: barrio.trim(), direccion: direccion.trim());
  }

  /// Calle / dirección completa cuando difiere del nombre (subtítulo).
  static String pickupSubtitle(Map<String, dynamic> data) {
    return pickupDetailForDriver(data);
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
    final referencia = referenciaFromPayload(n, destino: true)?.trim();
    if (referencia != null && referencia.isNotEmpty) return referencia;
    final barrio = _firstNonEmpty(n, const [
      'destino_barrio',
      'barrio_destino',
      'destination_barrio',
    ]);
    if (barrio != null && barrio.isNotEmpty) return compactBarrio(barrio);
    return '';
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
    final titulo = formatReadablePlaceName(pickupTitleForDriver(data));
    if (!isPlaceholderPickup(titulo) && titulo.trim().isNotEmpty) {
      if (titulo.length <= 48) return titulo;
      return '${titulo.substring(0, 45)}…';
    }
    final barrio = barrioFromPayload(data);
    if (barrio != null) return 'Recogida · $barrio';
    return 'Nueva solicitud';
  }

  static String notificationBody(Map<String, dynamic> data) {
    final titulo = formatReadablePlaceName(pickupTitleForDriver(data));
    final detalle = pickupDetailForDriver(data);
    final destino = formatReadablePlaceName(destinationName(data));
    final destinoSub = destinationSubtitle(data);
    final buffer = StringBuffer();

    if (!isPlaceholderPickup(titulo) && titulo.trim().isNotEmpty) {
      buffer.writeln('Recogida: $titulo');
      if (detalle.isNotEmpty &&
          !_normalizeCompare(detalle).contains(_normalizeCompare(titulo))) {
        buffer.writeln(detalle);
      }
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
