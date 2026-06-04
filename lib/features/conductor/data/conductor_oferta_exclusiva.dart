import 'package:intellitaxi/core/utils/json_payload_helper.dart';
import 'package:intellitaxi/features/conductor/utils/conductor_solicitud_payload_helper.dart';
import 'package:intellitaxi/features/conductor/utils/conductor_socket_payload_router.dart';
import 'package:intellitaxi/features/taxi/utils/servicio_espera_timer.dart';

/// Oferta exclusiva inDrive (`oferta.servicio.exclusiva` / GET oferta-activa).
class ConductorOfertaExclusiva {
  ConductorOfertaExclusiva({
    required this.servicioId,
    required this.solicitudId,
    required this.raw,
    this.faseOferta = 'exclusiva',
    this.segundosRestantes,
    this.ttlSegundos,
    this.intento,
    this.maxIntentos,
    this.distanciaDesdeMiKm,
    this.origen,
    this.destino,
    this.precioEstimado,
    this.origenLat,
    this.origenLng,
    this.expiraEn,
  });

  final int servicioId;
  final String solicitudId;
  final Map<String, dynamic> raw;
  final String faseOferta;
  final int? segundosRestantes;
  final int? ttlSegundos;
  final int? intento;
  final int? maxIntentos;
  final double? distanciaDesdeMiKm;
  final String? origen;
  final String? destino;
  final double? precioEstimado;
  final double? origenLat;
  final double? origenLng;
  final String? expiraEn;

  bool get esDirecta => faseOferta.toLowerCase() == 'directa';

  bool get esExclusiva =>
      faseOferta.toLowerCase() == 'exclusiva' ||
      raw['oferta_exclusiva'] == true;

  Map<String, dynamic> toSolicitudMap() {
    final m = Map<String, dynamic>.from(raw);
    m['servicio_id'] = servicioId;
    m['solicitud_id'] = servicioId;
    m['id'] = servicioId;
    m['fase_oferta'] = faseOferta;
    m['oferta_exclusiva'] = esExclusiva;
    if (segundosRestantes != null) {
      m['segundos_restantes'] = segundosRestantes;
      m['ttl_segundos'] = ttlSegundos ?? segundosRestantes;
    }
    _mergeUbicacionEnMapa(m, campoOrigen: origen, campoDestino: destino);
    for (final key in const [
      'origen_barrio',
      'barrio_origen',
      'barrio',
      'origen_address',
      'origen_direccion',
      'direccion_origen',
      'origen_nombre',
      'destino_barrio',
      'barrio_destino',
      'destino_address',
      'destino_direccion',
      'direccion_destino',
      'destino_nombre',
      'origen_servicio',
      'origenServicio',
      'telefono_llamada',
      'telefonoLlamada',
      'telefono_llamada_servicio',
      'assignment_method',
      'assignmentMethod',
      'pasajero_id',
      'pasajeroId',
      'origen_coordenadas_validas',
      'origenCoordenadasValidas',
      'aviso_sin_mapa',
      'avisoSinMapa',
      'codigo_origen',
      'codigoOrigen',
      'aceptable',
    ]) {
      final v = raw[key];
      if (v != null && v.toString().trim().isNotEmpty) {
        m[key] = v;
      }
    }
    if (precioEstimado != null) {
      m['precio_estimado'] = precioEstimado;
      m['precio_ofertado'] = precioEstimado;
    }
    if (distanciaDesdeMiKm != null) {
      m['distancia_desde_mi_km'] = distanciaDesdeMiKm;
    }
    return m;
  }

  static void _mergeUbicacionEnMapa(
    Map<String, dynamic> m, {
    String? campoOrigen,
    String? campoDestino,
  }) {
    void splitEnBarrio(String? texto, {required bool esOrigen}) {
      if (texto == null || texto.trim().isEmpty) return;
      final t = texto.trim();
      if (esOrigen) {
        m['origen'] ??= t;
      } else {
        m['destino'] ??= t;
      }
      if (!t.contains(',')) return;
      final partes = t.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
      if (partes.isEmpty) return;
      final calle = partes.first;
      final resto = partes.length > 1 ? partes.sublist(1).join(', ') : '';
      final barrioKey = esOrigen ? 'origen_barrio' : 'destino_barrio';
      final addrKey = esOrigen ? 'origen_address' : 'destino_address';
      final barrioActual = m[barrioKey]?.toString().trim() ?? '';
      final addrActual = m[addrKey]?.toString().trim() ?? '';
      if (barrioActual.isEmpty) {
        m[addrKey] = calle;
        if (resto.isNotEmpty) m[barrioKey] = resto;
      } else if (addrActual.isEmpty || addrActual == t) {
        m[addrKey] = calle;
      }
    }

    splitEnBarrio(campoOrigen, esOrigen: true);
    splitEnBarrio(campoDestino, esOrigen: false);
  }

