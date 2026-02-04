import 'package:intellitaxi/features/auth/data/activation_company_user.dart';

class Company {
  final int id;
  final String razonSocial;
  final String nit;
  final String rutaLogoUrl;

  Company({
    required this.id,
    required this.razonSocial,
    required this.nit,
    required this.rutaLogoUrl,
  });

  factory Company.fromJson(Map<String, dynamic> json) {
    return Company(
      id: json['id'],
      razonSocial: json['razonSocial'],
      nit: json['nit'],
      rutaLogoUrl: json['rutaLogoUrl'],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'razonSocial': razonSocial,
        'nit': nit,
        'rutaLogoUrl': rutaLogoUrl,
      };
}

class Persona {
  final int id;
  final String nombre1;
  final String? nombre2;
  final String apellido1;
  final String? apellido2;
  final String? rutaFotoUrl;
  final String? perfil;
  final String? email;
  final String? telefono;
  final String? direccion;
  final String? celular;

  Persona({
    required this.id,
    required this.nombre1,
    this.nombre2,
    required this.apellido1,
    this.apellido2,
    this.rutaFotoUrl,
    this.perfil,
    this.email,
    this.telefono,
    this.direccion,
    this.celular,
  });

  factory Persona.fromJson(Map<String, dynamic> json) {
    return Persona(
      id: json['id'],
      nombre1: json['nombre1'],
      nombre2: json['nombre2'],
      apellido1: json['apellido1'],
      apellido2: json['apellido2'],
      rutaFotoUrl: json['rutaFotoUrl'],
      perfil: json['perfil'],
      email: json['email'] ?? '',
      telefono: json['telefono'] ?? '',
      direccion: json['direccion'] ?? '',
      celular: json['celular'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'nombre1': nombre1,
        'nombre2': nombre2,
        'apellido1': apellido1,
        'apellido2': apellido2,
        'rutaFotoUrl': rutaFotoUrl,
        'perfil': perfil,
        'email': email ?? '',
        'telefono': telefono ?? '',
        'direccion': direccion ?? '',
        'celular': celular ?? '',
      };
}

class User {
  final int id;
  final String email;
  final String nombreCompleto;
  final Persona persona;
  final List<ActivationCompanyUser> activationCompanyUsers;

  User({
    required this.id,
    required this.email,
    required this.nombreCompleto,
    required this.persona,
    required this.activationCompanyUsers,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    final personaJson = json['persona'];

    return User(
      id: json['id'],
      email: json['email'],
      nombreCompleto:
          "${personaJson['nombre1']} ${personaJson['nombre2'] ?? ''} ${personaJson['apellido1']} ${personaJson['apellido2'] ?? ''}".trim(),
      persona: Persona.fromJson(personaJson),
      activationCompanyUsers: (json['activation_company_users'] as List<dynamic>?)
              ?.map((e) => ActivationCompanyUser.fromJson(e))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'nombreCompleto': nombreCompleto,
        'persona': persona.toJson(),
        'activation_company_users':
            activationCompanyUsers.map((e) => e.toJson()).toList(),
      };
}

class AuthResponse {
  final String token;
  final List<String> roles;
  final List<String> permissions;
  final Company company;
  final User user;

  AuthResponse({
    required this.token,
    required this.roles,
    required this.permissions,
    required this.company,
    required this.user,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      token: json['access_token'],
      roles: List<String>.from(json['payload']['roles']),
      permissions: List<String>.from(json['payload']['permissions']),
      company: Company.fromJson(json['payload']['company']),
      user: User.fromJson(json['user']),
    );
  }

  Map<String, dynamic> toJson() => {
        'access_token': token,
        'payload': {
          'roles': roles,
          'permissions': permissions,
          'company': company.toJson(),
        },
        'user': user.toJson(),
      };


      
}
