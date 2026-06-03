import 'package:shared_preferences/shared_preferences.dart';

/// Contadores de solicitudes para la burbuja cuando la app está en otra aplicación.
class ConductorOverlayBadgeStore {
  ConductorOverlayBadgeStore._();

  static const _llegandoKey = 'conductor_overlay_llegando';
  static const _esperaKey = 'conductor_overlay_espera';
  static const _pendingFcmKey = 'conductor_overlay_pending_fcm';

  static Future<({int llegando, int enEspera})> read() async {
    final prefs = await SharedPreferences.getInstance();
    return (
      llegando: prefs.getInt(_llegandoKey) ?? 0,
      enEspera: prefs.getInt(_esperaKey) ?? 0,
    );
  }

  static Future<void> write({
    required int llegando,
    required int enEspera,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_llegandoKey, llegando);
    await prefs.setInt(_esperaKey, enEspera);
    if (llegando > 0 || enEspera > 0) {
      await prefs.setBool(_pendingFcmKey, true);
    }
  }

  /// FCM en background: al menos 1 en «Llegando» hasta que abra la app.
  static Future<void> recordIncomingFromFcm() async {
    final prefs = await SharedPreferences.getInstance();
    final llegando = (prefs.getInt(_llegandoKey) ?? 0) + 1;
    await prefs.setInt(_llegandoKey, llegando);
    await prefs.setBool(_pendingFcmKey, true);
  }

  static Future<bool> hasPendingAlert() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_pendingFcmKey) ?? false;
  }

  static Future<void> clearPendingFlag() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pendingFcmKey);
  }
}
