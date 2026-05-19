class AfiliacionPropietariosVehiculo {
  final int id;
  final String numero;
  final String estado;
  final String? observaciones;
  final List<PropietarioVehiculo> propietarios;

  AfiliacionPropietariosVehiculo({
    required this.id,
    required this.numero,
    required this.estado,
    this.observaciones,
    required this.propietarios,
  });

  factory AfiliacionPropietariosVehiculo.fromJson(Map<String, dynamic> json) {
    return AfiliacionPropietariosVehiculo(
      id: _asInt(json['id']),
      numero: json['numero']?.toString() ?? '',
      estado: json['estado']?.toString() ?? '',
      observaciones: json['observaciones']?.toString(),
      propietarios:
          (json['propietario'] as List?)
              ?.whereType<Map>()
              .map(
                (e) =>
                    PropietarioVehiculo.fromJson(Map<String, dynamic>.from(e)),
              )
              .toList() ??
          const [],
    );
  }
}

class PropietarioVehiculo {
  final int id;
  final String identificacion;
  final String nombre1;
  final String? nombre2;
  final String apellido1;
  final String? apellido2;
  final String? email;
  final String? celular;
  final String? direccion;
  final String? rutaFotoUrl;
  final String? tipoTitular;
  final String? ciudadNacimiento;
  final String? departamentoNacimiento;
  final String? tipoIdentificacion;
  final PropietarioVehiculoPivot? pivot;

  PropietarioVehiculo({
    required this.id,
    required this.identificacion,
    required this.nombre1,
    this.nombre2,
    required this.apellido1,
    this.apellido2,
    this.email,
    this.celular,
    this.direccion,
    this.rutaFotoUrl,
    this.tipoTitular,
    this.ciudadNacimiento,
    this.departamentoNacimiento,
    this.tipoIdentificacion,
    this.pivot,
  });

  factory PropietarioVehiculo.fromJson(Map<String, dynamic> json) {
    final ciudadNac = json['ciudad_nac'] is Map
        ? Map<String, dynamic>.from(json['ciudad_nac'] as Map)
        : null;
    final departamento = ciudadNac?['departamento'] is Map
        ? Map<String, dynamic>.from(ciudadNac!['departamento'] as Map)
        : null;
    final tipoIdentificacion = json['tipo_identificacion'] is Map
        ? Map<String, dynamic>.from(json['tipo_identificacion'] as Map)
        : null;

    return PropietarioVehiculo(
      id: _asInt(json['id']),
      identificacion: json['identificacion']?.toString() ?? '',
      nombre1: json['nombre1']?.toString() ?? '',
      nombre2: json['nombre2']?.toString(),
      apellido1: json['apellido1']?.toString() ?? '',
      apellido2: json['apellido2']?.toString(),
      email: json['email']?.toString(),
      celular: json['celular']?.toString(),
      direccion: json['direccion']?.toString(),
      rutaFotoUrl: json['rutaFotoUrl']?.toString(),
      tipoTitular: json['tipoTitular']?.toString(),
      ciudadNacimiento: ciudadNac?['descripcion']?.toString(),
      departamentoNacimiento: departamento?['descripcion']?.toString(),
      tipoIdentificacion: tipoIdentificacion?['detalle']?.toString(),
      pivot: json['pivot'] is Map
          ? PropietarioVehiculoPivot.fromJson(
              Map<String, dynamic>.from(json['pivot'] as Map),
            )
          : null,
    );
  }

  String get nombreCompleto {
    return [nombre1, nombre2, apellido1, apellido2]
        .where((e) => e != null && e.trim().isNotEmpty)
        .map((e) => e!.trim())
        .join(' ');
  }
}

class PropietarioVehiculoPivot {
  final String porcentaje;
  final String administrador;
  final String estado;

  PropietarioVehiculoPivot({
    required this.porcentaje,
    required this.administrador,
    required this.estado,
  });

  factory PropietarioVehiculoPivot.fromJson(Map<String, dynamic> json) {
    return PropietarioVehiculoPivot(
      porcentaje: json['porcentaje']?.toString() ?? '',
      administrador: json['administrador']?.toString() ?? '',
      estado: json['estado']?.toString() ?? '',
    );
  }
}

int _asInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
