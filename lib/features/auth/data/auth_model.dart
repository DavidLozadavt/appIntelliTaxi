import 'package:intellitaxi/features/auth/data/activation_company_user.dart';

int _asInt(dynamic value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is double) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

String _asString(dynamic value, {String fallback = ''}) {
  if (value == null) return fallback;
  return value.toString();
}

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
      id: _asInt(json['id']),
      razonSocial: _asString(json['razonSocial']),
      nit: _asString(json['nit']),
      rutaLogoUrl: _asString(json['rutaLogoUrl']),
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
  final String? identificacion;
  final String? fechaNac;
  final String? sexo;
  final int? idTipoIdentificacion;

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
    this.identificacion,
    this.fechaNac,
    this.sexo,
    this.idTipoIdentificacion,
  });

  factory Persona.fromJson(Map<String, dynamic> json) {
    return Persona(
      id: _asInt(json['id']),
      nombre1: _asString(json['nombre1']),
      nombre2: json['nombre2']?.toString(),
      apellido1: _asString(json['apellido1']),
      apellido2: json['apellido2']?.toString(),
      rutaFotoUrl: json['rutaFotoUrl']?.toString(),
      perfil: json['perfil']?.toString(),
      email: json['email']?.toString() ?? '',
      telefono: json['telefono']?.toString() ?? '',
      direccion: json['direccion']?.toString() ?? '',
      celular: json['celular']?.toString() ?? '',
      identificacion: json['identificacion']?.toString(),
      fechaNac: json['fechaNac']?.toString(),
      sexo: json['sexo']?.toString(),
      idTipoIdentificacion: json['idTipoIdentificacion'] == null
          ? null
          : _asInt(json['idTipoIdentificacion']),
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
    'identificacion': identificacion,
    'fechaNac': fechaNac,
    'sexo': sexo,
    'idTipoIdentificacion': idTipoIdentificacion,
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
    final personaJson =
        (json['persona'] as Map?)?.cast<String, dynamic>() ?? {};

    return User(
      id: _asInt(json['id']),
      email: _asString(json['email']),
      nombreCompleto:
          "${_asString(personaJson['nombre1'])} ${personaJson['nombre2'] ?? ''} ${_asString(personaJson['apellido1'])} ${personaJson['apellido2'] ?? ''}"
              .trim(),
      persona: Persona.fromJson(personaJson),
      activationCompanyUsers:
          (json['activation_company_users'] as List<dynamic>?)
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
    'activation_company_users': activationCompanyUsers
        .map((e) => e.toJson())
        .toList(),
  };
}

class AuthResponse {
  final String token;
  final List<String> roles;
  final List<String> permissions;
  final Company company;
  final User user;
  final int? expiresInSeconds;
  final DateTime? expiresAt;

  AuthResponse({
    required this.token,
    required this.roles,
    required this.permissions,
    required this.company,
    required this.user,
    this.expiresInSeconds,
    this.expiresAt,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    final payload = (json['payload'] as Map?)?.cast<String, dynamic>() ?? {};
    final rolesRaw = payload['roles'] as List<dynamic>? ?? const [];
    final permissionsRaw = payload['permissions'] as List<dynamic>? ?? const [];
    final companyRaw =
        (payload['company'] as Map?)?.cast<String, dynamic>() ?? {};
    final userRaw = (json['user'] as Map?)?.cast<String, dynamic>() ?? {};
    final expiresIn = (json['expires_in'] as num?)?.toInt();
    final storedExpiresAt = json['expires_at_iso'] as String?;
    DateTime? expiresAt;
    if (storedExpiresAt != null && storedExpiresAt.isNotEmpty) {
      expiresAt = DateTime.tryParse(storedExpiresAt);
    } else if (expiresIn != null && expiresIn > 0) {
      expiresAt = DateTime.now().add(Duration(seconds: expiresIn));
    }

    return AuthResponse(
      token: _asString(json['access_token']),
      roles: rolesRaw.map((e) => e.toString()).toList(),
      permissions: permissionsRaw.map((e) => e.toString()).toList(),
      company: Company.fromJson(companyRaw),
      user: User.fromJson(userRaw),
      expiresInSeconds: expiresIn,
      expiresAt: expiresAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'access_token': token,
    if (expiresInSeconds != null) 'expires_in': expiresInSeconds,
    if (expiresAt != null) 'expires_at_iso': expiresAt!.toIso8601String(),
    'payload': {
      'roles': roles,
      'permissions': permissions,
      'company': company.toJson(),
    },
    'user': user.toJson(),
  };
}
