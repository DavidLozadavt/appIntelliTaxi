import 'package:intellitaxi/config/app_config.dart';
import 'package:intellitaxi/core/utils/json_payload_helper.dart';
import 'package:intellitaxi/features/conductor/conductor_constants.dart';
import 'package:intellitaxi/features/conductor/utils/conductor_servicio_pasajero_helper.dart';
import 'package:intellitaxi/features/conductor/utils/solicitud_display_helper.dart';
import 'package:intellitaxi/features/taxi/utils/servicio_espera_timer.dart';

/// Normalización de solicitudes recibidas por Pusher / sync API.
class ConductorSolicitudPayloadHelper {
  ConductorSolicitudPayloadHelper._();

  static Map<String, dynamic> parsePayload(dynamic data) =>
      JsonPayloadHelper.parseAndMerge(data);

  static String? obtenerSolicitudId(Map<String, dynamic> solicitud) {
    final rawId = solicitud['_local_id'] ??
        solicitud['solicitud_id'] ??
        solicitud['solicitudId'] ??
        solicitud['servicio_id'] ??
        solicitud['servicioId'] ??
        solicitud['id'] ??
        solicitud['ride_id'] ??
        solicitud['request_id'] ??
        solicitud['temp_id'];
    return rawId?.toString();
  }

  static String generarSolicitudTemporalId() =>
      'temp_${DateTime.now().microsecondsSinceEpoch}';

  /// `overlay_expira_en` del API (tarjeta overlay en mapa).
  static DateTime? resolverOverlayExpiraEn(Map<String, dynamic> solicitud) {
    for (final key in const [
      'overlay_expira_en',
      'overlayExpiraEn',
    ]) {
      final parsed = ServicioEsperaTimer.parseExpiraEn(solicitud[key]);
      if (parsed != null) return parsed;
    }
    return null;
  }

  static DateTime? _expiraColaDesdePayloadApi(Map<String, dynamic> solicitud) {
    for (final key in const [
      'cola_expira_en',
      'colaExpiraEn',
      'servicio_expira_en',
      'servicioExpiraEn',
    ]) {
      final parsed = ServicioEsperaTimer.parseExpiraEn(solicitud[key]);
      if (parsed != null) return parsed;
    }

    final seg = ServicioEsperaTimer.segundosCola(solicitud);
    if (seg > 0) {
      return DateTime.now().add(Duration(seconds: seg));
    }
    return null;
  }

  /// Instante de expiración de cola (`cola_expira_en` del API o ancla local).
  static DateTime? resolverExpiraEnCola(Map<String, dynamic> solicitud) {
    final anclado = solicitud['_cola_expira_en'];
    if (anclado != null) {
      final dt = DateTime.tryParse(anclado.toString());
      if (dt != null) return dt;
    }
    return _expiraColaDesdePayloadApi(solicitud);
  }

  /// Fija `overlay_expira_en` con mínimo de ventana en «Llegando» (p. ej. tras exclusiva).
  static void anclarOverlayExpiraEn(
    Map<String, dynamic> destino, {
    Map<String, dynamic>? anterior,
    int minSegundosRestantes = kOportunidadConductorSegundos,
  }) {
    final minimo =
        DateTime.now().add(Duration(seconds: minSegundosRestantes));
    DateTime? mejor;

    for (final raw in [
      destino['_overlay_expira_en_ancla'],
      anterior?['_overlay_expira_en_ancla'],
      destino['overlay_expira_en'],
      destino['overlayExpiraEn'],
      anterior?['overlay_expira_en'],
      anterior?['overlayExpiraEn'],
    ]) {
      final parsed = ServicioEsperaTimer.parseExpiraEn(raw);
      if (parsed != null && (mejor == null || parsed.isAfter(mejor))) {
        mejor = parsed;
      }
    }

    final expira = mejor != null && mejor.isAfter(minimo) ? mejor : minimo;
    final iso = expira.toIso8601String();
    destino['overlay_expira_en'] = iso;
    destino['overlayExpiraEn'] = iso;
    destino['_overlay_expira_en_ancla'] = iso;
  }

