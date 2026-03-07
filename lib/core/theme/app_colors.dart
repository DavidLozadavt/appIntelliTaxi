import 'package:flutter/material.dart';

class AppColors {
  static const Color brandWine = Color(0xFF7B1E3A);
  static const Color brandWineLight = Color(0xFF9F3A5A);
  static const Color brandWineDark = Color(0xFF5D132C);

  // Modo claro
  static const Color primary = brandWine;
  static const Color secondary = brandWineLight;
  static const Color accent = brandWine;

  // Modo oscuro - Colores principales
  static const Color primaryDark = brandWineDark;
  static const Color darkSurface = Color(0xFF000000);
  static const Color darkBackground = Color(0xFF000000);
  static const Color darkCard = Color(0xFF1A1A1A);

  // Modo oscuro - Colores de texto
  static const Color darkOnPrimary = Color(0xFF000000);
  static const Color darkOnSecondary = Color(0xFF000000);
  static const Color darkOnSurface = Color(0xFFFFFFFF);
  static const Color darkOnBackground = Color(0xFFFFFFFF);

  // Neutros
  static const Color black = Color(0xFF000000);
  static const Color white = Color(0xFFFFFFFF);
  static const Color grey = Color(0xFF808080);
  static const Color green = Color(0xff00C535);

  // Errores
  static const Color error = Color(0xFFCF6679);
  static const Color darkOnError = Color(0xFF000000);
}
