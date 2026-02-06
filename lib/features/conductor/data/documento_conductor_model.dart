class DocumentoConductor {
  final int id;
  final String fechaCarga;
  final String ruta;
  final int idConductor;
  final int idTipoDocumento;
  final String? fechaVigencia;
  final String createdAt;
  final String updatedAt;
  final int idEstado;
  final String? numeroDocumento;
  final String rutaUrl;
  final TipoDocumento tipoDocumento;
  // Nuevos campos del endpoint de alertas
  final String? fechaActual;
  final int? diasRestantesCalculados;
  final String? estadoVigencia;
  final String? mensajeAlerta;

  DocumentoConductor({
    required this.id,
    required this.fechaCarga,
    required this.ruta,
    required this.idConductor,
    required this.idTipoDocumento,
    this.fechaVigencia,
    required this.createdAt,
    required this.updatedAt,
    required this.idEstado,
    this.numeroDocumento,
    required this.rutaUrl,
    required this.tipoDocumento,
    this.fechaActual,
    this.diasRestantesCalculados,
    this.estadoVigencia,
    this.mensajeAlerta,
  });

  factory DocumentoConductor.fromJson(Map<String, dynamic> json) {
    return DocumentoConductor(
      id: json['id'],
      fechaCarga: json['fechaCarga']?.toString() ?? '',
      ruta: json['ruta']?.toString() ?? '',
      idConductor: json['idConductor'],
      idTipoDocumento: json['idTipoDocumento'],
      fechaVigencia: json['fecha_vigencia']?.toString(),
      createdAt: json['created_at']?.toString() ?? '',
      updatedAt: json['updated_at']?.toString() ?? '',
      idEstado: json['idEstado'],
      numeroDocumento: json['numeroDocumento']?.toString(),
      rutaUrl: json['rutaUrl']?.toString() ?? '',
      tipoDocumento: TipoDocumento.fromJson(json['tipo_documento']),
      fechaActual: json['fecha_actual']?.toString(),
      diasRestantesCalculados: json['dias_restantes'],
      estadoVigencia: json['estado_vigencia']?.toString(),
      mensajeAlerta: json['mensaje_alerta']?.toString(),
    );
  }

  /// Calcula los días restantes hasta que venza el documento
  int? get diasRestantes {
    if (fechaVigencia == null) return null;
    try {
      final vigencia = DateTime.parse(fechaVigencia!);
      final ahora = DateTime.now();
      return vigencia.difference(ahora).inDays;
    } catch (e) {
      return null;
    }
  }

  /// Verifica si el documento está por vencer (usa el estado del servidor si está disponible)
  bool get estaPorVencer {
    if (estadoVigencia != null) {
      return estadoVigencia!.toUpperCase() == 'POR VENCER';
    }
    final dias = diasRestantes;
    return dias != null && dias > 0 && dias <= 15;
  }

  /// Verifica si el documento está vencido (usa el estado del servidor si está disponible)
  bool get estaVencido {
    if (estadoVigencia != null) {
      return estadoVigencia!.toUpperCase() == 'VENCIDO';
    }
    final dias = diasRestantes;
    return dias != null && dias < 0;
  }
}

class TipoDocumento {
  final int id;
  final String tituloDocumento;
  final String descripcion;
  final int idEstado;
  final String? createdAt;
  final String? updatedAt;
  final String? tipoFecha;

  TipoDocumento({
    required this.id,
    required this.tituloDocumento,
    required this.descripcion,
    required this.idEstado,
    this.createdAt,
    this.updatedAt,
    this.tipoFecha,
  });

  factory TipoDocumento.fromJson(Map<String, dynamic> json) {
    return TipoDocumento(
      id: json['id'],
      tituloDocumento: json['tituloDocumento']?.toString() ?? '',
      descripcion: json['descripcion']?.toString() ?? '',
      idEstado: json['idEstado'],
      createdAt: json['created_at']?.toString(),
      updatedAt: json['updated_at']?.toString(),
      tipoFecha: json['tipoFecha']?.toString(),
    );
  }
}