  /// Fija `_cola_expira_en` para cuenta regresiva fluida (no saltos en cada sync).
  static void anclarExpiracionCola(
    Map<String, dynamic> destino, {
    Map<String, dynamic>? anterior,
  }) {
    for (final raw in [
      destino['_cola_expira_en'],
      anterior?['_cola_expira_en'],
    ]) {
      if (raw == null) continue;
      final prev = DateTime.tryParse(raw.toString());
      if (prev != null && prev.isAfter(DateTime.now())) {
        destino['_cola_expira_en'] = prev.toIso8601String();
        return;
      }
    }

    final expira = _expiraColaDesdePayloadApi(destino);
    if (expira != null) {
      destino['_cola_expira_en'] = expira.toIso8601String();
    }
  }

  /// Cuenta regresiva de cola (~10 min) anclada a `cola_expira_en`.
  static int? segundosRestantesCola(Map<String, dynamic> solicitud) {
    final expira = resolverExpiraEnCola(solicitud);
    if (expira != null) {
      final restantes = expira.difference(DateTime.now()).inSeconds;
      return restantes > 0 ? restantes : 0;
    }
    final seg = ServicioEsperaTimer.segundosCola(solicitud);
    return seg > 0 ? seg : 0;
  }

  static bool tieneExpiracionColaActiva(Map<String, dynamic> solicitud) {
    final seg = segundosRestantesCola(solicitud);
    return seg != null && seg > 0;
  }

  /// El API indica ventana activa en pestaña «Llegando».
  static bool overlayVigenteEnServidor(Map<String, dynamic> solicitud) {
    final expira = resolverOverlayExpiraEn(solicitud);
    return expira != null && expira.isAfter(DateTime.now());
  }

  /// Segundos hasta que expire el overlay (mín. 1 s).
  static int segundosRestantesOverlay(Map<String, dynamic> solicitud) {
    final expira = resolverOverlayExpiraEn(solicitud);
    if (expira != null) {
      final s = expira.difference(DateTime.now()).inSeconds;
      if (s > 0) return s;
    }
    return resolverTtlSegundos(solicitud);
  }

  /// TTL del overlay «Llegando» en mapa (no confundir con oferta exclusiva ni cola).
  static int resolverTtlSegundos(Map<String, dynamic> solicitud) {
    final expiraEn = resolverOverlayExpiraEn(solicitud);
    if (expiraEn != null) {
      final rest = expiraEn.difference(DateTime.now()).inSeconds;
      if (rest > 0) return rest;
    }
    final ttlRaw = solicitud['ttl_segundos'] ?? solicitud['ttl'];
    final ttl = int.tryParse(ttlRaw?.toString() ?? '');
    if (ttl != null && ttl > 0) return ttl;
    return kOportunidadConductorSegundos;
  }

  static String? resolverFotoPasajero(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final foto = value.trim();
    if (foto.startsWith('http://') || foto.startsWith('https://')) return foto;

    final base = Uri.parse(AppConfig.baseUrl);
    final origin =
        '${base.scheme}://${base.host}${base.hasPort ? ':${base.port}' : ''}';
    if (foto.startsWith('/')) return '$origin$foto';
    return '$origin/$foto';
  }

  static Map<String, dynamic> normalizarSolicitud(
    Map<String, dynamic> raw, {
    bool isDirectOffer = false,
  }) {
    final base = isDirectOffer
        ? normalizarOfertaDirecta(raw)
        : SolicitudDisplayHelper.normalizeSolicitudMap(raw);
    final barrio = SolicitudDisplayHelper.barrioFromPayload(base);
    if (barrio != null) {
      base['origen_barrio'] = barrio;
    }
    return base;
  }

