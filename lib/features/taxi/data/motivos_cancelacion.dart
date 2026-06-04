class MotivoCancelacionChip {
  const MotivoCancelacionChip({
    required this.codigo,
    required this.etiqueta,
  });

  final String codigo;
  final String etiqueta;

  factory MotivoCancelacionChip.fromJson(Map<String, dynamic> json) {
    return MotivoCancelacionChip(
      codigo: json['codigo']?.toString() ?? '',
      etiqueta: json['etiqueta']?.toString() ?? '',
    );
  }
}

class MotivosCancelacionCatalog {
  const MotivosCancelacionCatalog({
    required this.motivoOpcional,
    required this.textoSinMotivo,
    required this.motivos,
  });

  final bool motivoOpcional;
  final String textoSinMotivo;
  final List<MotivoCancelacionChip> motivos;

  factory MotivosCancelacionCatalog.fromJson(Map<String, dynamic> json) {
    final list = json['motivos'] as List? ?? [];
    return MotivosCancelacionCatalog(
      motivoOpcional: json['motivo_opcional'] == true,
      textoSinMotivo:
          json['texto_sin_motivo']?.toString() ?? 'Cancelación directa',
      motivos: list
          .whereType<Map>()
          .map(
            (e) => MotivoCancelacionChip.fromJson(
              Map<String, dynamic>.from(e),
            ),
          )
          .where((m) => m.codigo.isNotEmpty)
          .toList(),
    );
  }

  static const fallback = MotivosCancelacionCatalog(
    motivoOpcional: true,
    textoSinMotivo: 'Cancelación directa',
    motivos: [],
  );
}

/// Resultado de la UI antes de llamar a `POST /taxi/servicio/cancelar`.
class CancelacionServicioSeleccion {
  const CancelacionServicioSeleccion({this.motivoCodigo, this.motivoTexto});

  final String? motivoCodigo;
  final String? motivoTexto;

  bool get tieneMotivo {
    final texto = motivoTexto?.trim();
    if (texto != null && texto.isNotEmpty) return true;
    final codigo = motivoCodigo?.trim();
    return codigo != null && codigo.isNotEmpty;
  }
}
