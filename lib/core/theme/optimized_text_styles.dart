import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intellitaxi/core/services/app_logger.dart';

/// Configuración optimizada de Google Fonts
/// Uso: En lugar de llamar GoogleFonts.poppinsTextTheme() cada vez,
/// usa estos estilos pre-cacheados
class OptimizedTextStyles {
  static const String poppinsFamily = 'Poppins';

  // Cache estática de textTheme para evitar recrear
  static TextTheme? _cachedLightTextTheme;
  static TextTheme? _cachedDarkTextTheme;

  /// Estilo Poppins desde assets (sin HTTP). Usar en splash y pantallas sueltas.
  static TextStyle poppins({
    Color? color,
    double? fontSize,
    FontWeight? fontWeight,
    FontStyle? fontStyle,
    double? letterSpacing,
    List<Shadow>? shadows,
  }) {
    try {
      return GoogleFonts.poppins(
        color: color,
        fontSize: fontSize,
        fontWeight: fontWeight,
        fontStyle: fontStyle,
        letterSpacing: letterSpacing,
        shadows: shadows,
      );
    } catch (_) {
      return TextStyle(
        fontFamily: poppinsFamily,
        color: color,
        fontSize: fontSize,
        fontWeight: fontWeight,
        fontStyle: fontStyle,
        letterSpacing: letterSpacing,
        shadows: shadows,
      );
    }
  }

  static TextTheme _poppinsTextThemeOrFallback(TextTheme base) {
    try {
      return GoogleFonts.poppinsTextTheme(base);
    } catch (e) {
      AppLogger.d(
        'Poppins no disponible (red/caché), usando tema del sistema: $e',
        tag: 'Fonts',
      );
      return base;
    }
  }

  static TextStyle _poppinsOrFallback({
    required double fontSize,
    required FontWeight fontWeight,
  }) {
    try {
      return GoogleFonts.poppins(fontSize: fontSize, fontWeight: fontWeight);
    } catch (_) {
      return TextStyle(
        fontFamily: poppinsFamily,
        fontSize: fontSize,
        fontWeight: fontWeight,
      );
    }
  }

  /// TextTheme para modo claro (cacheado)
  static TextTheme get lightTextTheme {
    _cachedLightTextTheme ??= _poppinsTextThemeOrFallback(
      ThemeData.light().textTheme,
    );
    return _cachedLightTextTheme!;
  }

  /// TextTheme para modo oscuro (cacheado)
  static TextTheme get darkTextTheme {
    _cachedDarkTextTheme ??= _poppinsTextThemeOrFallback(
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
    _headlineLarge ??= _poppinsOrFallback(
      fontSize: 32,
      fontWeight: FontWeight.bold,
    );
    return _headlineLarge!;
  }

  static TextStyle get headlineMedium {
    _headlineMedium ??= _poppinsOrFallback(
      fontSize: 24,
      fontWeight: FontWeight.w600,
    );
    return _headlineMedium!;
  }

  static TextStyle get bodyLarge {
    _bodyLarge ??= _poppinsOrFallback(
      fontSize: 16,
      fontWeight: FontWeight.normal,
    );
    return _bodyLarge!;
  }

  static TextStyle get bodyMedium {
    _bodyMedium ??= _poppinsOrFallback(
      fontSize: 14,
      fontWeight: FontWeight.normal,
    );
    return _bodyMedium!;
  }

  static TextStyle get labelLarge {
    _labelLarge ??= _poppinsOrFallback(
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
    try {
      lightTextTheme;
      darkTextTheme;
      headlineLarge;
      headlineMedium;
      bodyLarge;
      bodyMedium;
      labelLarge;
    } catch (e) {
      AppLogger.d(
        'precacheAllFonts omitido (sin red o fuente no disponible): $e',
        tag: 'Fonts',
      );
    }
  }
}
