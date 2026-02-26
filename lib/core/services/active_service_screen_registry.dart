import 'package:intellitaxi/core/services/app_logger.dart';

/// Registro simple en memoria para evitar reabrir/reemplazar la misma pantalla
/// de servicio activo cuando la app vuelve del background.
class ActiveServiceScreenRegistry {
  static String? _activeType; // 'conductor' | 'pasajero'
  static int? _activeServiceId;

  static void markVisible({required String type, required int serviceId}) {
    _activeType = type;
    _activeServiceId = serviceId;
    AppLogger.d(
      '🧭 [ScreenRegistry] Pantalla activa visible: tipo=$type, servicio=$serviceId',
    );
  }

  static void markHidden({required String type, required int serviceId}) {
    final isSame = _activeType == type && _activeServiceId == serviceId;
    if (isSame) {
      _activeType = null;
      _activeServiceId = null;
      AppLogger.d(
        '🧭 [ScreenRegistry] Pantalla activa oculta: tipo=$type, servicio=$serviceId',
      );
    }
  }

  static bool isShowing({required String type, required int serviceId}) {
    return _activeType == type && _activeServiceId == serviceId;
  }
}
