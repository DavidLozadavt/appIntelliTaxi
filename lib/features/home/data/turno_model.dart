import 'vehiculo_conductor_model.dart';

class TurnoActivo {
  final int id;
  final int idConductor;
  final int idVehiculo;
  final String fechaTurno;
  final String horaInicio;
  final String? horaFin;
  final String estado;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final VehiculoConductor? vehiculo;

  TurnoActivo({
    required this.id,
    required this.idConductor,
    required this.idVehiculo,
    required this.fechaTurno,
    required this.horaInicio,
    this.horaFin,
    required this.estado,
    this.createdAt,
    this.updatedAt,
    this.vehiculo,
  });

  factory TurnoActivo.fromJson(Map<String, dynamic> json) {
    return TurnoActivo(
      id: json['id'] ?? 0,
      idConductor: json['idConductor'] ?? 0,
      idVehiculo: json['idVehiculo'] ?? 0,
      fechaTurno: json['fechaTurno']?.toString() ?? '',
      horaInicio: json['horaInicio']?.toString() ?? '',
      horaFin: json['horaFin']?.toString(),
      estado: json['estado']?.toString() ?? '',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
      vehiculo: json['vehiculo'] != null
          ? VehiculoConductor.fromJson(json['vehiculo'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'idConductor': idConductor,
      'idVehiculo': idVehiculo,
      'fechaTurno': fechaTurno,
      'horaInicio': horaInicio,
      'horaFin': horaFin,
      'estado': estado,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'vehiculo': vehiculo?.toJson(),
    };
  }

  bool get estaActivo => estado == 'ACTIVO' && horaFin == null;
}
