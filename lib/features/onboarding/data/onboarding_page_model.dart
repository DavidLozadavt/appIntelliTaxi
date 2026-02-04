import 'package:flutter/material.dart';

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

// Páginas del onboarding de Virtual Technology
final List<OnboardingPageModel> onboardingPages = [
  OnboardingPageModel(
    title: 'Virtual Technology',
    subtitle: 'Tu aliado tecnológico empresarial',
    description:
        'Somos proveedores de soluciones tecnológicas integrales para empresas modernas. Optimiza tu gestión con nuestro ERP completo.',
    icon: Icons.business_center_rounded,
    gradientColors: [Color(0xFF1E293B), Color(0xFF334155)],
  ),
  OnboardingPageModel(
    title: 'Facturación Electrónica',
    subtitle: 'Factura de forma rápida y segura',
    description:
        'Genera facturas electrónicas con cumplimiento legal completo. Automatiza tus procesos de facturación y ahorra tiempo.',
    icon: Icons.receipt_long_rounded,
    gradientColors: [Color(0xFF475569), Color(0xFF64748B)],
  ),
  OnboardingPageModel(
    title: 'Gestión de Nómina',
    subtitle: 'Control total de tu personal',
    description:
        'Administra salarios, deducciones y prestaciones de forma automática. Genera reportes detallados y cumple con las normativas laborales.',
    icon: Icons.payments_rounded,
    gradientColors: [Color(0xFFEA580C), Color(0xFFF97316)],
  ),
  OnboardingPageModel(
    title: 'Sistema de Transporte',
    subtitle: 'Gestiona tu flota eficientemente',
    description:
        'Controla vehículos, rutas, conductores y documentación. Optimiza operaciones logísticas con tecnología de punta.',
    icon: Icons.local_shipping_rounded,
    gradientColors: [Color(0xFF0F172A), Color(0xFF1E293B)],
  ),
  OnboardingPageModel(
    title: '¡Comencemos!',
    subtitle: 'Todo en un solo lugar',
    description:
        'Centraliza todas las operaciones de tu empresa en una sola plataforma. Potencia tu negocio con Virtual Technology.',
    icon: Icons.rocket_launch_rounded,
    gradientColors: [Color(0xFFC2410C), Color(0xFFEA580C)],
  ),
];
