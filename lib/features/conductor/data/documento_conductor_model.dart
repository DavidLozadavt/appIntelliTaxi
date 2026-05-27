import 'package:intellitaxi/features/conductor/utils/documento_tipo_fecha_helper.dart';

class DocumentoConductor {
  final int id;
  final String fechaCarga;
  final String ruta;
  final int idConductor;
  final int idTipoDocumento;
  final String? fechaVigencia;
  final String? fechaFinVigencia;
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
  final bool diligenciado;

  DocumentoConductor({
    required this.id,
    required this.fechaCarga,
    required this.ruta,
    required this.idConductor,
    required this.idTipoDocumento,
    this.fechaVigencia,
    this.fechaFinVigencia,
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
    this.diligenciado = false,
  });

  factory DocumentoConductor.fromJson(Map<String, dynamic> json) {
    final tipoDocumentoJson = json['tipo_documento'] ?? json['tipoDocumento'];
    return DocumentoConductor(
      id: _asInt(json['id']),
      fechaCarga: json['fechaCarga']?.toString() ?? '',
      ruta: json['ruta']?.toString() ?? '',
      idConductor: _asInt(json['idConductor']),
      idTipoDocumento: _asInt(json['idTipoDocumento']),
      fechaVigencia: json['fecha_vigencia']?.toString(),
      fechaFinVigencia: json['fecha_fin_vigencia']?.toString(),
      createdAt: json['created_at']?.toString() ?? '',
      updatedAt: json['updated_at']?.toString() ?? '',
      idEstado: _asInt(json['idEstado']),
      numeroDocumento: json['numeroDocumento']?.toString(),
      rutaUrl: json['rutaUrl']?.toString() ?? '',
      tipoDocumento: tipoDocumentoJson is Map<String, dynamic>
          ? TipoDocumento.fromJson(tipoDocumentoJson)
          : TipoDocumento.empty(),
      fechaActual: json['fecha_actual']?.toString(),
      diasRestantesCalculados: _asNullableInt(json['dias_restantes']),
      estadoVigencia: json['estado_vigencia']?.toString(),
      mensajeAlerta: json['mensaje_alerta']?.toString(),
      diligenciado: _asBool(json['diligenciado']),
    );
  }

  static int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static int? _asNullableInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  static bool _asBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    final text = value?.toString().trim().toLowerCase();
    return text == 'true' || text == '1' || text == 'si' || text == 'sí';
  }

  bool get estaCargado =>
      diligenciado || id > 0 || ruta.isNotEmpty || rutaUrl.isNotEmpty;

  bool get requiereVigencia => DocumentoTipoFechaHelper.requiereControlVigencia(
        tipoFecha: tipoDocumento.tipoFecha,
        tituloDocumento: tipoDocumento.tituloDocumento,
      );

  String get etiquetaFecha => DocumentoTipoFechaHelper.etiquetaFecha(
        tipoFecha: tipoDocumento.tipoFecha,
      );

  String? get fechaVigenciaDisplay => fechaFinVigencia ?? fechaVigencia;

  /// Calcula los días restantes hasta que venza el documento
  int? get diasRestantes {
    if (!requiereVigencia) return null;
    final fecha = fechaVigenciaDisplay;
    if (fecha == null) return null;
    try {
      final vigencia = DateTime.parse(fecha);
      final ahora = DateTime.now();
      return vigencia.difference(ahora).inDays;
    } catch (e) {
      return null;
    }
  }

  /// Verifica si el documento está por vencer (usa el estado del servidor si está disponible)
  bool get estaPorVencer {
    if (!requiereVigencia) return false;
    if (estadoVigencia != null) {
      return estadoVigencia!.toUpperCase() == 'POR VENCER';
    }
    final dias = diasRestantes;
    return dias != null && dias > 0 && dias <= 15;
  }

  /// Verifica si el documento está vencido (usa el estado del servidor si está disponible)
  bool get estaVencido {
    if (!requiereVigencia) return false;
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

  factory TipoDocumento.empty() {
    return TipoDocumento(
      id: 0,
      tituloDocumento: 'Documento',
      descripcion: '',
      idEstado: 0,
    );
  }

  factory TipoDocumento.fromJson(Map<String, dynamic> json) {
    return TipoDocumento(
      id: DocumentoConductor._asInt(json['id']),
      tituloDocumento: json['tituloDocumento']?.toString() ?? '',
      descripcion: json['descripcion']?.toString() ?? '',
      idEstado: DocumentoConductor._asInt(json['idEstado']),
      createdAt: json['created_at']?.toString(),
      updatedAt: json['updated_at']?.toString(),
      tipoFecha: json['tipoFecha']?.toString(),
    );
  }
}
