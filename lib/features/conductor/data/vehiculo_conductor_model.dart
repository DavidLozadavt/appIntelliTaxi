class VehiculoConductor {
  final int id;
  final String placa;
  final String? chasis;
  final String? serie;
  final String numPuestos;
  final String? runt;
  final String? foto;
  final int idModelo;
  final int idTipo;
  final int idMarca;
  final int idEstado;
  final int idEmpresa;
  final String createdAt;
  final String updatedAt;
  final int idClaseVehiculo;
  final String? tipoCombustible;
  final String? motor;
  final String? color;
  final String? radioAccion;
  final String? numeroManifiestoAduana;
  final String? origenManifiestoAduana;
  final String? rutaUrl;
  final Marca? marca;
  final Modelo? modelo;
  final TipoVehiculo? tipoVehiculo;
  final Estado? estado;
  final List<AsignacionPropietario> asignacionPropietarios;

  VehiculoConductor({
    required this.id,
    required this.placa,
    this.chasis,
    this.serie,
    required this.numPuestos,
    this.runt,
    this.foto,
    required this.idModelo,
    required this.idTipo,
    required this.idMarca,
    required this.idEstado,
    required this.idEmpresa,
    required this.createdAt,
    required this.updatedAt,
    required this.idClaseVehiculo,
    this.tipoCombustible,
    this.motor,
    this.color,
    this.radioAccion,
    this.numeroManifiestoAduana,
    this.origenManifiestoAduana,
    this.rutaUrl,
    this.marca,
    this.modelo,
    this.tipoVehiculo,
    this.estado,
    required this.asignacionPropietarios,
  });

  factory VehiculoConductor.fromJson(Map<String, dynamic> json) {
    return VehiculoConductor(
      id: _asInt(json['id']),
      placa: json['placa']?.toString() ?? '',
      chasis: json['chasis']?.toString(),
      serie: json['serie']?.toString(),
      numPuestos: json['numPuestos']?.toString() ?? '4',
      runt: json['runt']?.toString(),
      foto: json['foto']?.toString(),
      idModelo: _asInt(json['idModelo']),
      idTipo: _asInt(json['idTipo']),
      idMarca: _asInt(json['idMarca']),
      idEstado: _asInt(json['idEstado']),
      idEmpresa: _asInt(json['idEmpresa']),
      createdAt: json['created_at']?.toString() ?? '',
      updatedAt: json['updated_at']?.toString() ?? '',
      idClaseVehiculo: _asInt(json['idClaseVehiculo']),
      tipoCombustible: json['tipoCombustible']?.toString(),
      motor: json['motor']?.toString(),
      color: json['color']?.toString(),
      radioAccion: json['radioAccion']?.toString(),
      numeroManifiestoAduana: json['numeroManifiestoAduana']?.toString(),
      origenManifiestoAduana: json['origenManifiestoAduana']?.toString(),
      rutaUrl: json['rutaUrl']?.toString(),
      marca: json['marca'] != null ? Marca.fromJson(json['marca']) : null,
      modelo: json['modelo'] != null ? Modelo.fromJson(json['modelo']) : null,
      tipoVehiculo: json['tipo_vehiculo'] != null
          ? TipoVehiculo.fromJson(json['tipo_vehiculo'])
          : null,
      estado: json['estado'] != null ? Estado.fromJson(json['estado']) : null,
      asignacionPropietarios:
          (json['asignacion_propietarios'] as List?)
              ?.map((e) => AsignacionPropietario.fromJson(e))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'placa': placa,
      'chasis': chasis,
      'serie': serie,
      'numPuestos': numPuestos,
      'runt': runt,
      'foto': foto,
      'idModelo': idModelo,
      'idTipo': idTipo,
      'idMarca': idMarca,
      'idEstado': idEstado,
      'idEmpresa': idEmpresa,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'idClaseVehiculo': idClaseVehiculo,
      'tipoCombustible': tipoCombustible,
      'motor': motor,
      'color': color,
      'radioAccion': radioAccion,
      'numeroManifiestoAduana': numeroManifiestoAduana,
      'origenManifiestoAduana': origenManifiestoAduana,
      'rutaUrl': rutaUrl,
      'marca': marca?.toJson(),
      'modelo': modelo?.toJson(),
      'tipo_vehiculo': tipoVehiculo?.toJson(),
      'estado': estado?.toJson(),
      'asignacion_propietarios': asignacionPropietarios
          .map((e) => e.toJson())
          .toList(),
    };
  }

  String get nombreCompleto {
    if (marca != null && modelo != null) {
      return '${marca!.marca} ${modelo!.modelo} - $placa';
    }
    return placa;
  }
}

