/// Canales/eventos Pusher emergencias (instancia secundaria).
class EmergenciaPusherChannels {
  EmergenciaPusherChannels._();

  static String empresa(int idEmpresa) => 'emergencias-empresa.$idEmpresa';
}

class EmergenciaPusherEvents {
  EmergenciaPusherEvents._();

  static const activa = 'emergencia.activa';
  static const finalizada = 'emergencia.finalizada';
}
