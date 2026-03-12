/// Modelo de calificación de servicios
int _toInt(dynamic value) {
  if (value == null) return 0;
  if (value is int) return value;
  if (value is double) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

double _toDouble(dynamic value) {
  if (value == null) return 0.0;
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0.0;
  return 0.0;
}

class CalificacionServicio {
  final int id;
  final int idServicio;
  final int idUsuarioCalifica;
  final int idUsuarioCalificado;
  final String tipoCalificacion; // 'CONDUCTOR' o 'PASAJERO'
  final int calificacion; // 1 a 5 estrellas
  final String? comentario;
  final DateTime fechaCalificacion;
  final UsuarioCalifica? usuarioCalifica;
  final UsuarioCalificado? usuarioCalificado;

  CalificacionServicio({
    required this.id,
    required this.idServicio,
    required this.idUsuarioCalifica,
    required this.idUsuarioCalificado,
    required this.tipoCalificacion,
    required this.calificacion,
    this.comentario,
    required this.fechaCalificacion,
    this.usuarioCalifica,
    this.usuarioCalificado,
  });

  factory CalificacionServicio.fromJson(Map<String, dynamic> json) {
    final idServicioRaw = json['idServicio'] ?? json['id_servicio'];
    final idUsuarioCalificaRaw =
        json['idUsuarioCalifica'] ?? json['id_usuario_califica'];
    final idUsuarioCalificadoRaw =
        json['idUsuarioCalificado'] ?? json['id_usuario_calificado'];
    final tipoCalificacionRaw =
        json['tipoCalificacion'] ?? json['tipo_calificacion'];

    return CalificacionServicio(
      id: _toInt(json['id']),
      idServicio: _toInt(idServicioRaw),
      idUsuarioCalifica: _toInt(idUsuarioCalificaRaw),
      idUsuarioCalificado: _toInt(idUsuarioCalificadoRaw),
      tipoCalificacion: tipoCalificacionRaw?.toString() ?? '',
      calificacion: _toInt(json['calificacion']),
      comentario: json['comentario'],
      fechaCalificacion: json['fecha_calificacion'] != null
          ? DateTime.parse(json['fecha_calificacion'])
          : DateTime.now(),
      usuarioCalifica: json['usuarioCalifica'] != null
          ? UsuarioCalifica.fromJson(json['usuarioCalifica'])
          : null,
      usuarioCalificado: json['usuarioCalificado'] != null
          ? UsuarioCalificado.fromJson(json['usuarioCalificado'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'idServicio': idServicio,
      'idUsuarioCalifica': idUsuarioCalifica,
      'idUsuarioCalificado': idUsuarioCalificado,
      'tipoCalificacion': tipoCalificacion,
      'calificacion': calificacion,
      'comentario': comentario,
      'fecha_calificacion': fechaCalificacion.toIso8601String(),
    };
  }

  String get textoCalificacion {
    switch (calificacion) {
      case 1:
        return 'Muy malo';
      case 2:
        return 'Malo';
      case 3:
        return 'Regular';
      case 4:
        return 'Bueno';
      case 5:
        return 'Excelente';
      default:
        return '';
    }
  }
}

/// Usuario que realiza la calificación
class UsuarioCalifica {
  final int id;
  final String nombre;
  final String? email;

  UsuarioCalifica({required this.id, required this.nombre, this.email});

  factory UsuarioCalifica.fromJson(Map<String, dynamic> json) {
    return UsuarioCalifica(
      id: _toInt(json['id']),
      nombre: json['nombre'] ?? '',
      email: json['email'],
    );
  }
}

/// Usuario que recibe la calificación
class UsuarioCalificado {
  final int id;
  final String nombre;
  final String? email;

  UsuarioCalificado({required this.id, required this.nombre, this.email});

  factory UsuarioCalificado.fromJson(Map<String, dynamic> json) {
    return UsuarioCalificado(
      id: _toInt(json['id']),
      nombre: json['nombre'] ?? '',
      email: json['email'],
    );
  }
}

/// Estadísticas de calificaciones de un usuario
class EstadisticasCalificacion {
  final double promedio;
  final int total;
  final Map<String, int> distribucion;
  final List<CalificacionServicio> ultimasCalificaciones;

  EstadisticasCalificacion({
    required this.promedio,
    required this.total,
    required this.distribucion,
    required this.ultimasCalificaciones,
  });

  factory EstadisticasCalificacion.fromJson(Map<String, dynamic> json) {
    final estadisticas = json['estadisticas'] ?? {};
    final distribucion = estadisticas['distribucion'] ?? {};

    return EstadisticasCalificacion(
      promedio: _toDouble(estadisticas['promedio']),
      total: _toInt(estadisticas['total']),
      distribucion: {
        '5_estrellas': _toInt(distribucion['5_estrellas']),
        '4_estrellas': _toInt(distribucion['4_estrellas']),
        '3_estrellas': _toInt(distribucion['3_estrellas']),
        '2_estrellas': _toInt(distribucion['2_estrellas']),
        '1_estrella': _toInt(distribucion['1_estrella']),
      },
      ultimasCalificaciones: [],
    );
  }
}

/// Respuesta del endpoint de promedio
class PromedioCalificacion {
  final double promedio;
  final int totalCalificaciones;
  final String tipo;
  final List<CalificacionServicio> ultimasCalificaciones;

  PromedioCalificacion({
    required this.promedio,
    required this.totalCalificaciones,
    required this.tipo,
    required this.ultimasCalificaciones,
  });

  factory PromedioCalificacion.fromJson(Map<String, dynamic> json) {
    final data = json['data'] ?? json;
    final ultimas = data['ultimas_calificaciones'] as List? ?? [];

    return PromedioCalificacion(
      promedio: _toDouble(data['promedio']),
      totalCalificaciones: _toInt(data['total_calificaciones']),
      tipo: data['tipo'] ?? '',
      ultimasCalificaciones: ultimas
          .map((item) => CalificacionServicio.fromJson(item))
          .toList(),
    );
  }
}

/// Verificación de si puede calificar
class PuedeCalificar {
  final bool puedeCalificarConductor;
  final bool puedeCalificarPasajero;
  final Map<String, dynamic> servicio;

  PuedeCalificar({
    required this.puedeCalificarConductor,
    required this.puedeCalificarPasajero,
    required this.servicio,
  });

  factory PuedeCalificar.fromJson(Map<String, dynamic> json) {
    final data = json['data'] ?? json;

    return PuedeCalificar(
      puedeCalificarConductor: data['puede_calificar_conductor'] ?? false,
      puedeCalificarPasajero: data['puede_calificar_pasajero'] ?? false,
      servicio: data['servicio'] ?? {},
    );
  }
}
