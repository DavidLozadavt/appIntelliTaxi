import 'package:flutter/material.dart';

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
    final colorScheme = Theme.of(context).colorScheme;

    final indicator = SizedBox(
      width: size,
      height: size,
      child: CircularProgressIndicator(
        strokeWidth: strokeWidth,
        valueColor: AlwaysStoppedAnimation<Color>(color ?? colorScheme.primary),
      ),
    );

    if (centered) {
      return Center(child: indicator);
    }
    return indicator;
  }
}
