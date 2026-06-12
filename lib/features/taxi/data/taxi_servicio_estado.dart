/// Estado rápido del conductor según `GET /taxi/conductor/estado-actual`.
class TaxiConductorEstadoActual {
  final bool disponible;
  final bool enServicio;
  final bool enDescanso;
  final bool turnoActivo;
  final bool recibeServicios;
  final bool visibleEnMapa;
  final int? servicioActivoId;
  final int? idEstado;

  const TaxiConductorEstadoActual({
    required this.disponible,
    required this.enServicio,
    this.enDescanso = false,
    this.turnoActivo = false,
    this.recibeServicios = true,
    this.visibleEnMapa = true,
    this.servicioActivoId,
    this.idEstado,
  });

  factory TaxiConductorEstadoActual.fromJson(Map<String, dynamic> json) {
    final payload = _unwrapPayload(json);
    return TaxiConductorEstadoActual(
      disponible: payload['disponible'] == true,
      enServicio: payload['en_servicio'] == true,
      enDescanso: payload['en_descanso'] == true,
      turnoActivo: payload['turno_activo'] == true,
      recibeServicios: payload['recibe_servicios'] != false,
      visibleEnMapa: payload['visible_en_mapa'] != false,
      servicioActivoId: _parseInt(
        payload['servicio_activo_id'] ?? payload['servicioActivoId'],
      ),
      idEstado: _parseInt(payload['id_estado'] ?? payload['idEstado']),
    );
  }

  static Map<String, dynamic> _unwrapPayload(Map<String, dynamic> json) {
    final nested = json['data'];
    if (nested is Map<String, dynamic>) {
      return {...json, ...nested};
    }
    if (nested is Map) {
      return {...json, ...Map<String, dynamic>.from(nested)};
    }
    return json;
  }

  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    return int.tryParse(value.toString());
  }
}

/// Resultado de `GET/POST /taxi/conductor/modo-descanso`.
class TaxiModoDescansoEstado {
  final bool enDescanso;
  final bool turnoActivo;
  final String? estadoMapa;
  final bool recibeServicios;
  final bool visibleEnMapa;
  final String? mensaje;

  const TaxiModoDescansoEstado({
    required this.enDescanso,
    required this.turnoActivo,
    this.estadoMapa,
    this.recibeServicios = true,
    this.visibleEnMapa = true,
    this.mensaje,
  });

  factory TaxiModoDescansoEstado.fromJson(Map<String, dynamic> json) {
    final payload = TaxiConductorEstadoActual._unwrapPayload(json);
    return TaxiModoDescansoEstado(
      enDescanso: payload['en_descanso'] == true,
      turnoActivo: payload['turno_activo'] == true,
      estadoMapa: payload['estado_mapa']?.toString(),
      recibeServicios: payload['recibe_servicios'] != false,
      visibleEnMapa: payload['visible_en_mapa'] != false,
      mensaje: payload['mensaje']?.toString(),
    );
  }
}

/// Resultado de `GET /taxi/solicitudes-publicadas-conductor`.
class TaxiSolicitudesPublicadasResult {
  final bool enServicio;
  final bool enDescanso;
  final int? servicioActivoId;
  final List<Map<String, dynamic>> solicitudes;

  const TaxiSolicitudesPublicadasResult({
    required this.enServicio,
    this.enDescanso = false,
    this.servicioActivoId,
    required this.solicitudes,
  });
}

/// Meta de tiempos (`companyAssignmentSettings` vía `GET /solicitudes-pendientes`).
class CompanyAssignmentTiming {
  final int? pollIntervalSegundos;
  final int? graciaSegundos;
  final int? servidorTimestamp;
  final int? overlayTtlSegundos;
  final double? queueMaxMinutes;
  final double? queueAbiertaMaxMinutes;
  final double? ventanaListaMinutos;
  final int? ofertaExclusivaSegundos;
  final int? ofertaMaxIntentos;
  final bool? broadcastReboteFcm;

  const CompanyAssignmentTiming({
    this.pollIntervalSegundos,
    this.graciaSegundos,
    this.servidorTimestamp,
    this.overlayTtlSegundos,
    this.queueMaxMinutes,
    this.queueAbiertaMaxMinutes,
    this.ventanaListaMinutos,
    this.ofertaExclusivaSegundos,
    this.ofertaMaxIntentos,
    this.broadcastReboteFcm,
  });

