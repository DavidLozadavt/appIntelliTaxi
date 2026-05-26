/// Estado rápido del conductor según `GET /taxi/conductor/estado-actual`.
class TaxiConductorEstadoActual {
  final bool disponible;
  final bool enServicio;
  final int? servicioActivoId;
  final int? idEstado;

  const TaxiConductorEstadoActual({
    required this.disponible,
    required this.enServicio,
    this.servicioActivoId,
    this.idEstado,
  });

  factory TaxiConductorEstadoActual.fromJson(Map<String, dynamic> json) {
    return TaxiConductorEstadoActual(
      disponible: json['disponible'] == true,
      enServicio: json['en_servicio'] == true,
      servicioActivoId: _parseInt(
        json['servicio_activo_id'] ?? json['servicioActivoId'],
      ),
      idEstado: _parseInt(json['id_estado'] ?? json['idEstado']),
    );
  }

  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    return int.tryParse(value.toString());
  }
}

/// Resultado de `GET /taxi/solicitudes-publicadas-conductor`.
class TaxiSolicitudesPublicadasResult {
  final bool enServicio;
  final int? servicioActivoId;
  final List<Map<String, dynamic>> solicitudes;

  const TaxiSolicitudesPublicadasResult({
    required this.enServicio,
    this.servicioActivoId,
    required this.solicitudes,
  });
}
