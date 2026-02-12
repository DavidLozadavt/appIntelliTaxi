import 'package:flutter/material.dart';
import 'package:intellitaxi/features/onboarding/services/onboarding_service.dart';
import 'package:intellitaxi/features/onboarding/presentation/onboarding_screen.dart';
import 'package:intellitaxi/features/auth/presentation/splash_screen.dart';
import 'package:intellitaxi/core/services/active_service_restoration_service.dart';
import 'package:intellitaxi/core/services/service_navigation_helper.dart';
import 'package:provider/provider.dart';
import 'package:intellitaxi/features/auth/logic/auth_provider.dart';

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
    try {
      // 1. Verificar onboarding
      final hasCompleted = await _onboardingService.hasCompletedOnboarding();

      if (mounted) {
        setState(() {
          _shouldShowOnboarding = !hasCompleted;
          _isLoading = false;
        });
      }

      // 2. Si ya completó onboarding, verificar servicio activo
      if (hasCompleted && mounted) {
        await _verificarServicioActivo();
      }
    } catch (e) {
      debugPrint('⚠️ Error en inicialización: $e');
      if (mounted) {
        setState(() {
          _shouldShowOnboarding = false;
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _verificarServicioActivo() async {
    try {
      // Esperar un poco para que el AuthProvider se inicialice
      await Future.delayed(const Duration(milliseconds: 500));

      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      // Solo verificar si el usuario está autenticado
      if (authProvider.user == null) {
        print('ℹ️ [InitialScreen] Usuario no autenticado, saltando verificación');
        return;
      }

      print('🔍 [InitialScreen] Verificando servicio activo al iniciar...');

      // Usar el nuevo servicio de restauración
      final servicioActivo = await _restorationService
          .verificarServicioActivoSegunRol(authProvider);

      if (servicioActivo == null) {
        print('ℹ️ [InitialScreen] No hay servicio activo');
        return;
      }

      // Verificar que el servicio esté activo
      if (!_restorationService.esServicioActivo(servicioActivo['servicio'])) {
        print('ℹ️ [InitialScreen] El servicio ya no está activo');
        return;
      }

      // Verificar que debemos mostrar la pantalla
      if (!ServiceNavigationHelper.shouldShowActiveService(servicioActivo)) {
        print('ℹ️ [InitialScreen] No se debe mostrar la pantalla de servicio');
        return;
      }

      print('✅ [InitialScreen] Servicio activo encontrado, navegando...');

      if (mounted) {
        await ServiceNavigationHelper.navigateToActiveService(
          context,
          servicioActivo,
          authProvider,
        );
      }
    } catch (e, stackTrace) {
      debugPrint('⚠️ Error verificando servicio activo: $e');
      debugPrint('Stack trace: $stackTrace');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFFFFC502)),
        ),
      );
    }

    return _shouldShowOnboarding
        ? const OnboardingScreen()
        : const SplashScreen();
  }
}
