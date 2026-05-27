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
  final String? imagenUrl;
  final String? caption;
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
    this.imagenUrl,
    this.caption,
    required this.leido,
    this.fechaLectura,
    required this.createdAt,
  });

  bool get esImagen => tipo == 'imagen';
  bool get esTexto => tipo == 'texto';

  String get textoVista {
    if (esImagen) {
      if (caption != null && caption!.trim().isNotEmpty) return caption!.trim();
      return '📷 Imagen';
    }
    return mensaje;
  }

  factory MensajeTaxi.fromJson(Map<String, dynamic> json) {
    return MensajeTaxi(
      id: _toInt(json['id']),
      servicioId: _toInt(json['servicio_id']),
      remitenteId: _toInt(json['remitente_id']),
      remitenteNombre: json['remitente_nombre'] ?? 'Usuario',
      remitenteFoto: json['remitente_foto'],
      destinatarioId: _toInt(json['destinatario_id']),
      mensaje: json['mensaje']?.toString() ?? '',
      tipo: json['tipo']?.toString() ?? 'texto',
      imagenUrl: json['imagen_url']?.toString(),
      caption: json['caption']?.toString(),
      leido: json['leido'] == true,
      fechaLectura: json['fecha_lectura'] != null
          ? DateTime.tryParse(json['fecha_lectura'].toString())
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  /// Factory para mensajes que llegan por Pusher
  factory MensajeTaxi.fromPusher(Map<String, dynamic> json) {
    return MensajeTaxi(
      id: _toInt(json['id']),
      servicioId: _toInt(json['servicio_id']),
      remitenteId: _toInt(json['remitente_id']),
      remitenteNombre: json['remitente_nombre'] ?? 'Usuario',
      remitenteFoto: json['remitente_foto'],
      destinatarioId: _toInt(json['destinatario_id']),
      mensaje: json['mensaje']?.toString() ?? '',
      tipo: json['tipo']?.toString() ?? 'texto',
      imagenUrl: json['imagen_url']?.toString(),
      caption: json['caption']?.toString(),
      leido: false,
      fechaLectura: null,
      createdAt: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'].toString()) ?? DateTime.now()
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
      'imagen_url': imagenUrl,
      'caption': caption,
      'leido': leido,
      'fecha_lectura': fechaLectura?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }

  MensajeTaxi copyWith({
    int? id,
    int? servicioId,
    int? remitenteId,
    String? remitenteNombre,
    String? remitenteFoto,
    int? destinatarioId,
    String? mensaje,
    String? tipo,
    String? imagenUrl,
    String? caption,
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
      imagenUrl: imagenUrl ?? this.imagenUrl,
      caption: caption ?? this.caption,
      leido: leido ?? this.leido,
      fechaLectura: fechaLectura ?? this.fechaLectura,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

int _toInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}
