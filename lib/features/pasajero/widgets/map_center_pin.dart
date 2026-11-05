import 'package:flutter/material.dart';
import 'package:intellitaxi/core/theme/app_colors.dart';

class MapCenterPin extends StatelessWidget {
  const MapCenterPin({
    super.key,
    this.moving = false,
    this.color = AppColors.green,
  });

  final bool moving;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Transform.translate(
          offset: Offset(0, moving ? -10 : 0),
          child: Icon(Icons.location_on, size: 48, color: color),
        ),
        Container(
          width: moving ? 10 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.35),
            shape: BoxShape.circle,
          ),
        ),
      ],
    );
  }
}