  static ConductorOfertaExclusiva? tryFromDynamic(dynamic data) {
    if (data == null) return null;
    Map<String, dynamic> map;
    if (data is Map) {
      map = Map<String, dynamic>.from(data);
      if (map['data'] is Map) {
        map = Map<String, dynamic>.from(map['data'] as Map);
      }
    } else if (data is String) {
      return null;
    } else {
      return null;
    }

    final sid = _parseServicioId(map);
    if (sid == null || sid <= 0) return null;

    final notifTipo = ConductorSocketPayloadRouter.notificacionTipo(map);
    final esDirecta = ConductorSocketPayloadRouter.esOfertaDirecta(map);

    if (esDirecta || notifTipo == 'oferta_directa') {
      return _buildFromMap(map, sid, faseOferta: 'directa');
    }

    if (notifTipo == 'exclusiva_indrive') {
      return _buildFromMap(map, sid, faseOferta: 'exclusiva');
    }

    // Cola Llegando/Espera (BROADCAST o inDrive en lista): no pantalla exclusiva.
    if (ConductorSolicitudPayloadHelper.usaConductorTabApi(map)) {
      final modo = map['countdown_modo']?.toString();
      if (modo != 'oferta_exclusiva') return null;
    }
    if (ConductorSolicitudPayloadHelper.broadcastFaseLlegando(map)) {
      return null;
    }
    final metodo = map['assignment_method']?.toString().toUpperCase() ??
        map['assignmentMethod']?.toString().toUpperCase();
    if (metodo == 'BROADCAST_NEARBY_DRIVERS') return null;

    final fase = map['fase_oferta']?.toString().toLowerCase();
    if (fase != 'exclusiva' && map['oferta_exclusiva'] != true) {
      return null;
    }

    return _buildFromMap(map, sid, faseOferta: fase ?? 'exclusiva');
  }

  static ConductorOfertaExclusiva _buildFromMap(
    Map<String, dynamic> map,
    int sid, {
    required String faseOferta,
  }) {
    final ttl = _parseInt(map['ttl_segundos'] ?? map['oferta_segundos']);
    final seg = ServicioEsperaTimer.segundosOferta(map);
    final segRestantes = seg > 0 ? seg : ttl;

    return ConductorOfertaExclusiva(
      servicioId: sid,
      solicitudId: sid.toString(),
      raw: map,
      faseOferta: faseOferta,
      segundosRestantes: segRestantes,
      ttlSegundos: ttl ?? segRestantes,
      intento: _parseInt(map['intento']),
      maxIntentos: _parseInt(map['max_intentos']),
      distanciaDesdeMiKm: JsonPayloadHelper.parseDouble(
        map['distancia_desde_mi_km'] ?? map['distancia_km'],
      ),
      origen: map['origen']?.toString(),
      destino: map['destino']?.toString(),
      precioEstimado: JsonPayloadHelper.parseDouble(
        map['precio_estimado'] ?? map['precio_ofertado'],
      ),
      origenLat: JsonPayloadHelper.parseDouble(map['origen_lat']),
      origenLng: JsonPayloadHelper.parseDouble(map['origen_lng']),
      expiraEn: map['oferta_expira_en']?.toString() ??
          map['expira_en']?.toString() ??
          map['overlay_expira_en']?.toString(),
    );
  }

  static int? _parseServicioId(Map<String, dynamic> m) {
    for (final key in const [
      'servicio_id',
      'solicitud_id',
      'id',
    ]) {
      final v = m[key];
      if (v == null) continue;
      final n = int.tryParse(v.toString());
      if (n != null && n > 0) return n;
    }
    return null;
  }

  static int? _parseInt(dynamic v) {
    if (v == null) return null;
    return int.tryParse(v.toString());
  }
}
