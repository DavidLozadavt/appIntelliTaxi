import 'package:intellitaxi/features/auth/data/auth_model.dart';

/// Datos de sesión leídos de disco en un solo paso (token + perfil).
class SessionSnapshot {
  const SessionSnapshot({
    this.token,
    this.authResponse,
    this.storedActiveRole,
  });

  final String? token;
  final AuthResponse? authResponse;
  final String? storedActiveRole;

  bool get hasToken => token != null && token!.trim().isNotEmpty;

  bool get hasUser => authResponse != null;

  /// Listo para ir a Home sin otra lectura de SharedPreferences.
  bool get canOpenHome => hasToken && hasUser;
}
