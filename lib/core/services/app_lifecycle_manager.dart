import 'package:flutter/material.dart';
import 'package:intellitaxi/core/services/app_logger.dart';
import 'package:intellitaxi/core/services/active_service_restoration_service.dart';
import 'package:intellitaxi/core/services/service_navigation_helper.dart';
import 'package:intellitaxi/features/auth/logic/auth_provider.dart';

/// Observador del ciclo de vida de la aplicación
/// Detecta cuando la app vuelve del background y restaura servicios activos
class AppLifecycleManager extends WidgetsBindingObserver {
  final BuildContext context;
  final AuthProvider authProvider;
  final ActiveServiceRestorationService _restorationService;

  bool _isCheckingService = false;
  DateTime? _lastCheck;

  AppLifecycleManager({required this.context, required this.authProvider})
    : _restorationService = ActiveServiceRestorationService();

  /// Inicializa el observer
  void initialize() {
    WidgetsBinding.instance.addObserver(this);
    AppLogger.d('✅ [Lifecycle] AppLifecycleManager inicializado');
  }

  /// Limpia el observer
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    AppLogger.d('🗑️ [Lifecycle] AppLifecycleManager disposed');
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    AppLogger.d('🔄 [Lifecycle] Estado de la app cambió: $state');

    switch (state) {
      case AppLifecycleState.resumed:
        // La app volvió del background o se abrió
        _onAppResumed();
        break;
      case AppLifecycleState.inactive:
        // La app está inactiva (por ejemplo, en transición)
        AppLogger.d('⏸️ [Lifecycle] App inactiva');
        break;
      case AppLifecycleState.paused:
        // La app fue enviada al background
        AppLogger.d('⏸️ [Lifecycle] App en background');
        break;
      case AppLifecycleState.detached:
        // La app está siendo terminada
        AppLogger.d('🛑 [Lifecycle] App detached');
        break;
      case AppLifecycleState.hidden:
        // La app está oculta
        AppLogger.d('🙈 [Lifecycle] App hidden');
        break;
    }
  }

  /// Maneja el evento cuando la app vuelve al foreground
  Future<void> _onAppResumed() async {
    AppLogger.d('🔄 [Lifecycle] App resumed - verificando servicio activo...');

    // Evitar verificaciones múltiples simultáneas
    if (_isCheckingService) {
      AppLogger.d('⏳ [Lifecycle] Verificación en progreso, omitiendo...');
      return;
    }

    // Evitar verificaciones muy frecuentes (cooldown de 3 segundos)
    if (_lastCheck != null) {
      final timeSinceLastCheck = DateTime.now().difference(_lastCheck!);
      if (timeSinceLastCheck.inSeconds < 3) {
        AppLogger.d('⏳ [Lifecycle] Cooldown activo, omitiendo verificación');
        return;
      }
    }

    _isCheckingService = true;
    _lastCheck = DateTime.now();

    try {
      await _checkAndRestoreActiveService();
    } finally {
      _isCheckingService = false;
    }
  }

  /// Verifica y restaura el servicio activo si existe
  Future<void> _checkAndRestoreActiveService() async {
    try {
      // Verificar si hay un servicio activo según el rol del usuario
      final servicioActivo = await _restorationService
          .verificarServicioActivoSegunRol(authProvider);

      if (servicioActivo == null) {
        AppLogger.d('ℹ️ [Lifecycle] No hay servicio activo para restaurar');
        return;
      }

      // Verificar que el servicio realmente esté activo
      if (!_restorationService.esServicioActivo(servicioActivo['servicio'])) {
        AppLogger.d('ℹ️ [Lifecycle] El servicio ya no está activo');
        return;
      }

      // Verificar que debemos mostrar la pantalla
      if (!ServiceNavigationHelper.shouldShowActiveService(servicioActivo)) {
        AppLogger.d(
          'ℹ️ [Lifecycle] No se debe mostrar la pantalla de servicio',
        );
        return;
      }

      AppLogger.d('✅ [Lifecycle] Servicio activo encontrado, restaurando...');

      // Navegar a la pantalla correcta
      if (context.mounted) {
        await ServiceNavigationHelper.navigateToActiveService(
          context,
          servicioActivo,
          authProvider,
        );
      }
    } catch (e, stackTrace) {
      AppLogger.d('⚠️ [Lifecycle] Error restaurando servicio activo: $e');
      AppLogger.d('Stack trace: $stackTrace');
    }
  }

  /// Método público para verificar servicio activo manualmente
  /// Útil para llamar al iniciar la app
  Future<void> checkActiveService() async {
    AppLogger.d('🔍 [Lifecycle] Verificación manual de servicio activo...');
    await _checkAndRestoreActiveService();
  }
}
