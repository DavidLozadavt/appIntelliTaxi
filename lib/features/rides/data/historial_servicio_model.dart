/// Helper para parsear valores que pueden venir como string o número a double
double _parseDouble(dynamic value) {
  if (value == null) return 0.0;
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is String) {
    return double.tryParse(value) ?? 0.0;
  }
  return 0.0;
}

/// Modelo para el historial de servicios
class HistorialServicio {
  final int id;
  final DateTime fechaServicio;
  final DateTime? finServicio;
  final int? duracionMinutos;
  final UbicacionServicio origen;
  final UbicacionServicio destino;
  final String? distancia;
  final double precioEstimado;
  final double? precioFinal;
  final String estado;
  final PersonaServicio? persona; // Conductor o Pasajero según el contexto
  final VehiculoServicio? vehiculo;
  final CalificacionServicioHistorial? calificacion;

  HistorialServicio({
    required this.id,
    required this.fechaServicio,
    this.finServicio,
    this.duracionMinutos,
    required this.origen,
    required this.destino,
    this.distancia,
    required this.precioEstimado,
    this.precioFinal,
    required this.estado,
    this.persona,
    this.vehiculo,
    this.calificacion,
  });

  factory HistorialServicio.fromJson(Map<String, dynamic> json) {
    return HistorialServicio(
      id: json['id'] ?? 0,
      fechaServicio: json['fecha_servicio'] != null
          ? DateTime.parse(json['fecha_servicio'])
          : DateTime.now(),
      finServicio: json['fin_servicio'] != null
          ? DateTime.parse(json['fin_servicio'])
          : null,
      duracionMinutos: json['duracion_minutos'],
      origen: UbicacionServicio.fromJson(json['origen'] ?? {}),
      destino: UbicacionServicio.fromJson(json['destino'] ?? {}),
      distancia: json['distancia'],
      precioEstimado: _parseDouble(json['precio_estimado']),
      precioFinal: json['precio_final'] != null
          ? _parseDouble(json['precio_final'])
          : null,
      estado: json['estado'] ?? '',
      persona: json['pasajero'] != null
          ? PersonaServicio.fromJson(json['pasajero'])
          : (json['conductor'] != null
                ? PersonaServicio.fromJson(json['conductor'])
                : null),
      vehiculo: json['conductor']?['vehiculo'] != null
          ? VehiculoServicio.fromJson(json['conductor']['vehiculo'])
          : null,
      calificacion: json['calificacion'] != null
          ? CalificacionServicioHistorial.fromJson(json['calificacion'])
          : (json['calificacion_dada'] != null
                ? CalificacionServicioHistorial.fromJson(
                    json['calificacion_dada'],
                  )
                : null),
    );
  }

  String get duracionTexto {
    if (duracionMinutos == null) return 'N/A';
    if (duracionMinutos! < 60) return '$duracionMinutos min';
    final horas = duracionMinutos! ~/ 60;
    final mins = duracionMinutos! % 60;
    return '${horas}h ${mins}min';
  }

  String get precioFinalFormateado {
    final precio = precioFinal ?? precioEstimado;
    return '\$${precio.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}';
  }
}

/// Ubicación (origen o destino) de un servicio
class UbicacionServicio {
  final String direccion;
  final String? nombre;
  final double? lat;
  final double? lng;

  UbicacionServicio({required this.direccion, this.nombre, this.lat, this.lng});

  factory UbicacionServicio.fromJson(Map<String, dynamic> json) {
    return UbicacionServicio(
      direccion: json['direccion'] ?? '',
      nombre: json['nombre'],
      lat: json['lat'] != null ? _parseDouble(json['lat']) : null,
      lng: json['lng'] != null ? _parseDouble(json['lng']) : null,
    );
  }

  String get nombreODireccion => nombre ?? direccion;
}

/// Información de persona (conductor o pasajero)
class PersonaServicio {
  final int id;
  final String nombre;
  final String? telefono;
  final String? fotoPerfil;
  final double? calificacionPromedio;

  PersonaServicio({
    required this.id,
    required this.nombre,
    this.telefono,
    this.fotoPerfil,
    this.calificacionPromedio,
  });

  factory PersonaServicio.fromJson(Map<String, dynamic> json) {
    return PersonaServicio(
      id: json['id'] ?? 0,
      nombre: json['nombre'] ?? 'Sin nombre',
      telefono: json['telefono'],
      fotoPerfil: json['foto_perfil'],
      calificacionPromedio: json['calificacion_promedio'] != null
          ? _parseDouble(json['calificacion_promedio'])
          : null,
    );
  }
}

