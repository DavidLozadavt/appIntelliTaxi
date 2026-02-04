class MessageModel {
  final int id;
  final String? text;
  final String? origen;
  final Persona? persona;
  final List<String> files;
  final int idActivationCompanyUser;
  final DateTime? createdAt; // 👈

  MessageModel({
    required this.id,
    this.text,
    this.origen,
    this.persona,
    this.files = const [],
    required this.idActivationCompanyUser,
    this.createdAt,
  });

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    return MessageModel(
      id: json['id'] ?? 0,
      text: json['body'],
      origen: json['origen'],
      idActivationCompanyUser:
          int.tryParse(json['idActivationCompanyUser'].toString()) ?? 0,
      files:
          (json['archivos'] as List?)
              ?.map((f) => f['archivo'] as String)
              .toList() ??
          [],
      persona: json['activation_company_user']?['user']?['persona'] != null
          ? Persona.fromJson(json['activation_company_user']['user']['persona'])
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'])
          : null, 
    );
  }
}

class Persona {
  final int id;
  final String nombre1;
  final String apellido1;
  final String? rutaFotoUrl;

  Persona({
    required this.id,
    required this.nombre1,
    required this.apellido1,
    this.rutaFotoUrl,
  });

  factory Persona.fromJson(Map<String, dynamic> json) {
    return Persona(
      id: json['id'],
      nombre1: json['nombre1'],
      apellido1: json['apellido1'],
      rutaFotoUrl: json['rutaFotoUrl'],
    );
  }
}
