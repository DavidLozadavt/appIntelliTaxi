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

  /// Verifica si el documento está por vencer (menos de 30 días)
  bool get estaPorVencer {
    final dias = diasRestantes;
    return dias != null && dias > 0 && dias <= 30;
  }

  /// Verifica si el documento está vencido
  bool get estaVencido {
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
