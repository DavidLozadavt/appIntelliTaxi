class EmergenciaModel {
  final int id;
  final int? idConductor;
  final int? idVehiculo;
  final int? idTurno;
  final int? idEmpresa;

  final double lat;
  final double lng;

  final String tipo;
  final String? mensaje;
  final String? descripcion;
  final String estado;

  final String? direccionCompleta;
  final String? barrio;
  final String? mapsUrl;
  final String? conductorNombre;
  final String? conductorTelefono;
  final String? placa;

  final DateTime? createdAt;

  EmergenciaModel({
    required this.id,
    this.idConductor,
    this.idVehiculo,
    this.idTurno,
    this.idEmpresa,
    required this.lat,
    required this.lng,
    required this.tipo,
    this.mensaje,
    this.descripcion,
    required this.estado,
    this.direccionCompleta,
    this.barrio,
    this.mapsUrl,
    this.conductorNombre,
    this.conductorTelefono,
    this.placa,
    this.createdAt,
  });

  String get tituloUbicacion {
    if (barrio != null && barrio!.trim().isNotEmpty) return barrio!.trim();
    if (direccionCompleta != null && direccionCompleta!.trim().isNotEmpty) {
      return direccionCompleta!.trim();
    }
    return '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}';
  }

  String get subtituloUbicacion {
    if (direccionCompleta != null &&
        barrio != null &&
        direccionCompleta!.trim().isNotEmpty &&
        !direccionCompleta!.trim().toLowerCase().contains(
          barrio!.trim().toLowerCase(),
        )) {
      return direccionCompleta!.trim();
    }
    return direccionCompleta?.trim() ?? '';
  }

  String get urlMaps =>
      mapsUrl?.trim().isNotEmpty == true
          ? mapsUrl!.trim()
          : 'https://www.google.com/maps/search/?api=1&query=$lat,$lng';

  bool get isActiva {
    final e = estado.toLowerCase();
    return e != 'finalizada' && e != 'cerrada' && e != 'cancelada';
  }

  factory EmergenciaModel.fromJson(Map<String, dynamic> json) {
    final nested = json['data'] is Map
        ? Map<String, dynamic>.from(json['data'] as Map)
        : null;
    final src = nested ?? json;

    return EmergenciaModel(
      id: _asInt(src['id']) ?? 0,
      idConductor: _asInt(src['idConductor'] ?? src['id_conductor']),
      idVehiculo: _asInt(src['idVehiculo'] ?? src['id_vehiculo']),
      idTurno: _asInt(src['idTurno'] ?? src['id_turno']),
      idEmpresa: _asInt(src['idEmpresa'] ?? src['id_empresa']),
      lat: _asDouble(src['lat']) ?? 0,
      lng: _asDouble(src['lng']) ?? 0,
      tipo: src['tipo']?.toString() ?? 'EMERGENCIA',
      mensaje: src['mensaje']?.toString() ?? src['descripcion']?.toString(),
      descripcion: src['descripcion']?.toString(),
      estado: src['estado']?.toString() ?? 'activa',
      direccionCompleta: src['direccion_completa']?.toString() ??
          src['direccionCompleta']?.toString() ??
          src['direccion']?.toString(),
      barrio: src['barrio']?.toString(),
      mapsUrl: src['maps_url']?.toString() ?? src['mapsUrl']?.toString(),
      conductorNombre: src['conductor_nombre']?.toString() ??
          src['conductorNombre']?.toString(),
      conductorTelefono: src['conductor_telefono']?.toString() ??
          src['conductorTelefono']?.toString(),
      placa: src['placa']?.toString() ?? src['vehiculo_placa']?.toString(),
      createdAt: _parseDate(src['created_at'] ?? src['createdAt']),
    );
  }

  static int? _asInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    return int.tryParse(v.toString());
  }

  static double? _asDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString().replaceAll(',', '.'));
  }

  static DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    return DateTime.tryParse(v.toString());
  }
}
