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
  static const solicitudTomada = 'solicitud.tomada';
  static const servicioAceptado = 'servicio.aceptado';
  static const servicioEstadoCambiado = 'servicio.estado.cambiado';
  static const conductorUbicacionActualizada = 'conductor.ubicacion.actualizada';
}
