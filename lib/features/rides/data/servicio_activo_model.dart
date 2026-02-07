class ServicioActivo {
  final int id;
  final String fechaServicio;
  final int idActivationCompanyUser;
  final int idEmpresa;
  final int idEstado;
  final String origenServicio;
  final double origenLat;
  final double origenLng;
  final String origenAddress;
  final String? origenName;
  final double destinoLat;
  final double destinoLng;
  final String destinoAddress;
  final String? destinoName;
  final int? distanciaMetros;
  final String? distanciaTexto;
  final int? duracionSegundos;
  final String? duracionTexto;
  final double precioEstimado;
  final double? precioFinal;
  final String tipoServicio;
  final int? conductorId;
  final EstadoServicio estado;
  final ConductorInfo? conductor;
  final VehiculoInfo? vehiculo;

  ServicioActivo({
    required this.id,
    required this.fechaServicio,
    required this.idActivationCompanyUser,
    required this.idEmpresa,
    required this.idEstado,
    required this.origenServicio,
    required this.origenLat,
    required this.origenLng,
    required this.origenAddress,
    this.origenName,
    required this.destinoLat,
    required this.destinoLng,
    required this.destinoAddress,
    this.destinoName,
    this.distanciaMetros,
    this.distanciaTexto,
    this.duracionSegundos,
    this.duracionTexto,
    required this.precioEstimado,
    this.precioFinal,
    required this.tipoServicio,
    this.conductorId,
    required this.estado,
    this.conductor,
    this.vehiculo,
  });

  factory ServicioActivo.fromJson(Map<String, dynamic> json) {
    return ServicioActivo(
      id: json['id'] ?? 0,
      fechaServicio: json['fechaServicio'] ?? '',
      idActivationCompanyUser: json['idActivationCompanyUser'] ?? 0,
      idEmpresa: json['idEmpresa'] ?? 0,
      idEstado: json['idEstado'] ?? 0,
      origenServicio: json['origenServicio'] ?? '',
      origenLat: double.tryParse(json['origen_lat']?.toString() ?? '0') ?? 0.0,
      origenLng: double.tryParse(json['origen_lng']?.toString() ?? '0') ?? 0.0,
      origenAddress: json['origen_address'] ?? '',
      origenName: json['origen_name'],
      destinoLat:
          double.tryParse(json['destino_lat']?.toString() ?? '0') ?? 0.0,
      destinoLng:
          double.tryParse(json['destino_lng']?.toString() ?? '0') ?? 0.0,
      destinoAddress: json['destino_address'] ?? '',
      destinoName: json['destino_name'],
      distanciaMetros: json['distancia_metros'],
      distanciaTexto: json['distancia_texto'],
      duracionSegundos: json['duracion_segundos'],
      duracionTexto: json['duracion_texto'],
      precioEstimado:
          double.tryParse(json['precio_estimado']?.toString() ?? '0') ?? 0.0,
      precioFinal: json['precio_final'] != null
          ? double.tryParse(json['precio_final'].toString())
          : null,
      tipoServicio: json['tipo_servicio'] ?? 'taxi',
      conductorId: json['conductor_id'],
      estado: EstadoServicio.fromJson(json['estado'] ?? {}),
      conductor: json['conductor'] != null
          ? ConductorInfo.fromJson(json['conductor'])
          : null,
      vehiculo: json['vehiculo'] != null
          ? VehiculoInfo.fromJson(json['vehiculo'])
          : null,
    );
  }

  bool get isPendiente => idEstado == 1;
  bool get isAceptado => idEstado == 2;
  bool get isEnCamino => idEstado == 3;
  bool get isLlegue => idEstado == 4;
  bool get isEnCurso => idEstado == 5;
  bool get isFinalizado => idEstado == 6;
  bool get isCancelado => idEstado == 7;
  bool get isActivo => !isFinalizado && !isCancelado;
}

class EstadoServicio {
  final int id;
  final String estado;

  EstadoServicio({required this.id, required this.estado});

  factory EstadoServicio.fromJson(Map<String, dynamic> json) {
    return EstadoServicio(
      id: json['id'] ?? 0,
      estado: json['estado'] ?? 'Desconocido',
    );
  }
}

class ConductorInfo {
  final int id;
  final String nombre;
  final String? telefono;
  final String? foto;
  final double? calificacion;
  final double? lat;
  final double? lng;

  ConductorInfo({
    required this.id,
    required this.nombre,
    this.telefono,
    this.foto,
    this.calificacion,
    this.lat,
    this.lng,
  });

  factory ConductorInfo.fromJson(Map<String, dynamic> json) {
    return ConductorInfo(
      id: json['id'] ?? 0,
      nombre: json['nombre'] ?? 'Conductor',
      telefono: json['telefono'],
      foto: json['foto'],
      calificacion: json['calificacion'] != null
          ? double.tryParse(json['calificacion'].toString())
          : null,
      lat: json['lat'] != null ? double.tryParse(json['lat'].toString()) : null,
      lng: json['lng'] != null ? double.tryParse(json['lng'].toString()) : null,
    );
  }
}

class VehiculoInfo {
  final String? marca;
  final String? modelo;
  final String? placa;
  final String? color;

  VehiculoInfo({this.marca, this.modelo, this.placa, this.color});

  factory VehiculoInfo.fromJson(Map<String, dynamic> json) {
    return VehiculoInfo(
      marca: json['marca'],
      modelo: json['modelo'],
      placa: json['placa'],
      color: json['color'],
    );
  }

  String get descripcion {
    final parts = <String>[];
    if (marca != null) parts.add(marca!);
    if (modelo != null) parts.add(modelo!);
    if (color != null) parts.add(color!);
    return parts.join(' ');
  }
}
