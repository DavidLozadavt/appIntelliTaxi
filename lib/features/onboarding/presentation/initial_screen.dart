import 'package:flutter/material.dart';
import 'package:intellitaxi/features/onboarding/services/onboarding_service.dart';
import 'package:intellitaxi/features/onboarding/presentation/onboarding_screen.dart';
import 'package:intellitaxi/features/auth/presentation/splash_screen.dart';
import 'package:intellitaxi/core/services/active_service_restoration_service.dart';
import 'package:intellitaxi/core/services/service_navigation_helper.dart';
import 'package:intellitaxi/core/widgets/app_loading_indicator.dart';
import 'package:provider/provider.dart';
import 'package:intellitaxi/features/auth/providers/auth_provider.dart';
import 'package:intellitaxi/core/services/app_logger.dart';

/// Wrapper que decide si mostrar onboarding o ir directo al splash
class InitialScreen extends StatefulWidget {
  const InitialScreen({super.key});

  @override
  State<InitialScreen> createState() => _InitialScreenState();
}

class _InitialScreenState extends State<InitialScreen> {
  final OnboardingService _onboardingService = OnboardingService();
  final ActiveServiceRestorationService _restorationService =
      ActiveServiceRestorationService();
  bool _isLoading = true;
  bool _shouldShowOnboarding = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    final sw = Stopwatch()..start();
    try {
      // 1. Verificar onboarding
      final hasCompleted = await _onboardingService
          .hasCompletedOnboarding()
          .timeout(const Duration(seconds: 3));
      AppLogger.d(
        '⏱️ [InitialScreen] Onboarding verificado en ${sw.elapsedMilliseconds}ms',
      );

      if (mounted) {
        setState(() {
          _shouldShowOnboarding = !hasCompleted;
          _isLoading = false;
        });
      }

      // 2. Si ya completó onboarding, verificar servicio activo
      if (hasCompleted && mounted) {
        await _verificarServicioActivo().timeout(const Duration(seconds: 5));
      }
      AppLogger.d(
        '✅ [InitialScreen] Inicialización completa en ${sw.elapsedMilliseconds}ms',
      );
    } catch (e) {
      AppLogger.e('Error en inicialización', tag: 'InitialScreen', error: e);
      if (mounted) {
        setState(() {
          _shouldShowOnboarding = false;
          _isLoading = false;
        });
      }
    } finally {
      sw.stop();
    }
  }

  Future<void> _verificarServicioActivo() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final token = await authProvider.getSavedToken().timeout(
        const Duration(seconds: 3),
      );

      // Cargar usuario desde storage si aún no está en memoria
      if (authProvider.user == null && token != null) {
        await authProvider.loadUserFromStorage().timeout(
          const Duration(seconds: 3),
        );
      }

      // Solo verificar si el usuario está autenticado
      if (authProvider.user == null) {
        AppLogger.d(
          'ℹ️ [InitialScreen] Usuario no autenticado, saltando verificación',
        );
        return;
      }

      AppLogger.d(
        '🔍 [InitialScreen] Verificando servicio activo al iniciar...',
      );

      // Usar el nuevo servicio de restauración
      final servicioActivo = await _restorationService
          .verificarServicioActivoSegunRol(authProvider)
          .timeout(const Duration(seconds: 4));

      if (servicioActivo == null) {
        AppLogger.d('ℹ️ [InitialScreen] No hay servicio activo');
        return;
      }

      // Verificar que el servicio esté activo
      if (!_restorationService.esServicioActivo(servicioActivo['servicio'])) {
        AppLogger.d('ℹ️ [InitialScreen] El servicio ya no está activo');
        return;
      }

      // Verificar que debemos mostrar la pantalla
      if (!ServiceNavigationHelper.shouldShowActiveService(servicioActivo)) {
        AppLogger.d(
          'ℹ️ [InitialScreen] No se debe mostrar la pantalla de servicio',
        );
        return;
      }

      AppLogger.d('✅ [InitialScreen] Servicio activo encontrado, navegando...');

      if (mounted) {
        await ServiceNavigationHelper.navigateToActiveService(
          context,
          servicioActivo,
          authProvider,
        );
      }
    } catch (e, stackTrace) {
      AppLogger.e(
        'Error verificando servicio activo',
        tag: 'InitialScreen',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: AppLoadingIndicator(size: 30, strokeWidth: 3.2)),
      );
    }

    return _shouldShowOnboarding
        ? const OnboardingScreen()
        : const SplashScreen();
  }
}
