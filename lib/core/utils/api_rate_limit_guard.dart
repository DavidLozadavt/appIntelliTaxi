import 'package:dio/dio.dart';

/// Cooldown cliente cuando Laravel responde 429 / «Too Many Attempts».
class ApiRateLimitGuard {
  ApiRateLimitGuard._();
  static final ApiRateLimitGuard instance = ApiRateLimitGuard._();

  static const Duration defaultBackoff = Duration(seconds: 45);

  DateTime? _blockedUntil;

  bool get isBlocked {
    final until = _blockedUntil;
    if (until == null) return false;
    if (DateTime.now().isAfter(until)) {
      _blockedUntil = null;
      return false;
    }
    return true;
  }

  int get secondsRemaining {
    final until = _blockedUntil;
    if (until == null) return 0;
    final sec = until.difference(DateTime.now()).inSeconds;
    return sec < 0 ? 0 : sec;
  }

  void recordHit({Duration backoff = defaultBackoff}) {
    _blockedUntil = DateTime.now().add(backoff);
  }

  static bool looksLikeRateLimit(Object error) {
    if (error is DioException && error.response?.statusCode == 429) {
      return true;
    }
    final lower = error.toString().toLowerCase();
    return lower.contains('too many attempts') ||
        lower.contains('too many requests') ||
        lower.contains(' 429') ||
        lower.contains('status code: 429');
  }

  void recordIfRateLimit(Object error) {
    if (looksLikeRateLimit(error)) recordHit();
  }
}
