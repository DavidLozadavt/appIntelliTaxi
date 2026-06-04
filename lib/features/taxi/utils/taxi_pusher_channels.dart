/// Nombres de canales/eventos Pusher taxi (instancia secundaria).
class TaxiPusherChannels {
  TaxiPusherChannels._();

  static const solicitudesServicio = 'solicitudes-servicio';

  static String servicio(int servicioId) => 'servicio.$servicioId';

  static String chatServicio(int servicioId) => 'chat.servicio.$servicioId';

  static String pasajero(int userId) => 'pasajero.$userId';
}

class TaxiPusherEvents {
  TaxiPusherEvents._();

  static const nuevaSolicitud = 'nueva-solicitud';
  static const servicioCercano = 'servicio.cercano';
  static const ofertaServicioExclusiva = 'oferta.servicio.exclusiva';
  static const ofertaServicioCerrada = 'oferta.servicio.cerrada';
  static const solicitudTomada = 'solicitud.tomada';
  static const servicioAceptado = 'servicio.aceptado';
  static const servicioEstadoCambiado = 'servicio.estado.cambiado';
  static const conductorUbicacionActualizada = 'conductor.ubicacion.actualizada';

  /// Eventos de chat en `chat.servicio.{id}` (Laravel `NuevoMensajeTaxi`).
  static const nuevoMensaje = 'nuevo.mensaje';
  static const mensajeLeido = 'mensaje.leido';

  /// Variantes que el backend puede emitir según `broadcastAs` / versión.
  static const List<String> nuevoMensajeAliases = [
    nuevoMensaje,
    'NuevoMensajeTaxi',
    'nuevo_mensaje',
    'nuevo-mensaje',
  ];

  static const List<String> mensajeLeidoAliases = [
    mensajeLeido,
    'MensajeLeidoTaxi',
    'mensaje_leido',
  ];
}
