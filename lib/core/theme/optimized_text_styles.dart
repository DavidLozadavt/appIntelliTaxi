import 'package:flutter/material.dart';

/// Poppins embebido en [pubspec.yaml] — sin `google_fonts` ni red.
class OptimizedTextStyles {
  static const String poppinsFamily = 'Poppins';

  static TextTheme? _cachedLightTextTheme;
  static TextTheme? _cachedDarkTextTheme;

  static TextTheme _applyPoppins(TextTheme base) =>
      base.apply(fontFamily: poppinsFamily);

  /// Estilo Poppins desde assets locales.
  static TextStyle poppins({
    Color? color,
    double? fontSize,
    FontWeight? fontWeight,
    FontStyle? fontStyle,
    double? letterSpacing,
    List<Shadow>? shadows,
  }) {
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

  static TextStyle _poppins({
    required double fontSize,
    required FontWeight fontWeight,
  }) =>
      TextStyle(
        fontFamily: poppinsFamily,
        fontSize: fontSize,
        fontWeight: fontWeight,
      );

  static TextTheme get lightTextTheme {
    _cachedLightTextTheme ??= _applyPoppins(ThemeData.light().textTheme);
    return _cachedLightTextTheme!;
  }

  static TextTheme get darkTextTheme {
    _cachedDarkTextTheme ??= _applyPoppins(ThemeData.dark().textTheme);
    return _cachedDarkTextTheme!;
  }

  static TextStyle? _headlineLarge;
  static TextStyle? _headlineMedium;
  static TextStyle? _bodyLarge;
  static TextStyle? _bodyMedium;
  static TextStyle? _labelLarge;

  static TextStyle get headlineLarge {
    _headlineLarge ??= _poppins(fontSize: 32, fontWeight: FontWeight.bold);
    return _headlineLarge!;
  }

  static TextStyle get headlineMedium {
    _headlineMedium ??= _poppins(fontSize: 24, fontWeight: FontWeight.w600);
    return _headlineMedium!;
  }

  static TextStyle get bodyLarge {
    _bodyLarge ??= _poppins(fontSize: 16, fontWeight: FontWeight.normal);
    return _bodyLarge!;
  }

  static TextStyle get bodyMedium {
    _bodyMedium ??= _poppins(fontSize: 14, fontWeight: FontWeight.normal);
    return _bodyMedium!;
  }

  static TextStyle get labelLarge {
    _labelLarge ??= _poppins(fontSize: 14, fontWeight: FontWeight.w500);
    return _labelLarge!;
  }

  static void clearCache() {
    _cachedLightTextTheme = null;
    _cachedDarkTextTheme = null;
    _headlineLarge = null;
    _headlineMedium = null;
    _bodyLarge = null;
    _bodyMedium = null;
    _labelLarge = null;
  }

  /// Calienta el tema tipográfico (síncrono, sin red).
  static void warmUp() {
    lightTextTheme;
    darkTextTheme;
    headlineLarge;
    headlineMedium;
    bodyLarge;
    bodyMedium;
    labelLarge;
  }
}
