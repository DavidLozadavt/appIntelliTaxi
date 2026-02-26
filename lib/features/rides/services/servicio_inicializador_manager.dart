import 'package:intellitaxi/features/rides/services/servicio_persistencia_service.dart';
import 'package:intellitaxi/features/rides/services/servicio_notificacion_foreground.dart';
import 'package:intellitaxi/features/rides/services/active_service_manager.dart';
import 'package:intellitaxi/features/rides/data/servicio_activo_model.dart';
import 'package:intellitaxi/core/services/app_logger.dart';

/// Gestor de inicialización de servicios activos
/// Verifica si hay un servicio activo guardado al iniciar la app
class ServicioInicializadorManager {
  final ServicioPersistenciaService _persistencia =
      ServicioPersistenciaService();
  final ServicioNotificacionForeground _notificacionService =
      ServicioNotificacionForeground();
  final ActiveServiceManager _activeServiceManager = ActiveServiceManager();

  /// Verifica e inicializa servicio activo al abrir la app
  Future<Map<String, dynamic>?> verificarYCargarServicioActivo() async {
    try {
      AppLogger.d('🔍 Verificando servicio activo al iniciar app...');

      // Inicializar notificaciones
      await _notificacionService.inicializar();

      // Verificar si hay servicio guardado localmente
      final servicioGuardado = await _persistencia.obtenerServicioActivo();

      if (servicioGuardado == null) {
        AppLogger.d('ℹ️ No hay servicio activo guardado localmente');
        return null;
      }

      // Verificar con el backend si el servicio sigue activo
      final servicioActivo = await _activeServiceManager.getActiveService();

      if (servicioActivo != null && servicioActivo.isActivo) {
        AppLogger.d('✅ Servicio activo verificado: ${servicioActivo.id}');

        // Restaurar notificación
        await _restaurarNotificacion(servicioActivo, servicioGuardado['tipo']);

        return {'servicio': servicioActivo, 'tipo': servicioGuardado['tipo']};
      } else {
        // El servicio ya no está activo, limpiar
        AppLogger.d('ℹ️ Servicio guardado ya no está activo, limpiando...');
        await _persistencia.limpiarServicioActivo();
        return null;
      }
    } catch (e) {
      AppLogger.d('⚠️ Error verificando servicio activo: $e');
      return null;
    }
  }

  /// Restaura la notificación persistente
  Future<void> _restaurarNotificacion(
    ServicioActivo servicio,
    String tipo,
  ) async {
    try {
      if (tipo == 'conductor') {
        await _notificacionService.mostrarNotificacionConductor(
          servicioId: servicio.id,
          estado: servicio.estado.estado,
          origen: servicio.origenAddress,
          destino: servicio.destinoAddress,
        );
      } else {
        await _notificacionService.mostrarNotificacionPasajero(
          servicioId: servicio.id,
          estado: servicio.estado.estado,
          conductorNombre: servicio.conductor?.nombre,
          vehiculoInfo: servicio.vehiculo != null
              ? '${servicio.vehiculo!.marca} ${servicio.vehiculo!.modelo}'
              : null,
          destino: servicio.destinoAddress,
        );
      }
    } catch (e) {
      AppLogger.d('⚠️ Error restaurando notificación: $e');
    }
  }

  /// Limpia el servicio activo
  Future<void> limpiarServicio() async {
    await _persistencia.limpiarServicioActivo();
  }
}
