import 'package:intellitaxi/core/geo/map_marker_bearing_helper.dart';

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
  /// Rumbo GPS en grados (0–360), campo `direccion` del backend.
  final double? rumbo;

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
    this.rumbo,
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
      conductorId: _asInt(conductorId),
      nombre: nombre,
      telefono: json['telefono'] ?? json['conductor_telefono'],
      foto: foto,
      calificacion: _asDouble(calificacion, 5.0),
      lat: _asDouble(lat),
      lng: _asDouble(lng),
      vehiculo: vehiculo,
      distanciaKm: json['distancia_km'] != null
          ? _asDouble(json['distancia_km'])
          : null,
      estado: json['estado'] ?? 'disponible',
      rumbo: MapMarkerBearingHelper.parseRumbo(
        json['direccion'] ?? json['bearing'] ?? json['heading'] ?? json['rumbo'],
      ),
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

int _asInt(dynamic value, [int fallback = 0]) {
  if (value == null) return fallback;
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) {
    final parsed = int.tryParse(value.trim());
    if (parsed != null) return parsed;
  }
  return fallback;
}

double _asDouble(dynamic value, [double fallback = 0.0]) {
  if (value == null) return fallback;
  if (value is double) return value;
  if (value is num) return value.toDouble();
  if (value is String) {
    final normalized = value.trim().replaceAll(',', '.');
    final parsed = double.tryParse(normalized);
    if (parsed != null) return parsed;
  }
  return fallback;
}
