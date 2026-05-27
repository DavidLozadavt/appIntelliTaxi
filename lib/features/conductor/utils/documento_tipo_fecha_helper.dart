/// Reglas de `tipoFecha` del ERP para documentos de conductor/vehículo.
class DocumentoTipoFechaHelper {
  DocumentoTipoFechaHelper._();

  static String _norm(String? value) =>
      value?.trim().toUpperCase().replaceAll('Ó', 'O') ?? '';

  /// Documentos de identificación no usan vigencia en la app.
  static bool esDocumentoIdentificacion(String? tituloDocumento) {
    final titulo = _norm(tituloDocumento);
    return titulo.contains('IDENTIFICACION') ||
        titulo.contains('CEDULA') ||
        titulo.contains('C.C');
  }

  /// Si la fecha del documento debe evaluarse como vencimiento/vigencia.
  static bool requiereControlVigencia({
    String? tipoFecha,
    String? tituloDocumento,
  }) {
    if (esDocumentoIdentificacion(tituloDocumento)) return false;

    final tipo = _norm(tipoFecha);
    if (tipo.isEmpty) return true;

    const sinControl = {
      'N/A',
      'NA',
      'NO APLICA',
      'SIN FECHA',
      'FECHA EXPEDICION',
      'EXPEDICION',
      'FECHA CARGA',
      'CARGA',
    };
    if (sinControl.contains(tipo)) return false;
    if (tipo.contains('EXPEDIC')) return false;
    if (tipo.contains('CARGA') && !tipo.contains('VENC')) return false;

    const conControl = {
      'FECHA VIGENCIA',
      'FECHA VENCIMIENTO',
      'VENCIMIENTO',
      'VIGENCIA',
    };
    if (conControl.contains(tipo)) return true;
    if (tipo.contains('VENCIM') || tipo.contains('VIGENCIA')) return true;

    return true;
  }

  /// Etiqueta para mostrar en UI según el tipo de fecha del documento.
  static String etiquetaFecha({String? tipoFecha}) {
    final tipo = _norm(tipoFecha);
    if (tipo.contains('EXPEDIC')) return 'Expedición';
    if (tipo.contains('VENCIM')) return 'Vencimiento';
    if (tipo.contains('VIGENCIA')) return 'Vigencia';
    if (tipo.contains('CARGA')) return 'Fecha de carga';
    return 'Fecha';
  }

  /// Subtítulo cuando el documento no controla vigencia.
  static String? subtituloSinVigencia({
    required String? tipoFecha,
    required String? fechaDisplay,
  }) {
    if (fechaDisplay == null || fechaDisplay.trim().isEmpty) {
      return 'Documento cargado';
    }
    return '${etiquetaFecha(tipoFecha: tipoFecha)}: $fechaDisplay';
  }
}
