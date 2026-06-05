/// Canales/eventos WebSocket emergencias (Soketi en VPS).
class EmergenciaSocketChannels {
  EmergenciaSocketChannels._();

  static String empresa(int idEmpresa) => 'emergencias-empresa.$idEmpresa';
}

class EmergenciaSocketEvents {
  EmergenciaSocketEvents._();

  static const activa = 'emergencia.activa';
  static const finalizada = 'emergencia.finalizada';
}
