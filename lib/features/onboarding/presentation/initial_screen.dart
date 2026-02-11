import 'package:flutter/material.dart';
import 'package:intellitaxi/features/onboarding/services/onboarding_service.dart';
import 'package:intellitaxi/features/onboarding/presentation/onboarding_screen.dart';
import 'package:intellitaxi/features/auth/presentation/splash_screen.dart';
import 'package:intellitaxi/features/rides/services/servicio_inicializador_manager.dart';
import 'package:intellitaxi/features/rides/presentation/active_service_screen.dart';
import 'package:intellitaxi/features/conductor/presentation/conductor_servicio_activo_screen.dart';
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
  final ServicioInicializadorManager _inicializadorManager =
      ServicioInicializadorManager();
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
        return;
      }

      final resultado = await _inicializadorManager
          .verificarYCargarServicioActivo();

      if (resultado != null && mounted) {
        final servicio = resultado['servicio'];
        final tipo = resultado['tipo'];

        print('🔄 Restaurando servicio activo: Tipo=$tipo');

        // Navegar a la pantalla correspondiente
        if (tipo == 'pasajero') {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => ActiveServiceScreen(
                servicio: servicio,
                onServiceCompleted: () {
                  Navigator.of(context).pop();
                },
              ),
            ),
          );
        } else if (tipo == 'conductor') {
          final conductorId = authProvider.user?.id;
          if (conductorId != null) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (context) => ConductorServicioActivoScreen(
                  servicio: servicio,
                  conductorId: conductorId,
                ),
              ),
            );
          }
        }
      }
    } catch (e) {
      debugPrint('⚠️ Error verificando servicio activo: $e');
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
