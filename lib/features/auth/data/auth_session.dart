/// Ventana de validez del access token (JWT) según `expires_in` del backend (segundos).
class AuthSessionTiming {
  AuthSessionTiming({
    required this.expiresInSeconds,
    required this.expiresAt,
  });

  final int expiresInSeconds;
  final DateTime expiresAt;

  factory AuthSessionTiming.fromExpiresIn(int expiresInSeconds) {
    return AuthSessionTiming(
      expiresInSeconds: expiresInSeconds,
      expiresAt: DateTime.now().add(Duration(seconds: expiresInSeconds)),
    );
  }

  factory AuthSessionTiming.fromStoredIso(String iso) {
    final at = DateTime.parse(iso);
    final remaining = at.difference(DateTime.now()).inSeconds;
    return AuthSessionTiming(
      expiresInSeconds: remaining > 0 ? remaining : 0,
      expiresAt: at,
    );
  }

  /// Renovar unos minutos antes de expirar (evita 401 en ráfaga de peticiones).
  bool get shouldRefreshSoon {
    return DateTime.now().isAfter(
      expiresAt.subtract(const Duration(minutes: 5)),
    );
  }

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}
