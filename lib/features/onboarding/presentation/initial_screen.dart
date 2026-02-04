import 'package:flutter/material.dart';
import 'package:intellitaxi/features/onboarding/services/onboarding_service.dart';
import 'package:intellitaxi/features/onboarding/presentation/onboarding_screen.dart';
import 'package:intellitaxi/features/auth/presentation/splash_screen.dart';

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
    _checkOnboarding();
  }

  Future<void> _checkOnboarding() async {
    try {
      final hasCompleted = await _onboardingService.hasCompletedOnboarding();
      if (mounted) {
        setState(() {
          _shouldShowOnboarding = !hasCompleted;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('⚠️ Error verificando onboarding: $e');
      if (mounted) {
        setState(() {
          _shouldShowOnboarding = false;
          _isLoading = false;
        });
      }
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
