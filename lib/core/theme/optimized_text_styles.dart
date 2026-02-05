import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Configuración optimizada de Google Fonts
/// Uso: En lugar de llamar GoogleFonts.poppinsTextTheme() cada vez,
/// usa estos estilos pre-cacheados
class OptimizedTextStyles {
  // Cache estática de textTheme para evitar recrear
  static TextTheme? _cachedLightTextTheme;
  static TextTheme? _cachedDarkTextTheme;

  /// TextTheme para modo claro (cacheado)
  static TextTheme get lightTextTheme {
    _cachedLightTextTheme ??= GoogleFonts.poppinsTextTheme(
      ThemeData.light().textTheme,
    );
    return _cachedLightTextTheme!;
  }

  /// TextTheme para modo oscuro (cacheado)
  static TextTheme get darkTextTheme {
    _cachedDarkTextTheme ??= GoogleFonts.poppinsTextTheme(
      ThemeData.dark().textTheme,
    );
    return _cachedDarkTextTheme!;
  }

  // Estilos comunes pre-cacheados
  static TextStyle? _headlineLarge;
  static TextStyle? _headlineMedium;
  static TextStyle? _bodyLarge;
  static TextStyle? _bodyMedium;
  static TextStyle? _labelLarge;

  static TextStyle get headlineLarge {
    _headlineLarge ??= GoogleFonts.poppins(
      fontSize: 32,
      fontWeight: FontWeight.bold,
    );
    return _headlineLarge!;
  }

  static TextStyle get headlineMedium {
    _headlineMedium ??= GoogleFonts.poppins(
      fontSize: 24,
      fontWeight: FontWeight.w600,
    );
    return _headlineMedium!;
  }

  static TextStyle get bodyLarge {
    _bodyLarge ??= GoogleFonts.poppins(
      fontSize: 16,
      fontWeight: FontWeight.normal,
    );
    return _bodyLarge!;
  }

  static TextStyle get bodyMedium {
    _bodyMedium ??= GoogleFonts.poppins(
      fontSize: 14,
      fontWeight: FontWeight.normal,
    );
    return _bodyMedium!;
  }

  static TextStyle get labelLarge {
    _labelLarge ??= GoogleFonts.poppins(
      fontSize: 14,
      fontWeight: FontWeight.w500,
    );
    return _labelLarge!;
  }

  /// Limpia el caché si es necesario (raramente usado)
  static void clearCache() {
    _cachedLightTextTheme = null;
    _cachedDarkTextTheme = null;
    _headlineLarge = null;
    _headlineMedium = null;
    _bodyLarge = null;
    _bodyMedium = null;
    _labelLarge = null;
  }

  /// Pre-cachea todos los estilos (llamar en main.dart)
  static Future<void> precacheAllFonts() async {
    // Forzar la carga de los estilos
    lightTextTheme;
    darkTextTheme;
    headlineLarge;
    headlineMedium;
    bodyLarge;
    bodyMedium;
    labelLarge;
  }
}
