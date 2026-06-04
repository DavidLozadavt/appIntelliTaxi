import 'package:intellitaxi/core/services/app_logger.dart';

/// Registro simple en memoria para evitar reabrir/reemplazar la misma pantalla
/// de servicio activo cuando la app vuelve del background.
class ActiveServiceScreenRegistry {
  static String? _activeType; // 'conductor' | 'pasajero'
  static int? _activeServiceId;

  /// FCM / Pusher cuando el viaje termina o cancela remotamente.
  static void Function({required int serviceId, required bool cancelado})?
      onRemoteTerminal;

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

  /// Notifica a la pantalla activa (si coincide) que el servicio cerró en servidor.
  static bool notifyRemoteTerminal({
    required int serviceId,
    required bool cancelado,
  }) {
    if (_activeServiceId != serviceId || _activeType == null) return false;
    final handler = onRemoteTerminal;
    if (handler == null) return false;
    AppLogger.d(
      '🧭 [ScreenRegistry] Terminal remoto servicio=$serviceId '
      'cancelado=$cancelado tipo=$_activeType',
    );
    handler(serviceId: serviceId, cancelado: cancelado);
    return true;
  }
}
