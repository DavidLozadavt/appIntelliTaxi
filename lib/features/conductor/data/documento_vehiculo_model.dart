class DocumentoVehiculo {
  final int id;
  final int idVehiculo;
  final int idTipoDocumento;
  final String? fechaVigencia;
  final String? fechaFinVigencia;
  final String? rutaUrl;
  final String tituloDocumento;

  DocumentoVehiculo({
    required this.id,
    required this.idVehiculo,
    required this.idTipoDocumento,
    required this.fechaVigencia,
    required this.fechaFinVigencia,
    required this.rutaUrl,
    required this.tituloDocumento,
  });

  factory DocumentoVehiculo.fromJson(Map<String, dynamic> json) {
    final tipoDoc = json['tipo_documento'];
    return DocumentoVehiculo(
      id: _asInt(json['id']),
      idVehiculo: _asInt(json['idVehiculo']),
      idTipoDocumento: _asInt(json['idTipoDocumento']),
      fechaVigencia: json['fecha_vigencia']?.toString(),
      fechaFinVigencia: json['fecha_fin_vigencia']?.toString(),
      rutaUrl: json['rutaUrl']?.toString(),
      tituloDocumento: tipoDoc is Map<String, dynamic>
          ? (tipoDoc['tituloDocumento']?.toString() ?? 'Documento')
          : 'Documento',
    );
  }

  static int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  String? get fechaVigenciaDisplay => fechaFinVigencia ?? fechaVigencia;

  DateTime? get fechaVigenciaDate {
    final value = fechaVigenciaDisplay;
    if (value == null || value.trim().isEmpty) return null;
    return DateTime.tryParse(value);
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
