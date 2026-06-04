/// Enrutamiento de payloads Pusher/FCM según `notificacion_tipo` (prioridad §5 spec).
abstract final class ConductorSocketPayloadRouter {
  static String? notificacionTipo(Map<String, dynamic> raw) {
    final tipo = raw['notificacion_tipo']?.toString().trim().toLowerCase();
    if (tipo != null && tipo.isNotEmpty) return tipo;
    return raw['tipo']?.toString().trim().toLowerCase();
  }

  static bool esOfertaDirecta(Map<String, dynamic> raw) {
    final tipo = notificacionTipo(raw);
    if (tipo == 'oferta_directa') return true;

    final status = raw['status']?.toString().toLowerCase() ?? '';
    if (status == 'oferta_directa') return true;
    if (raw['es_oferta_directa'] == true || raw['oferta_directa'] == true) {
      return true;
    }

    final metodo = raw['assignment_method']?.toString().toUpperCase() ??
        raw['assignmentMethod']?.toString().toUpperCase();
    return metodo == 'DIRECT_OFFER' || metodo == 'OFERTA_DIRECTA';
  }

  static bool requiereOverlayFullscreen(Map<String, dynamic> raw) {
    final tipo = notificacionTipo(raw);
    if (tipo == 'exclusiva_indrive' || tipo == 'oferta_directa') return true;
    if (raw['ui_overlay']?.toString().toLowerCase() == 'fullscreen') {
      return true;
    }
    return raw['fullscreen'] == true ||
        raw['fullscreen'] == 1 ||
        raw['fullscreen'] == '1';
  }

  static bool esListaSinFullscreen(Map<String, dynamic> raw) {
    final tipo = notificacionTipo(raw);
    return tipo == 'global_indrive' || tipo == 'fase_abierta_indrive';
  }

  static bool esCercanoBroadcast(Map<String, dynamic> raw) {
    final tipo = notificacionTipo(raw);
    return tipo == 'cercano_broadcast';
  }

  static bool esOfertaCerrada(Map<String, dynamic> raw, {String? eventName}) {
    final tipo = notificacionTipo(raw);
    if (tipo == 'oferta_exclusiva_cerrada') return true;
    final ev = eventName?.toLowerCase() ?? '';
    return ev.contains('oferta.servicio.cerrada') ||
        ev.contains('oferta_servicio_cerrada');
  }

  static ConductorSocketAccion accionParaPayload(
    Map<String, dynamic> raw, {
    String? eventName,
  }) {
    if (esOfertaCerrada(raw, eventName: eventName)) {
      return ConductorSocketAccion.cerrarOverlay;
    }

    final tipo = notificacionTipo(raw);
    switch (tipo) {
      case 'exclusiva_indrive':
      case 'oferta_directa':
        return ConductorSocketAccion.overlayFullscreen;
      case 'cercano_broadcast':
        return ConductorSocketAccion.mergeColaCercano;
      case 'global_indrive':
      case 'fase_abierta_indrive':
        return ConductorSocketAccion.mergeCola;
      case 'oferta_exclusiva_cerrada':
        return ConductorSocketAccion.cerrarOverlay;
    }

    final ev = eventName?.toLowerCase() ?? '';
    if (ev.contains('oferta.servicio.cerrada') ||
        ev.contains('oferta_servicio_cerrada')) {
      return ConductorSocketAccion.cerrarOverlay;
    }
    if (ev.contains('oferta.servicio.exclusiva') ||
        ev.contains('oferta_directa') ||
        ev.contains('oferta.directa') ||
        ev.contains('oferta-directa')) {
      return ConductorSocketAccion.overlayFullscreen;
    }
    if (ev.contains('servicio.cercano') || ev.contains('servicio_cercano')) {
      return ConductorSocketAccion.mergeColaCercano;
    }

    if (requiereOverlayFullscreen(raw)) {
      return ConductorSocketAccion.overlayFullscreen;
    }
    if (esListaSinFullscreen(raw)) {
      return ConductorSocketAccion.mergeCola;
    }

    return ConductorSocketAccion.mergeCola;
  }
}

enum ConductorSocketAccion {
  overlayFullscreen,
  cerrarOverlay,
  mergeCola,
  mergeColaCercano,
}