/// Información del vehículo
class VehiculoServicio {
  final String placa;
  final String marca;
  final String modelo;
  final String color;

  VehiculoServicio({
    required this.placa,
    required this.marca,
    required this.modelo,
    required this.color,
  });

  factory VehiculoServicio.fromJson(Map<String, dynamic> json) {
    return VehiculoServicio(
      placa: json['placa'] ?? '',
      marca: json['marca'] ?? '',
      modelo: json['modelo'] ?? '',
      color: json['color'] ?? '',
    );
  }

  String get descripcion => '$marca $modelo $color';
}

/// Calificación asociada al servicio
class CalificacionServicioHistorial {
  final int puntuacion;
  final String? comentario;
  final DateTime? fecha;

  CalificacionServicioHistorial({
    required this.puntuacion,
    this.comentario,
    this.fecha,
  });

  factory CalificacionServicioHistorial.fromJson(Map<String, dynamic> json) {
    return CalificacionServicioHistorial(
      puntuacion: json['puntuacion'] ?? json['calificacion'] ?? 0,
      comentario: json['comentario'],
      fecha: json['fecha'] != null ? DateTime.parse(json['fecha']) : null,
    );
  }
}

/// Respuesta paginada del historial
class HistorialResponse {
  final List<HistorialServicio> servicios;
  final PaginacionInfo paginacion;

  HistorialResponse({required this.servicios, required this.paginacion});

  factory HistorialResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as List? ?? [];
    return HistorialResponse(
      servicios: data.map((item) => HistorialServicio.fromJson(item)).toList(),
      paginacion: PaginacionInfo.fromJson(json['pagination'] ?? {}),
    );
  }
}

/// Información de paginación
class PaginacionInfo {
  final int total;
  final int perPage;
  final int currentPage;
  final int lastPage;

  PaginacionInfo({
    required this.total,
    required this.perPage,
    required this.currentPage,
    required this.lastPage,
  });

  factory PaginacionInfo.fromJson(Map<String, dynamic> json) {
    return PaginacionInfo(
      total: json['total'] ?? 0,
      perPage: json['per_page'] ?? 20,
      currentPage: json['current_page'] ?? 1,
      lastPage: json['last_page'] ?? 1,
    );
  }

  bool get hasNextPage => currentPage < lastPage;
  bool get hasPreviousPage => currentPage > 1;
}

/// Estadísticas de servicios
class EstadisticasServicios {
  final int totalServicios;
  final double? totalIngresos;
  final double? promedioCalificacion;
  final int? totalCalificaciones;
  final Map<String, int>? distribucionCalificaciones;
  final double? tiempoPromedioMinutos;
  final double? distanciaTotalKm;

  EstadisticasServicios({
    required this.totalServicios,
    this.totalIngresos,
    this.promedioCalificacion,
    this.totalCalificaciones,
    this.distribucionCalificaciones,
    this.tiempoPromedioMinutos,
    this.distanciaTotalKm,
  });

  factory EstadisticasServicios.fromJson(Map<String, dynamic> json) {
    final data = json['data'] ?? json;

    Map<String, int>? distribucion;
    if (data['distribucion_calificaciones'] != null) {
      final dist = data['distribucion_calificaciones'] as Map;
      distribucion = dist.map(
        (key, value) => MapEntry(key.toString(), value as int),
      );
    }

    return EstadisticasServicios(
      totalServicios: data['total_servicios'] ?? 0,
      totalIngresos: data['ingresos_totales'] != null
          ? _parseDouble(data['ingresos_totales'])
          : (data['gasto_total'] != null
                ? _parseDouble(data['gasto_total'])
                : null),
      promedioCalificacion: data['promedio_calificacion'] != null
          ? _parseDouble(data['promedio_calificacion'])
          : null,
      totalCalificaciones: data['total_calificaciones'],
      distribucionCalificaciones: distribucion,
      tiempoPromedioMinutos: data['tiempo_promedio_servicio_minutos'] != null
          ? _parseDouble(data['tiempo_promedio_servicio_minutos'])
          : null,
      distanciaTotalKm: data['distancia_total_km'] != null
          ? _parseDouble(data['distancia_total_km'])
          : null,
    );
  }

  String get ingresosFormateado {
    if (totalIngresos == null) return '\$0';
    return '\$${totalIngresos!.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}';
  }
}
