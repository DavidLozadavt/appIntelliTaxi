class EmergenciaModel {
  final int id;
  final int idConductor;
  final int? idVehiculo;
  final int? idTurno;

  final double lat;
  final double lng;

  final String tipo;
  final String? descripcion;
  final String estado;

  final DateTime createdAt;

  EmergenciaModel({
    required this.id,
    required this.idConductor,
    this.idVehiculo,
    this.idTurno,
    required this.lat,
    required this.lng,
    required this.tipo,
    this.descripcion,
    required this.estado,
    required this.createdAt,
  });

  factory EmergenciaModel.fromJson(Map<String, dynamic> json) {
    return EmergenciaModel(
      id: json['id'],
      idConductor: json['idConductor'],
      idVehiculo: json['idVehiculo'],
      idTurno: json['idTurno'],
      lat: double.parse(json['lat'].toString()),
      lng: double.parse(json['lng'].toString()),
      tipo: json['tipo'],
      descripcion: json['descripcion'],
      estado: json['estado'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "idConductor": idConductor,
      "idVehiculo": idVehiculo,
      "idTurno": idTurno,
      "lat": lat,
      "lng": lng,
      "tipo": tipo,
      "descripcion": descripcion,
    };
  }
}