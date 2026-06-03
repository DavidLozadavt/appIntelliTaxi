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
  static bool ignorarNuevaSolicitudPublica(
    Map<String, dynamic> raw, {
    required bool tengoOfertaExclusivaActiva,
    int? miOfertaExclusivaServicioId,
  }) {
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
}
