import 'package:intellitaxi/core/bootstrap/session_snapshot.dart';
import 'package:intellitaxi/features/auth/services/auth_service.dart';

/// Precarga token y perfil en paralelo al arranque (antes / durante Splash).
class SessionPreload {
  SessionPreload._();

  static Future<SessionSnapshot>? _future;

  static void start() {
    _future ??= AuthService.readSessionSnapshot();
  }

  static Future<SessionSnapshot> ensureReady() {
    start();
    return _future!;
  }

  static void invalidate() {
    _future = null;
  }
}
