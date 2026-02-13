// lib/features/chat/data/mensaje_taxi_model.dart

class MensajeTaxi {
  final int id;
  final int servicioId;
  final int remitenteId;
  final String remitenteNombre;
  final String? remitenteFoto;
  final int destinatarioId;
  final String mensaje;
  final String tipo;
  final bool leido;
  final DateTime? fechaLectura;
  final DateTime createdAt;

  MensajeTaxi({
    required this.id,
    required this.servicioId,
    required this.remitenteId,
    required this.remitenteNombre,
    this.remitenteFoto,
    required this.destinatarioId,
    required this.mensaje,
    required this.tipo,
    required this.leido,
    this.fechaLectura,
    required this.createdAt,
  });

  factory MensajeTaxi.fromJson(Map<String, dynamic> json) {
    return MensajeTaxi(
      id: json['id'] ?? 0,
      servicioId: json['servicio_id'] ?? 0,
      remitenteId: json['remitente_id'] ?? 0,
      remitenteNombre: json['remitente_nombre'] ?? 'Usuario',
      remitenteFoto: json['remitente_foto'],
      destinatarioId: json['destinatario_id'] ?? 0,
      mensaje: json['mensaje'] ?? '',
      tipo: json['tipo'] ?? 'texto',
      leido: json['leido'] ?? false,
      fechaLectura: json['fecha_lectura'] != null
          ? DateTime.tryParse(json['fecha_lectura'])
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at']) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  /// Factory para mensajes que llegan por Pusher
  factory MensajeTaxi.fromPusher(Map<String, dynamic> json) {
    return MensajeTaxi(
      id: json['id'] ?? 0,
      servicioId: json['servicio_id'] ?? 0,
      remitenteId: json['remitente_id'] ?? 0,
      remitenteNombre: json['remitente_nombre'] ?? 'Usuario',
      remitenteFoto: json['remitente_foto'],
      destinatarioId: json['destinatario_id'] ?? 0,
      mensaje: json['mensaje'] ?? '',
      tipo: json['tipo'] ?? 'texto',
      leido: false,
      fechaLectura: null,
      createdAt: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp']) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'servicio_id': servicioId,
      'remitente_id': remitenteId,
      'remitente_nombre': remitenteNombre,
      'remitente_foto': remitenteFoto,
      'destinatario_id': destinatarioId,
      'mensaje': mensaje,
      'tipo': tipo,
      'leido': leido,
      'fecha_lectura': fechaLectura?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }

  /// Copia con modificaciones
  MensajeTaxi copyWith({
    int? id,
    int? servicioId,
    int? remitenteId,
    String? remitenteNombre,
    String? remitenteFoto,
    int? destinatarioId,
    String? mensaje,
    String? tipo,
    bool? leido,
    DateTime? fechaLectura,
    DateTime? createdAt,
  }) {
    return MensajeTaxi(
      id: id ?? this.id,
      servicioId: servicioId ?? this.servicioId,
      remitenteId: remitenteId ?? this.remitenteId,
      remitenteNombre: remitenteNombre ?? this.remitenteNombre,
      remitenteFoto: remitenteFoto ?? this.remitenteFoto,
      destinatarioId: destinatarioId ?? this.destinatarioId,
      mensaje: mensaje ?? this.mensaje,
      tipo: tipo ?? this.tipo,
      leido: leido ?? this.leido,
      fechaLectura: fechaLectura ?? this.fechaLectura,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