class Marca {
  final int id;
  final String marca;
  final String? descripcion;
  final String? codigo;
  final String? createdAt;
  final String? updatedAt;

  Marca({
    required this.id,
    required this.marca,
    this.descripcion,
    this.codigo,
    this.createdAt,
    this.updatedAt,
  });

  factory Marca.fromJson(Map<String, dynamic> json) {
    return Marca(
      id: _asInt(json['id']),
      marca: json['marca']?.toString() ?? '',
      descripcion: json['descripcion']?.toString(),
      codigo: json['codigo']?.toString(),
      createdAt: json['created_at']?.toString(),
      updatedAt: json['updated_at']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'marca': marca,
      'descripcion': descripcion,
      'codigo': codigo,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }
}

class Modelo {
  final int id;
  final String modelo;
  final String? descripcion;

  Modelo({required this.id, required this.modelo, this.descripcion});

  factory Modelo.fromJson(Map<String, dynamic> json) {
    return Modelo(
      id: _asInt(json['id']),
      modelo: json['modelo']?.toString() ?? '',
      descripcion: json['descripcion']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'modelo': modelo, 'descripcion': descripcion};
  }
}

class TipoVehiculo {
  final int id;
  final String tipo;
  final String? descripcion;

  TipoVehiculo({required this.id, required this.tipo, this.descripcion});

  factory TipoVehiculo.fromJson(Map<String, dynamic> json) {
    return TipoVehiculo(
      id: _asInt(json['id']),
      tipo: json['tipo']?.toString() ?? '',
      descripcion: json['descripcion']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'tipo': tipo, 'descripcion': descripcion};
  }
}

class Estado {
  final int id;
  final String estado;
  final String? descripcion;

  Estado({required this.id, required this.estado, this.descripcion});

  factory Estado.fromJson(Map<String, dynamic> json) {
    return Estado(
      id: _asInt(json['id']),
      estado: json['estado']?.toString() ?? '',
      descripcion: json['descripcion']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'estado': estado, 'descripcion': descripcion};
  }
}

class AsignacionPropietario {
  final int id;
  final int? idPropietario;
  final String fechaAsignacion;
  final int idVehiculo;
  final String? porcentaje;
  final String? observacion;
  final int idEstado;
  final int idAfiliacion;
  final String createdAt;
  final String updatedAt;
  final String administrador;
  final String estado;
  final dynamic propietario;
  final Afiliacion afiliacion;

  AsignacionPropietario({
    required this.id,
    this.idPropietario,
    required this.fechaAsignacion,
    required this.idVehiculo,
    this.porcentaje,
    this.observacion,
    required this.idEstado,
    required this.idAfiliacion,
    required this.createdAt,
    required this.updatedAt,
    required this.administrador,
    required this.estado,
    this.propietario,
    required this.afiliacion,
  });

  factory AsignacionPropietario.fromJson(Map<String, dynamic> json) {
    return AsignacionPropietario(
      id: _asInt(json['id']),
      idPropietario: json['idPropietario'] == null
          ? null
          : _asInt(json['idPropietario']),
      fechaAsignacion: json['fechaAsignacion']?.toString() ?? '',
      idVehiculo: _asInt(json['idVehiculo']),
      porcentaje: json['porcentaje']?.toString(),
      observacion: json['observacion']?.toString(),
      idEstado: _asInt(json['idEstado']),
      idAfiliacion: _asInt(json['idAfiliacion']),
      createdAt: json['created_at']?.toString() ?? '',
      updatedAt: json['updated_at']?.toString() ?? '',
      administrador: json['administrador']?.toString() ?? 'No',
      estado: json['estado']?.toString() ?? '',
      propietario: json['propietario'],
      afiliacion: Afiliacion.fromJson(
        Map<String, dynamic>.from(json['afiliacion'] ?? const {}),
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'idPropietario': idPropietario,
      'fechaAsignacion': fechaAsignacion,
      'idVehiculo': idVehiculo,
      'porcentaje': porcentaje,
      'observacion': observacion,
      'idEstado': idEstado,
      'idAfiliacion': idAfiliacion,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'administrador': administrador,
      'estado': estado,
      'propietario': propietario,
      'afiliacion': afiliacion.toJson(),
    };
  }
}

class Afiliacion {
  final int id;
  final String numero;

  Afiliacion({required this.id, required this.numero});

  factory Afiliacion.fromJson(Map<String, dynamic> json) {
    return Afiliacion(
      id: _asInt(json['id']),
      numero: json['numero']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'numero': numero};
  }
}

int _asInt(dynamic value, [int fallback = 0]) {
  if (value == null) return fallback;
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) {
    final parsed = int.tryParse(value.trim());
    if (parsed != null) return parsed;
  }
  return fallback;
}
