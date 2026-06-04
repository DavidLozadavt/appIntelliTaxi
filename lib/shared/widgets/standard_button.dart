import 'package:flutter/material.dart';
import 'package:intellitaxi/core/theme/app_colors.dart';
import 'package:intellitaxi/core/widgets/app_loading_indicator.dart';

enum ButtonType { primary, secondary, danger, success }

class StandardButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final ButtonType type;
  final IconData? icon;
  final bool isLoading;
  final bool isOutlined;
  final double? width;
  final double height;
  final double fontSize;

  const StandardButton({
    super.key,
    required this.text,
    this.onPressed,
    this.type = ButtonType.primary,
    this.icon,
    this.isLoading = false,
    this.isOutlined = false,
    this.width,
    this.height = 50,
    this.fontSize = 16,
  });

  @override
  Widget build(BuildContext context) {
    final colors = _getColors();

    if (isOutlined) {
      return SizedBox(
        width: width,
        height: height,
        child: OutlinedButton.icon(
          onPressed: isLoading ? null : onPressed,
          icon: isLoading
              ? AppBrandLoaderCompact(
                  ringSize: 22,
                  theme: isOutlined
                      ? AppLoaderTheme.light
                      : AppLoaderTheme.dark,
                )
              : (icon != null ? Icon(icon, size: 20) : const SizedBox.shrink()),
          label: Text(
            text,
            style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.bold),
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor: colors['color'],
            side: BorderSide(color: colors['color']!, width: 2),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      );
    }

    if (icon != null) {
      return SizedBox(
        width: width,
        height: height,
        child: ElevatedButton.icon(
          onPressed: isLoading ? null : onPressed,
          icon: isLoading
              ? const AppBrandLoaderCompact(
                  ringSize: 22,
                  theme: AppLoaderTheme.dark,
                )
              : Icon(icon, size: 20),
          label: Text(
            text,
            style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.bold),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: colors['background'],
            foregroundColor: colors['foreground'],
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 2,
          ),
        ),
      );
    }

    return SizedBox(
      width: width,
      height: height,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: colors['background'],
          foregroundColor: colors['foreground'],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 2,
        ),
        child: isLoading
            ? const AppBrandLoaderCompact(
                ringSize: 22,
                theme: AppLoaderTheme.dark,
              )
            : Text(
                text,
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }

  Map<String, Color> _getColors() {
    switch (type) {
      case ButtonType.primary:
        return {
          'background': AppColors.primary,
          'foreground': Colors.black,
          'color': AppColors.primary,
        };
      case ButtonType.secondary:
        return {
          'background': AppColors.accent,
          'foreground': Colors.white,
          'color': AppColors.accent,
        };
      case ButtonType.danger:
        return {
          'background': Colors.red,
          'foreground': Colors.white,
          'color': Colors.red,
        };
      case ButtonType.success:
        return {
          'background': AppColors.green,
          'foreground': Colors.white,
          'color': AppColors.green,
        };
    }
  }
}

// Botón flotante redondo estándar
class StandardFloatingButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final Color? backgroundColor;
  final Color? iconColor;
  final String? tooltip;
  final bool mini;
  final Widget? badge;

  const StandardFloatingButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.backgroundColor,
    this.iconColor,
    this.tooltip,
    this.mini = false,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    Widget button = FloatingActionButton(
      mini: mini,
      onPressed: onPressed,
      backgroundColor: backgroundColor ?? AppColors.primary,
      tooltip: tooltip,
      child: Icon(icon, color: iconColor ?? Colors.black),
    );

    if (badge != null) {
      return Stack(
        children: [
          button,
          Positioned(right: 0, top: 0, child: badge!),
        ],
      );
    }

    return button;
  }
}
