import 'package:flutter/material.dart';
import 'package:intellitaxi/core/theme/app_colors.dart';

/// Tema del anillo (claro = vino sobre fondo claro; oscuro = blanco sobre overlay).
enum AppLoaderTheme { auto, light, dark }

/// Loader global IntelliTaxi: anillo + [logo_overlay.png] en el centro.
class AppBrandLoader extends StatelessWidget {
  const AppBrandLoader({
    super.key,
    this.ringSize = 68,
    this.logoSize,
    this.strokeWidth = 2,
    this.theme = AppLoaderTheme.auto,
    this.value,
    this.ringColor,
  });

  static const logoAsset = 'assets/images/logo_overlay.png';

  final double ringSize;
  final double? logoSize;
  final double strokeWidth;
  final AppLoaderTheme theme;
  /// Progreso 0–1; null = indeterminado.
  final double? value;
  final Color? ringColor;

  double get _logoSize => logoSize ?? ringSize * 36 / 68;

  double get _logoRadius => (_logoSize / 36 * 6).clamp(4.0, 8.0);

  (Color ring, Color track) _colors(BuildContext context) {
    final useDarkRing = switch (theme) {
      AppLoaderTheme.light => false,
      AppLoaderTheme.dark => true,
      AppLoaderTheme.auto =>
        Theme.of(context).brightness == Brightness.dark,
    };
    if (useDarkRing) {
      return (
        Colors.white.withValues(alpha: 0.9),
        Colors.white.withValues(alpha: 0.12),
      );
    }
    return (
      AppColors.brandWine,
      AppColors.brandWine.withValues(alpha: 0.14),
    );
  }

  @override
  Widget build(BuildContext context) {
    final (ring, track) = _colors(context);
    final logo = _logoSize;

    return SizedBox(
      width: ringSize,
      height: ringSize,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: ringSize,
            height: ringSize,
            child: CircularProgressIndicator(
              value: value,
              strokeWidth: strokeWidth,
              color: ringColor ?? ring,
              backgroundColor: track,
            ),
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(_logoRadius),
            child: Image.asset(
              logoAsset,
              width: logo,
              height: logo,
              fit: BoxFit.contain,
            ),
          ),
        ],
      ),
    );
  }
}

/// Loader compacto para botones y controles pequeños.
class AppBrandLoaderCompact extends StatelessWidget {
  const AppBrandLoaderCompact({
    super.key,
    this.ringSize = 22,
    this.theme = AppLoaderTheme.auto,
  });

  final double ringSize;
  final AppLoaderTheme theme;

  @override
  Widget build(BuildContext context) {
    return AppBrandLoader(
      ringSize: ringSize,
      strokeWidth: 1.5,
      theme: theme,
    );
  }
}

class AppLoadingIndicator extends StatelessWidget {
  final double size;
  final double strokeWidth;
  final Color? color;
  final bool centered;
  final AppLoaderTheme theme;

  const AppLoadingIndicator({
    super.key,
    this.size = 68,
    this.strokeWidth = 2,
    this.color,
    this.centered = false,
    this.theme = AppLoaderTheme.auto,
  });

  @override
  Widget build(BuildContext context) {
    final loader = AppBrandLoader(
      ringSize: size,
      strokeWidth: strokeWidth,
      theme: theme,
    );
    if (centered) {
      return Center(child: loader);
    }
    return loader;
  }
}

/// Capa fullscreen semitransparente + loader centrado (p. ej. aceptar oferta).
class AppLoadingOverlay extends StatelessWidget {
  const AppLoadingOverlay({
    super.key,
    this.scrimOpacity = 0.55,
    this.ringSize = 68,
  });

  final double scrimOpacity;
  final double ringSize;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: ColoredBox(
        color: Colors.black.withValues(alpha: scrimOpacity),
        child: Center(
          child: AppBrandLoader(
            ringSize: ringSize,
            theme: AppLoaderTheme.dark,
          ),
        ),
      ),
    );
  }
}
