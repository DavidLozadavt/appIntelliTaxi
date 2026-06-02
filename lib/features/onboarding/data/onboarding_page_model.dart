import 'package:flutter/material.dart';

class OnboardingPageModel {
  final String title;
  final String? highlightedText;
  final String description;
  final String imagePath;
  final Alignment imageAlignment;

  const OnboardingPageModel({
    required this.title,
    this.highlightedText,
    required this.description,
    required this.imagePath,
    this.imageAlignment = Alignment.center,
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
    imagePath: 'assets/images/logoTaxbel.webp',
  ),
];
