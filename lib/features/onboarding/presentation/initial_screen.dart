import 'package:flutter/material.dart';
import 'package:intellitaxi/features/onboarding/services/onboarding_service.dart';
import 'package:intellitaxi/features/onboarding/presentation/onboarding_screen.dart';
import 'package:intellitaxi/features/auth/presentation/splash_screen.dart';
import 'package:intellitaxi/core/widgets/app_loading_indicator.dart';
import 'package:intellitaxi/core/services/app_logger.dart';

/// Wrapper que decide si mostrar onboarding o ir directo al splash
class InitialScreen extends StatefulWidget {
  const InitialScreen({super.key});

  @override
  State<InitialScreen> createState() => _InitialScreenState();
}

class _InitialScreenState extends State<InitialScreen> {
  final OnboardingService _onboardingService = OnboardingService();
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

      // Servicio activo: lo comprueba Splash/Home/Lifecycle (evita API duplicada).
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
