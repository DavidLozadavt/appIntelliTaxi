/// Caché en memoria para respuestas de Geocoding API (menos costo y texto más estable).
class GeocodeMemoryCache {
  GeocodeMemoryCache._();
  static final GeocodeMemoryCache instance = GeocodeMemoryCache._();

  final Map<String, _GeocodeCacheEntry> _entries = {};

  static String gridKey(double lat, double lng, {int decimals = 3}) {
    return '${lat.toStringAsFixed(decimals)},${lng.toStringAsFixed(decimals)}';
  }

  T? get<T>(String key) {
    final entry = _entries[key];
    if (entry == null) return null;
    if (DateTime.now().isAfter(entry.expiresAt)) {
      _entries.remove(key);
      return null;
    }
    return entry.value as T?;
  }

  void put<T>(String key, T value, Duration ttl) {
    _entries[key] = _GeocodeCacheEntry(
      value: value,
      expiresAt: DateTime.now().add(ttl),
    );
  }

  void clear() => _entries.clear();
}

class _GeocodeCacheEntry {
  final Object? value;
  final DateTime expiresAt;

  _GeocodeCacheEntry({required this.value, required this.expiresAt});
}
