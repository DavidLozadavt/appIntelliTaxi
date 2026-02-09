import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

class AppFeedback {
  static void show(
    BuildContext context,
    String mensaje, {
    bool success = true,
    IconData? icon,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: success ? Colors.green.shade600 : Colors.red.shade600,
        content: Row(
          children: [
            Icon(
              icon ?? (success ? Iconsax.tick_circle_copy : Iconsax.info_circle_copy),
              color: Colors.white,
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(mensaje)),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  static void info(BuildContext context, String mensaje) {
    show(
      context,
      mensaje,
      success: true,
      icon: Iconsax.info_circle_copy,
    );
  }
}
