import 'package:intellitaxi/core/map/intellitaxi_maps.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ServicioConductorLocationCacheService {
  static const String _keyPrefixLat = 'servicio_conductor_lat_';
  static const String _keyPrefixLng = 'servicio_conductor_lng_';

  Future<void> save(int servicioId, LatLng location) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('$_keyPrefixLat$servicioId', location.latitude);
    await prefs.setDouble('$_keyPrefixLng$servicioId', location.longitude);
  }

  Future<LatLng?> read(int servicioId) async {
    final prefs = await SharedPreferences.getInstance();
    final lat = prefs.getDouble('$_keyPrefixLat$servicioId');
    final lng = prefs.getDouble('$_keyPrefixLng$servicioId');
    if (lat == null || lng == null) return null;
    return LatLng(lat, lng);
  }

  Future<void> clear(int servicioId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_keyPrefixLat$servicioId');
    await prefs.remove('$_keyPrefixLng$servicioId');
  }
}
