class DocumentoVehiculo {
  final int id;
  final int idVehiculo;
  final int idTipoDocumento;
  final String? fechaVigencia;
  final String? rutaUrl;
  final String tituloDocumento;

  DocumentoVehiculo({
    required this.id,
    required this.idVehiculo,
    required this.idTipoDocumento,
    required this.fechaVigencia,
    required this.rutaUrl,
    required this.tituloDocumento,
  });

  factory DocumentoVehiculo.fromJson(Map<String, dynamic> json) {
    final tipoDoc = json['tipo_documento'];
    return DocumentoVehiculo(
      id: json['id'] ?? 0,
      idVehiculo: json['idVehiculo'] ?? 0,
      idTipoDocumento: json['idTipoDocumento'] ?? 0,
      fechaVigencia: json['fecha_vigencia']?.toString(),
      rutaUrl: json['rutaUrl']?.toString(),
      tituloDocumento: tipoDoc is Map<String, dynamic>
          ? (tipoDoc['tituloDocumento']?.toString() ?? 'Documento')
          : 'Documento',
    );
  }

  DateTime? get fechaVigenciaDate {
    if (fechaVigencia == null || fechaVigencia!.trim().isEmpty) return null;
    return DateTime.tryParse(fechaVigencia!);
  }

  int? get diasRestantes {
    final fecha = fechaVigenciaDate;
    if (fecha == null) return null;
    final hoy = DateTime.now();
    final vigencia = DateTime(fecha.year, fecha.month, fecha.day);
    final actual = DateTime(hoy.year, hoy.month, hoy.day);
    return vigencia.difference(actual).inDays;
  }

  bool get estaVencido {
    final dias = diasRestantes;
    return dias != null && dias < 0;
  }

  bool get estaPorVencer {
    final dias = diasRestantes;
    return dias != null && dias >= 0 && dias <= 15;
  }
}
