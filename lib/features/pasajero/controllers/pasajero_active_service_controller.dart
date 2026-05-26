import 'package:intellitaxi/core/services/app_logger.dart';
import 'package:intellitaxi/features/rides/data/servicio_activo_model.dart';
import 'package:intellitaxi/features/rides/services/active_service_manager.dart';

/// Restauración y seguimiento del servicio activo del pasajero (sin UI).
class PasajeroActiveServiceController {
  PasajeroActiveServiceController({ActiveServiceManager? manager})
      : _manager = manager ?? ActiveServiceManager();

  final ActiveServiceManager _manager;

  ActiveServiceManager get manager => _manager;

  Future<ServicioActivo?> fetchActiveServiceIfAny() async {
    try {
      AppLogger.d('🔍 Verificando servicio activo al iniciar...');
      final servicio = await _manager.getActiveService();
      if (servicio != null && servicio.isActivo) {
        AppLogger.d('✅ Servicio activo: ${servicio.id} (${servicio.estado.estado})');
        return servicio;
      }
      AppLogger.d('ℹ️ No hay servicio activo');
      return null;
    } catch (e, st) {
      AppLogger.e(
        'Error verificando servicio activo',
        tag: 'PasajeroActiveService',
        error: e,
        stackTrace: st,
      );
      return null;
    }
  }

  void startTracking({
    required int servicioId,
    void Function(ServicioActivo servicio)? onUpdated,
    void Function()? onCompleted,
  }) {
    _manager.onServiceUpdated = onUpdated;
    _manager.onServiceCompleted = onCompleted;
    _manager.startPolling();
    _manager.subscribeToServiceEvents(servicioId);
  }

  void dispose() {
    _manager.onServiceUpdated = null;
    _manager.onServiceCompleted = null;
    _manager.cleanup();
  }
}
