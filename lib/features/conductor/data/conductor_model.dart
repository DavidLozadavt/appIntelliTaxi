class Conductor {
  final int conductorId;
  final String nombre;
  final String? telefono;
  final String? foto;
  final double calificacion;
  final double lat;
  final double lng;
  final Vehiculo? vehiculo;
  final double? distanciaKm;
  final String? estado;

  Conductor({
    required this.conductorId,
    required this.nombre,
    this.telefono,
    this.foto,
    required this.calificacion,
    required this.lat,
    required this.lng,
    this.vehiculo,
    this.distanciaKm,
    this.estado,
  });

  factory Conductor.fromJson(Map<String, dynamic> json) {
    // Manejar diferentes formatos de respuesta del backend
    final conductorId = json['conductor_id'] ?? json['id'];
    final nombre = json['conductor_nombre'] ?? json['nombre'];
    final foto = json['conductor_foto'] ?? json['foto'];
    final calificacion = json['calificacion'];

    // Latitud y longitud pueden venir en diferentes formatos
    final lat = json['latitud'] ?? json['lat'] ?? json['ubicacion']?['lat'];
    final lng = json['longitud'] ?? json['lng'] ?? json['ubicacion']?['lng'];

    // Datos del vehículo pueden venir directamente o anidados
    Vehiculo? vehiculo;
    if (json['vehiculo'] != null) {
      vehiculo = Vehiculo.fromJson(json['vehiculo']);
    } else if (json['vehiculo_marca'] != null ||
        json['vehiculo_placa'] != null) {
      vehiculo = Vehiculo(
        marca: json['vehiculo_marca'],
        modelo: json['vehiculo_modelo'],
        placa: json['vehiculo_placa'],
        color: json['vehiculo_color'],
      );
    }

    return Conductor(
      conductorId: conductorId,
      nombre: nombre,
      telefono: json['telefono'] ?? json['conductor_telefono'],
      foto: foto,
      calificacion: calificacion != null
          ? (calificacion is String
                ? double.parse(calificacion)
                : calificacion.toDouble())
          : 5.0,
      lat: lat != null
          ? (lat is String ? double.parse(lat) : lat.toDouble())
          : 0.0,
      lng: lng != null
          ? (lng is String ? double.parse(lng) : lng.toDouble())
          : 0.0,
      vehiculo: vehiculo,
      distanciaKm: json['distancia_km']?.toDouble(),
      estado: json['estado'] ?? 'disponible',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'conductor_id': conductorId,
      'nombre': nombre,
      'telefono': telefono,
      'foto': foto,
      'calificacion': calificacion,
      'lat': lat,
      'lng': lng,
      'vehiculo': vehiculo?.toJson(),
      'distancia_km': distanciaKm,
      'estado': estado,
    };
  }
}

class Vehiculo {
  final String? marca;
  final String? modelo;
  final String? placa;
  final String? color;

  Vehiculo({this.marca, this.modelo, this.placa, this.color});

  factory Vehiculo.fromJson(Map<String, dynamic> json) {
    return Vehiculo(
      marca: json['marca'],
      modelo: json['modelo'],
      placa: json['placa'],
      color: json['color'],
    );
  }

  Map<String, dynamic> toJson() {
    return {'marca': marca, 'modelo': modelo, 'placa': placa, 'color': color};
  }

  String get descripcion {
    final parts = <String>[];
    if (marca != null && marca!.isNotEmpty) parts.add(marca!);
    if (modelo != null && modelo!.isNotEmpty) parts.add(modelo!);
    if (placa != null && placa!.isNotEmpty) parts.add(placa!);

    return parts.isEmpty ? 'Vehículo' : parts.join(' ');
  }
}