  factory CompanyAssignmentTiming.fromResponse(Map data) {
    final nested = data['timing'];
    final timing = nested is Map
        ? Map<String, dynamic>.from(nested)
        : <String, dynamic>{};

    int? pickInt(String snake, [String? camel]) {
      final raw = timing[snake] ?? timing[camel ?? ''] ?? data[snake];
      if (raw == null) return null;
      if (raw is int) return raw > 0 ? raw : null;
      return int.tryParse(raw.toString());
    }

    double? pickDouble(String snake) {
      final raw = timing[snake] ?? data[snake];
      if (raw == null) return null;
      if (raw is num) return raw.toDouble();
      return double.tryParse(raw.toString());
    }

    bool? pickBool(String snake) {
      final raw = timing[snake] ?? data[snake];
      if (raw == null) return null;
      if (raw is bool) return raw;
      final s = raw.toString().toLowerCase();
      if (s == 'true' || s == '1') return true;
      if (s == 'false' || s == '0') return false;
      return null;
    }

    return CompanyAssignmentTiming(
      pollIntervalSegundos: pickInt('poll_interval_segundos', 'pollIntervalSegundos'),
      graciaSegundos: pickInt('gracia_segundos', 'graciaSegundos'),
      servidorTimestamp: pickInt('servidor_timestamp', 'servidorTimestamp'),
      overlayTtlSegundos: pickInt('overlay_ttl_segundos', 'overlayTtlSegundos'),
      queueMaxMinutes: pickDouble('queue_max_minutes'),
      queueAbiertaMaxMinutes: pickDouble('queue_abierta_max_minutes'),
      ventanaListaMinutos: pickDouble('ventana_lista_minutos'),
      ofertaExclusivaSegundos: pickInt('oferta_exclusiva_segundos'),
      ofertaMaxIntentos: pickInt('oferta_max_intentos'),
      broadcastReboteFcm: pickBool('broadcast_rebote_fcm'),
    );
  }
}

/// Resultado de `GET /taxi/solicitudes-pendientes`.
class TaxiSolicitudesPendientesResult {
  final bool enServicio;
  final bool enDescanso;
  final int? idEmpresa;
  final int? servicioActivoId;
  final int total;
  final List<Map<String, dynamic>> pendientes;
  /// Tab Llegando — fuente principal (spec 2026-06-12 b).
  final List<Map<String, dynamic>> pendientesLlegando;
  /// Tab Espera — fuente principal (spec 2026-06-12 b).
  final List<Map<String, dynamic>> pendientesEspera;
  final int? totalLlegando;
  final int? totalEspera;
  final String? actualizadoEn;
  /// `TAXI_PENDIENTES_MAX_EDAD_MINUTOS` en servidor (solo informativo en UI).
  final int? pendientesMaxEdadMinutos;
  /// `NEAREST_OFFER_THEN_BROADCAST` → true; `BROADCAST_NEARBY_DRIVERS` → false (filtro radio).
  /// No implica tab Espera vacía: broadcast fase 2 usa `pendientes_espera`.
  final bool listaGlobal;
  /// Método de asignación de la empresa (`companyAssignmentSettings`).
  final String? assignmentMethod;
  /// Radio efectivo en km (BD): `driver_search_radius_km` o alias `radio_km`.
  final double? driverSearchRadiusKm;
  /// Meta cola (`companyAssignmentSettings` vía API).
  final double? queueMaxMinutes;
  final double? queueAbiertaMaxMinutes;
  final double? ventanaListaMinutos;
  /// `companyAssignmentSettings.oferta_exclusiva_segundos`
  final int? ofertaExclusivaSegundos;
  /// `companyAssignmentSettings.oferta_max_intentos`
  final int? ofertaMaxIntentos;
  /// Bloque `timing` + campos raíz de `companyAssignmentSettings`.
  final CompanyAssignmentTiming? timing;
  final bool sinUbicacion;
  final bool desdeCache;

  const TaxiSolicitudesPendientesResult({
    required this.enServicio,
    this.enDescanso = false,
    this.idEmpresa,
    this.servicioActivoId,
    required this.total,
    required this.pendientes,
    this.pendientesLlegando = const [],
    this.pendientesEspera = const [],
    this.totalLlegando,
    this.totalEspera,
    this.actualizadoEn,
    this.pendientesMaxEdadMinutos,
    this.listaGlobal = true,
    this.assignmentMethod,
    this.driverSearchRadiusKm,
    this.queueMaxMinutes,
    this.queueAbiertaMaxMinutes,
    this.ventanaListaMinutos,
    this.ofertaExclusivaSegundos,
    this.ofertaMaxIntentos,
    this.timing,
    this.sinUbicacion = false,
    this.desdeCache = false,
  });

  /// Alias de [driverSearchRadiusKm] para compatibilidad.
  double? get radioKm => driverSearchRadiusKm;

  factory TaxiSolicitudesPendientesResult.empty({
    bool enServicio = false,
    bool enDescanso = false,
  }) {
    return TaxiSolicitudesPendientesResult(
      enServicio: enServicio,
      enDescanso: enDescanso,
      total: 0,
      pendientes: const [],
      pendientesLlegando: const [],
      pendientesEspera: const [],
      totalLlegando: 0,
      totalEspera: 0,
    );
  }
}

/// Resultado de `GET /taxi/conductor/solicitudes-rechazadas`.
class TaxiSolicitudesRechazadasResult {
  final int total;
  final Set<int> servicioIds;

  const TaxiSolicitudesRechazadasResult({
    required this.total,
    required this.servicioIds,
  });

  factory TaxiSolicitudesRechazadasResult.empty() {
    return const TaxiSolicitudesRechazadasResult(total: 0, servicioIds: {});
  }
}
