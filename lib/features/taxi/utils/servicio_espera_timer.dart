/// Dos relojes del backend: oferta exclusiva (~45 s) vs cola (~10 min).
class ServicioEsperaTimer {
  ServicioEsperaTimer._();

  static DateTime? parseExpiraEn(dynamic raw) {
    if (raw == null) return null;
    final s = raw.toString().trim();
    if (s.isEmpty) return null;

    var parsed = DateTime.tryParse(s.replaceFirst(' ', 'T'));
    parsed ??= DateTime.tryParse(s);
    if (parsed == null) return null;
    return parsed.isUtc ? parsed.toLocal() : parsed;
  }

  static int? _parseInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString());
  }

  static int _desdeExpira(String? expiraStr, int? fallbackSeg) {
    if (expiraStr != null) {
      final expira = parseExpiraEn(expiraStr);
      if (expira != null) {
        return expira.difference(DateTime.now()).inSeconds.clamp(0, 86400);
      }
    }
    return (fallbackSeg ?? 0).clamp(0, 86400);
  }

  static bool _esContextoOfertaExclusiva(Map<String, dynamic> data) {
    final f = data['fase_oferta']?.toString().toLowerCase();
    return f == 'exclusiva' || data['oferta_exclusiva'] == true;
  }

  /// Pantalla grande / oferta exclusiva (~45 s).
  static int segundosOferta(Map<String, dynamic> data) => _desdeExpira(
        (data['oferta_expira_en'] ??
                data['ofertaExpiraEn'] ??
                data['expira_en'] ??
                data['expiraEn'] ??
                data['overlay_expira_en'] ??
                data['overlayExpiraEn'])
            ?.toString(),
        _parseInt(
          data['segundos_restantes_oferta'] ??
              data['segundosRestantesOferta'] ??
              data['oferta_segundos'] ??
              data['segundos_restantes'] ??
              data['segundosRestantes'] ??
              data['ttl_segundos'],
        ),
      );

  /// Servicio en cola (~10 min).
  static int segundosCola(Map<String, dynamic> data) {
    final cola = _desdeExpira(
      (data['cola_expira_en'] ??
              data['colaExpiraEn'] ??
              data['servicio_expira_en'] ??
              data['servicioExpiraEn'])
          ?.toString(),
      _parseInt(
        data['segundos_restantes_cola'] ?? data['segundosRestantesCola'],
      ),
    );
    if (cola > 0) return cola;

    // Lista API (fase abierta): `expira_en` = fin de cola.
    if (!_esContextoOfertaExclusiva(data)) {
      return _desdeExpira(
        (data['expira_en'] ?? data['expiraEn'])?.toString(),
        _parseInt(data['segundos_restantes'] ?? data['segundosRestantes']),
      );
    }
    return 0;
  }

  static bool ofertaExpirada(Map<String, dynamic> data) =>
      segundosOferta(data) <= 0;

  static bool colaExpirada(Map<String, dynamic> data) => segundosCola(data) <= 0;

  /// Hay campos de cola en el payload (evita purgar ítems sin timing del API).
  static bool tieneDatosCola(Map<String, dynamic> data) {
    for (final key in const [
      'cola_expira_en',
      'colaExpiraEn',
      'servicio_expira_en',
      'servicioExpiraEn',
      'segundos_restantes_cola',
      'segundosRestantesCola',
    ]) {
      if (data[key] != null) return true;
    }
    if (!_esContextoOfertaExclusiva(data)) {
      return data['expira_en'] != null ||
          data['expiraEn'] != null ||
          data['segundos_restantes'] != null ||
          data['segundosRestantes'] != null;
    }
    return false;
  }

  /// `9:47` si ≥ 60 s; si no, `45s`.
  static String formatearCuentaRegresiva(int segundos) {
    if (segundos <= 0) return '0:00';
    if (segundos >= 60) {
      final m = segundos ~/ 60;
      final s = segundos % 60;
      return '$m:${s.toString().padLeft(2, '0')}';
    }
    return '${segundos}s';
  }
}
