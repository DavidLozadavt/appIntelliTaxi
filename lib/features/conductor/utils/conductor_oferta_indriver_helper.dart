import 'package:intellitaxi/features/conductor/data/conductor_oferta_exclusiva.dart';
import 'package:intellitaxi/features/conductor/utils/conductor_socket_payload_router.dart';

/// Reglas fase oferta inDrive (exclusiva → abierta).
abstract final class ConductorOfertaIndriverHelper {
  static String? faseOferta(Map<String, dynamic> raw) {
    final f = raw['fase_oferta']?.toString().trim().toLowerCase();
    if (f != null && f.isNotEmpty) return f;
    if (raw['oferta_exclusiva'] == true) return 'exclusiva';
    return null;
  }

  static bool esFaseExclusiva(Map<String, dynamic> raw) =>
      faseOferta(raw) == 'exclusiva' || raw['oferta_exclusiva'] == true;

  static bool esFaseAbierta(Map<String, dynamic> raw) {
    final f = faseOferta(raw);
    return f == null || f == 'abierta' || f == 'broadcast' || f == 'publica';
  }

  /// Exclusiva terminó y el mismo servicio entra al broadcast / «Llegando».
  static bool pasoDeExclusivaAPublicoEnLlegando(
    Map<String, dynamic>? anterior,
    Map<String, dynamic> actual,
  ) {
    if (anterior == null) return false;
    if (!esFaseExclusiva(anterior)) return false;
    return esFaseAbierta(actual) && !esFaseExclusiva(actual);
  }

  /// BROADCAST / inDrive: el API movió el servicio de «Llegando» a «En espera» (fase 2).
  static bool pasoDeLlegandoAEspera(
    Map<String, dynamic>? anterior,
    Map<String, dynamic> actual,
  ) {
    if (anterior == null) return false;
    final tabAnt =
        anterior['conductor_tab']?.toString().trim().toLowerCase();
    final tabNuevo =
        actual['conductor_tab']?.toString().trim().toLowerCase();
    if (tabAnt == 'llegando' && tabNuevo == 'espera') return true;
    if (tabAnt != 'llegando') return false;
    return esFaseAbierta(actual) &&
        faseOferta(anterior) != null &&
        faseOferta(actual) == 'abierta';
  }

  /// `servicio.cercano` / pendientes con cola asignada a este conductor (BROADCAST fase 1, etc.).
  static bool esAsignacionColaParaMi(Map<String, dynamic> raw) {
    final tab = raw['conductor_tab']?.toString().trim().toLowerCase();
    if (tab == 'llegando' || tab == 'espera') return true;
    if (raw['broadcast_fase_llegando'] == true) return true;
    if (raw['aceptar_rechazar'] == true && tab != null) return true;
    final method = raw['assignment_method']?.toString().toUpperCase() ??
        raw['assignmentMethod']?.toString().toUpperCase();
    if (method == 'BROADCAST_NEARBY_DRIVERS') return true;
    final modo = raw['countdown_modo']?.toString().toLowerCase() ?? '';
    if (modo.contains('broadcast')) return true;
    return false;
  }

  /// En canal público: ignorar si la oferta sigue siendo exclusiva para otro.
  /// Con [listaGlobal] true (híbrido), el broadcast público siempre entra a la cola.
  static bool ignorarNuevaSolicitudPublica(
    Map<String, dynamic> raw, {
    required bool listaGlobal,
    required bool tengoOfertaExclusivaActiva,
    int? miOfertaExclusivaServicioId,
  }) {
    if (listaGlobal) return false;
    if (esAsignacionColaParaMi(raw)) return false;

    if (esFaseExclusiva(raw) && raw['oferta_exclusiva'] == true) {
      return true;
    }
    if (tengoOfertaExclusivaActiva) {
      final sid = ConductorOfertaExclusiva.tryFromDynamic(raw)?.servicioId ??
          int.tryParse(
            raw['servicio_id']?.toString() ?? raw['solicitud_id']?.toString() ?? '',
          );
      if (sid == null || sid != miOfertaExclusivaServicioId) {
        return true;
      }
    }
    return false;
  }

