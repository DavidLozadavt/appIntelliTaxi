class Sancion {
  final int id;
  final int idConductor;
  final int idUser;
  final String? urlDoc;
  final String? fecha;
  final String? fechaFin;
  final String? observaciones;
  final String gravedad;
  final String? createdAt;
  final PersonaRegistro? registradoPor;

  Sancion({
    required this.id,
    required this.idConductor,
    required this.idUser,
    this.urlDoc,
    this.fecha,
    this.fechaFin,
    this.observaciones,
    required this.gravedad,
    this.createdAt,
    this.registradoPor,
  });

  factory Sancion.fromJson(Map<String, dynamic> json) {
    return Sancion(
      id: json['id'],
      idConductor: json['idConductor'],
      idUser: json['idUser'],
      urlDoc: json['urlDoc'],
      fecha: json['fecha'],
      fechaFin: json['fechaFin'],
      observaciones: json['observaciones'],
      gravedad: json['gravedad'] ?? 'BAJO',
      createdAt: json['created_at'],
      registradoPor: json['registradoPor'] != null
          ? PersonaRegistro.fromJson(json['registradoPor'])
          : null,
    );
  }

  bool get estaActiva {
    if (fechaFin == null) return true;
    try {
      return DateTime.parse(fechaFin!).isAfter(DateTime.now());
    } catch (_) {
      return true;
    }
  }

  DateTime? get fechaParsed {
    if (fecha == null) return null;
    try {
      return DateTime.parse(fecha!);
    } catch (_) {
      return null;
    }
  }

  DateTime? get fechaFinParsed {
    if (fechaFin == null) return null;
    try {
      return DateTime.parse(fechaFin!);
    } catch (_) {
      return null;
    }
  }
}

class PersonaRegistro {
  final int id;
  final String? email;
  final String? nombre1;
  final String? apellido1;
  final String? rutaFotoUrl;

  PersonaRegistro({
    required this.id,
    this.email,
    this.nombre1,
    this.apellido1,
    this.rutaFotoUrl,
  });

  factory PersonaRegistro.fromJson(Map<String, dynamic> json) {
    final persona = json['persona'] as Map<String, dynamic>?;
    return PersonaRegistro(
      id: json['id'],
      email: json['email'],
      nombre1: persona?['nombre1'],
      apellido1: persona?['apellido1'],
      rutaFotoUrl: persona?['rutaFotoUrl'],
    );
  }

  String get nombreCompleto => '${nombre1 ?? ''} ${apellido1 ?? ''}'.trim();
}
