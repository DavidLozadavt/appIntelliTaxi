class ActivationCompanyUser {
  final int id;
  final String userId;
  final String stateId;
  final String companyId;
  final String fechaInicio;
  final String fechaFin;
  final Company company;
  final User user;
  final List<Role> roles;
  final Estado estado;

  ActivationCompanyUser({
    required this.id,
    required this.userId,
    required this.stateId,
    required this.companyId,
    required this.fechaInicio,
    required this.fechaFin,
    required this.company,
    required this.user,
    required this.roles,
    required this.estado,
  });

  factory ActivationCompanyUser.fromJson(Map<String, dynamic> json) {
    return ActivationCompanyUser(
      id: json['id'],
      userId: json['user_id'],
      stateId: json['state_id'],
      companyId: json['company_id'],
      fechaInicio: json['fechaInicio'],
      fechaFin: json['fechaFin'],
      company: Company.fromJson(json['company']),
      user: User.fromJson(json['user']),
      roles: (json['roles'] as List).map((e) => Role.fromJson(e)).toList(),
      estado: Estado.fromJson(json['estado']),
    );
  }
}

class Role {
  final int id;
  final String name;

  Role({required this.id, required this.name});

  factory Role.fromJson(Map<String, dynamic> json) {
    return Role(
      id: json['id'],
      name: json['name'],
    );
  }
}

class User {
  final int id;
  final String email;
  final Persona persona;

  User({required this.id, required this.email, required this.persona});

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      email: json['email'],
      persona: Persona.fromJson(json['persona']),
    );
  }
}

class Persona {
    final int id;

  final String nombre1;
  final String nombre2;
  final String apellido1;
  final String apellido2;
   final String? rutaFotoUrl;

  Persona({
    required this.id,
    required this.nombre1,
    required this.nombre2,
    required this.apellido1,
    required this.apellido2,
    this.rutaFotoUrl,
  });

  factory Persona.fromJson(Map<String, dynamic> json) {
    return Persona(
            id: json['id'],

      nombre1: json['nombre1'] ?? '',
      nombre2: json['nombre2'] ?? '',
      apellido1: json['apellido1'] ?? '',
      apellido2: json['apellido2'] ?? '',
      rutaFotoUrl: json['rutaFotoUrl'],
    );
  }

  String get nombreCompleto {
    return '$nombre1 ${nombre2.isNotEmpty ? "$nombre2 " : ""}$apellido1 ${apellido2.isNotEmpty ? apellido2 : ""}'.trim();
  }
}

class Company {
  final String razonSocial;

  Company({required this.razonSocial});

  factory Company.fromJson(Map<String, dynamic> json) {
    return Company(
      razonSocial: json['razonSocial'],
    );
  }
}

class Estado {
  final String estado;

  Estado({required this.estado});

  factory Estado.fromJson(Map<String, dynamic> json) {
    return Estado(
      estado: json['estado'],
    );
  }
}