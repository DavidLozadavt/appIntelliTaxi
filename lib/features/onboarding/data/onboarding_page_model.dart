import 'package:flutter/material.dart';

class OnboardingPageModel {
  final String title;
  final String? highlightedText;
  final String description;
  final String imagePath;
  final Alignment imageAlignment;
  final bool showBrandLogo;

  const OnboardingPageModel({
    required this.title,
    this.highlightedText,
    required this.description,
    required this.imagePath,
    this.imageAlignment = Alignment.center,
    this.showBrandLogo = false,
  });
}

// Páginas del onboarding de TaxbelUrbano
final List<OnboardingPageModel> onboardingPages = [
  OnboardingPageModel(
    title: 'Bienvenido a',
    highlightedText: 'TaxbelUrbano',
    description:
        'La experiencia de transporte premium impulsada por inteligencia y eficiencia.',
    imagePath: 'assets/images/mock3.png',
    imageAlignment: Alignment.center,
  ),
  OnboardingPageModel(
    title: 'Eficiencia Inteligente',
    description:
        'Pide tu transporte en segundos. Rapidez y simplicidad redefinidas para tu comodidad.',
    imagePath: 'assets/images/taxiOboarding.png',
    showBrandLogo: true,
  ),
];
