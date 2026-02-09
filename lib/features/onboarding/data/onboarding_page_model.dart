import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

class OnboardingPageModel {
  final String title;
  final String description;
  final IconData icon;
  final List<Color> gradientColors;
  final String? subtitle;

  const OnboardingPageModel({
    required this.title,
    required this.description,
    required this.icon,
    required this.gradientColors,
    this.subtitle,
  });
}

// Páginas del onboarding de IntelliTaxi
final List<OnboardingPageModel> onboardingPages = [
  OnboardingPageModel(
    title: 'Bienvenido a IntelliTaxi',
    subtitle: 'Tu compañero de viaje ideal',
    description:
        'Descubre una nueva forma de moverte por la ciudad. Conectamos personas con conductores confiables en segundos.',
    icon: Iconsax.emoji_happy_copy,
    gradientColors: [Color(0xFFFFC502), Color(0xFFFFB300)],
  ),
  OnboardingPageModel(
    title: 'Viaja con Confianza',
    subtitle: 'Seguridad en cada kilómetro',
    description:
        'Conductores verificados, seguimiento en tiempo real y soporte disponible siempre. Tu tranquilidad es nuestra misión.',
    icon: Iconsax.shield_tick_copy,
    gradientColors: [Color(0xFF1E88E5), Color(0xFF1565C0)],
  ),
  OnboardingPageModel(
    title: 'Tu Destino te Espera',
    subtitle: 'Simple, rápido y confiable',
    description:
        'Solicita tu viaje con un toque, disfruta del trayecto y llega a donde necesitas. ¡Es hora de comenzar!',
    icon: Iconsax.global_copy,
    gradientColors: [Color(0xFFFFB300), Color(0xFFFF6F00)],
  ),
];