  static Map<String, dynamic> normalizarOfertaDirecta(Map<String, dynamic> raw) {
    final merged = SolicitudDisplayHelper.normalizeSolicitudMap(raw);
    final solicitudId = merged['solicitud_id'] ?? merged['id'];
    return {
      ...merged,
      'solicitud_id': solicitudId,
      'servicio_id': solicitudId,
      'id': solicitudId,
      'pasajero_id': merged['pasajero_id'],
      'pasajero_nombre': merged['pasajero_nombre'] ??
          ConductorServicioPasajeroHelper.nombre(merged),
      'pasajero_telefono': merged['pasajero_telefono'] ??
          ConductorServicioPasajeroHelper.telefono(merged),
      'telefonoLlamada': merged['telefonoLlamada'] ??
          merged['telefono_llamada'] ??
          ConductorServicioPasajeroHelper.telefonoLlamada(merged),
      'pasajero_foto': resolverFotoPasajero(merged['pasajero_foto']?.toString()),
      'origen': SolicitudDisplayHelper.pickupName(merged),
      'destino': SolicitudDisplayHelper.destinationName(merged),
      'origen_name': merged['origen_name'],
      'origen_address': merged['origen_address'],
      'destino_name': merged['destino_name'],
      'destino_address': merged['destino_address'],
      'origen_barrio': merged['origen_barrio'] ?? merged['barrio'],
      'origen_lat': merged['origen_lat'],
      'origen_lng': merged['origen_lng'],
      'origen_coordenadas_validas': merged['origen_coordenadas_validas'],
      'aviso_sin_mapa': merged['aviso_sin_mapa'],
      'codigo_origen': merged['codigo_origen'],
      'aceptable': merged['aceptable'],
      'destino_lat': merged['destino_lat'],
      'destino_lng': merged['destino_lng'],
      'precio_ofertado':
          merged['precio_ofrecido'] ?? merged['precio_ofertado'] ?? 0,
      'distancia': merged['distancia'],
      'duracion_estimada': merged['duracion_estimada'],
      'mensaje': merged['mensaje'],
      'status': 'oferta_directa',
      'clase_vehiculo': 'taxi',
      'timestamp': merged['timestamp'] ?? DateTime.now().toIso8601String(),
      'ttl_segundos': merged['ttl_segundos'] ?? kOportunidadConductorSegundos,
    };
  }

  static bool hasMeaningfulPlaceName(String? value) {
    if (value == null || value.trim().isEmpty) return false;
    if (SolicitudDisplayHelper.isPlaceholderPickup(value)) return false;
    if (SolicitudDisplayHelper.isPlaceholderDestino(value)) return false;
    return !SolicitudDisplayHelper.looksLikeStreetAddress(value);
  }

  static bool hasMeaningfulAddress(String? value) {
    if (value == null || value.trim().isEmpty) return false;
    if (SolicitudDisplayHelper.isPlaceholderPickup(value)) return false;
    if (SolicitudDisplayHelper.isPlaceholderDestino(value)) return false;
    return true;
  }

  static String? servicioIdFromTomadaPayload(Map<String, dynamic> raw) {
    final servicioId = raw['servicio_id'] ??
        raw['servicioId'] ??
        raw['solicitud_id'] ??
        raw['solicitudId'] ??
        raw['id'];
    return servicioId?.toString();
  }

  /// Conductor que tomó el servicio (evento `solicitud.tomada` / `oferta.cerrada`).
  static int? conductorIdFromTomadaPayload(Map<String, dynamic> raw) {
    for (final key in const [
      'conductor_id',
      'conductorId',
      'id_conductor',
      'idConductor',
      'persona_id',
      'personaId',
      'id_persona',
      'idPersona',
    ]) {
      final v = raw[key];
      if (v == null) continue;
      final n = int.tryParse(v.toString());
      if (n != null && n > 0) return n;
    }
    final conductor = raw['conductor'];
    if (conductor is Map) {
      final id = conductor['id'] ?? conductor['persona_id'];
      final n = int.tryParse(id?.toString() ?? '');
      if (n != null && n > 0) return n;
    }
    final servicio = raw['servicio'];
    if (servicio is Map) {
      for (final key in const ['idConductor', 'id_conductor', 'conductor_id']) {
        final n = int.tryParse(servicio[key]?.toString() ?? '');
        if (n != null && n > 0) return n;
      }
    }
    return null;
  }

  static String? servicioIdFromAlertaPayload(Map<String, dynamic> raw) =>
      servicioIdFromTomadaPayload(raw) ?? obtenerSolicitudId(raw);
}
