import 'package:intellitaxi/features/conductor/utils/documento_tipo_fecha_helper.dart';

class DocumentoVehiculo {
  final int id;
  final int idVehiculo;
  final int idTipoDocumento;
  final String? fechaVigencia;
  final String? fechaFinVigencia;
  final String? rutaUrl;
  final String tituloDocumento;
  final String? tipoFecha;
  final bool diligenciado;

  DocumentoVehiculo({
    required this.id,
    required this.idVehiculo,
    required this.idTipoDocumento,
    required this.fechaVigencia,
    required this.fechaFinVigencia,
    required this.rutaUrl,
    required this.tituloDocumento,
    this.tipoFecha,
    this.diligenciado = false,
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
      tipoFecha: tipoDoc is Map<String, dynamic>
          ? tipoDoc['tipoFecha']?.toString()
          : null,
      diligenciado: _asBool(json['diligenciado']),
    );
  }

  static int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static bool _asBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    final text = value?.toString().trim().toLowerCase();
    return text == 'true' || text == '1' || text == 'si' || text == 'sí';
  }

  bool get estaCargado =>
      diligenciado || id > 0 || (rutaUrl != null && rutaUrl!.isNotEmpty);

  bool get requiereVigencia => DocumentoTipoFechaHelper.requiereControlVigencia(
        tipoFecha: tipoFecha,
        tituloDocumento: tituloDocumento,
      );

  String get etiquetaFecha =>
      DocumentoTipoFechaHelper.etiquetaFecha(tipoFecha: tipoFecha);

  String? get fechaReferenciaDisplay => fechaFinVigencia ?? fechaVigencia;

  /// Alias usado en formularios de edición.
  String? get fechaVigenciaDisplay => fechaReferenciaDisplay;

  DateTime? get fechaReferenciaDate {
    final value = fechaReferenciaDisplay;
    if (value == null || value.trim().isEmpty) return null;
    return DateTime.tryParse(value);
  }

  int? get diasRestantes {
    if (!requiereVigencia) return null;
    final fecha = fechaReferenciaDate;
    if (fecha == null) return null;
    final hoy = DateTime.now();
    final referencia = DateTime(fecha.year, fecha.month, fecha.day);
    final actual = DateTime(hoy.year, hoy.month, hoy.day);
    return referencia.difference(actual).inDays;
  }

  bool get estaVencido {
    if (!requiereVigencia) return false;
    final dias = diasRestantes;
    return dias != null && dias < 0;
  }

  bool get estaPorVencer {
    if (!requiereVigencia) return false;
    final dias = diasRestantes;
    return dias != null && dias >= 0 && dias <= 15;
  }

  String get estadoDisplay {
    if (!requiereVigencia) {
      return estaCargado ? 'Cargado' : 'Pendiente';
    }
    if (estaVencido) return 'Vencido';
    if (estaPorVencer) return 'Por vencer';
    return 'Vigente';
  }

  String get subtituloFecha {
    if (!requiereVigencia) {
      return DocumentoTipoFechaHelper.subtituloSinVigencia(
            tipoFecha: tipoFecha,
            fechaDisplay: fechaReferenciaDisplay,
          ) ??
          'Documento cargado';
    }
    final fecha = fechaReferenciaDisplay;
    if (fecha == null || fecha.isEmpty) {
      return 'Sin ${etiquetaFecha.toLowerCase()}';
    }
    return '$etiquetaFecha: $fecha';
  }
}
