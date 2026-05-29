/// Evita consultas duplicadas a servicio-activo en arranque / lifecycle.
class ActiveServiceCheckCache {
  ActiveServiceCheckCache._();

  static const Duration _ttl = Duration(seconds: 12);

  static String? _userKey;
  static DateTime? _fetchedAt;
  static Map<String, dynamic>? _cachedResult;
  static bool _fetchInFlight = false;
  static Future<Map<String, dynamic>?>? _inFlightFuture;

  static Future<Map<String, dynamic>?> dedupe(
    String userKey,
    Future<Map<String, dynamic>?> Function() fetch,
  ) async {
    final now = DateTime.now();
    if (_userKey == userKey &&
        _fetchedAt != null &&
        now.difference(_fetchedAt!) < _ttl) {
      return _cachedResult;
    }

    if (_fetchInFlight && _inFlightFuture != null) {
      return _inFlightFuture!;
    }

    _fetchInFlight = true;
    final future = fetch();
    _inFlightFuture = future;
    try {
      final result = await future;
      _userKey = userKey;
      _fetchedAt = DateTime.now();
      _cachedResult = result;
      return result;
    } finally {
      _fetchInFlight = false;
      _inFlightFuture = null;
    }
  }

  static void invalidate() {
    _userKey = null;
    _fetchedAt = null;
    _cachedResult = null;
  }
}