  /// 409 al aceptar: reservado para otro conductor cercano (mantener en lista global).
  static bool esConflictoOfertaAjena(String message) {
    final m = message.toLowerCase();
    return m.contains('reservad') ||
        m.contains('otro conductor cercano') ||
        m.contains('temporalmente para otro') ||
        m.contains('espera a que quede abierto');
  }

  /// Fuera del radio de asignación (403 al aceptar).
  static bool esErrorFueraDeRangoAsignacion(String message) {
    final m = message.toLowerCase();
    return m.contains('fuera del rango') ||
        m.contains('rango permitido') ||
        (m.contains('outside') && m.contains('range'));
  }

  /// Tras 409/403, quitar de cola solo si el servicio ya no está disponible para nadie.
  static bool debeRetirarTrasConflictoAceptacion(String message) {
    if (message.trim().isEmpty) return false;
    if (esConflictoOfertaAjena(message)) return false;
    if (esErrorFueraDeRangoAsignacion(message)) return true;
    final m = message.toLowerCase();
    return m.contains('ya fue aceptado') ||
        m.contains('ya fue tomado') ||
        m.contains('tomada por otro') ||
        m.contains('tomado por otro') ||
        m.contains('no está disponible') ||
        m.contains('no esta disponible');
  }

  static bool esBroadcastNearbyDrivers(Map<String, dynamic> raw) {
    final method = raw['assignment_method']?.toString().toUpperCase() ??
        raw['assignmentMethod']?.toString().toUpperCase();
    return method == 'BROADCAST_NEARBY_DRIVERS';
  }

  /// Rotación inDrive activa (`oferta_max_intentos > 0`). Con 0 → solo 2 min Llegando + 2 min Espera.
  static bool tieneRotacionIndriver(int? ofertaMaxIntentos) =>
      ofertaMaxIntentos != null && ofertaMaxIntentos > 0;

  /// Rotación broadcast explícita (`rebote_numero` > 1). No confundir con fase Llegando/Espera normal.
  static bool esBroadcastRebote(Map<String, dynamic> s) {
    if (s['rebote_activo'] == true) return true;
    final modo = s['countdown_modo']?.toString().toLowerCase() ?? '';
    if (modo == 'broadcast_rebote') return true;
    final rebote = int.tryParse(s['rebote_numero']?.toString() ?? '');
    return rebote != null && rebote > 1;
  }

  static bool esActualizarFase(Map<String, dynamic> raw) {
    final accion = raw['evento_accion']?.toString().toLowerCase() ?? '';
    return accion == 'actualizar_fase';
  }

  static bool debeReemplazarExistente(Map<String, dynamic> raw) {
    if (raw['reemplazar_existente'] == true) return true;
    return esActualizarFase(raw);
  }

  static int? reboteNumero(Map<String, dynamic> raw) {
    final n = int.tryParse(raw['rebote_numero']?.toString() ?? '');
    return n != null && n > 0 ? n : null;
  }

  /// Payload de canal privado / FCM / oferta-activa (no broadcast público genérico).
  static bool esPayloadOfertaExclusivaParaMi(Map<String, dynamic> raw) {
    if (raw['fullscreen'] == true ||
        raw['fullscreen'] == 1 ||
        raw['fullscreen'] == '1') {
      return true;
    }
    final tipo = raw['tipo']?.toString().toLowerCase() ?? '';
    return tipo.contains('oferta_servicio_exclusiva');
  }

  /// Botones aceptar/rechazar: solo si el API indica `puede_aceptar` / `aceptar_rechazar`.
  /// Realtime sin esas claves: exclusiva directa, rebote broadcast u oferta directa.
  static bool puedeAceptarRechazar(Map<String, dynamic> raw) {
    if (raw.containsKey('puede_aceptar')) {
      return raw['puede_aceptar'] == true;
    }
    if (raw.containsKey('aceptar_rechazar')) {
      return raw['aceptar_rechazar'] == true;
    }
    if (raw['oferta_exclusiva'] == true) return true;
    if (ConductorSocketPayloadRouter.esOfertaDirecta(raw)) return true;
    return false;
  }
}
