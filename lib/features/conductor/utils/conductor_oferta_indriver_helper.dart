import 'package:intellitaxi/features/conductor/data/conductor_oferta_exclusiva.dart';

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

  /// En canal público: ignorar si la oferta sigue siendo exclusiva para otro.
  /// Con [listaGlobal] true (híbrido), el broadcast público siempre entra a la cola.
  static bool ignorarNuevaSolicitudPublica(
    Map<String, dynamic> raw, {
    required bool listaGlobal,
    required bool tengoOfertaExclusivaActiva,
    int? miOfertaExclusivaServicioId,
  }) {
    if (listaGlobal) return false;

    if (esFaseExclusiva(raw)) {
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

  /// Tras 409, quitar de cola solo si el servicio ya no está disponible para nadie.
  static bool debeRetirarTrasConflictoAceptacion(String message) {
    if (message.trim().isEmpty) return false;
    if (esConflictoOfertaAjena(message)) return false;
    final m = message.toLowerCase();
    return m.contains('ya fue aceptado') ||
        m.contains('ya fue tomado') ||
        m.contains('tomada por otro') ||
        m.contains('tomado por otro') ||
        m.contains('no está disponible') ||
        m.contains('no esta disponible');
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
}
