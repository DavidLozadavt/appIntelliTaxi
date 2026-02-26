import 'package:flutter/material.dart';
import 'package:intellitaxi/core/theme/app_colors.dart';

class AppLoadingIndicator extends StatelessWidget {
  final double size;
  final double strokeWidth;
  final Color? color;
  final bool centered;

  const AppLoadingIndicator({
    super.key,
    this.size = 24,
    this.strokeWidth = 2.8,
    this.color,
    this.centered = false,
  });

  @override
  Widget build(BuildContext context) {
    final indicator = SizedBox(
      width: size,
      height: size,
      child: CircularProgressIndicator(
        strokeWidth: strokeWidth,
        valueColor: AlwaysStoppedAnimation<Color>(color ?? AppColors.accent),
      ),
    );

    if (centered) {
      return Center(child: indicator);
    }
    return indicator;
  }
}
