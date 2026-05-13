import 'package:flutter/material.dart';
import 'package:intellitaxi/core/theme/app_colors.dart';
import 'package:intellitaxi/features/app_update/data/app_version_dto.dart';

class AppUpdateDialog extends StatelessWidget {
  const AppUpdateDialog({
    super.key,
    required this.versionInfo,
    required this.onUpdatePressed,
    this.onLaterPressed,
  });

  final AppVersionDto versionInfo;
  final Future<void> Function() onUpdatePressed;
  final VoidCallback? onLaterPressed;

  @override
  Widget build(BuildContext context) {
    final isForced = versionInfo.forceUpdate;

    return PopScope(
      canPop: !isForced,
      child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('Nueva actualización disponible'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Hay una nueva versión de la app disponible.'),
            const SizedBox(height: 12),
            Text(
              'Versión: ${versionInfo.version}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text('Cambios: ${versionInfo.effectiveChangelog}'),
          ],
        ),
        actions: [
          if (!isForced)
            TextButton(
              onPressed: onLaterPressed,
              child: const Text('Actualizar más tarde'),
            ),
          FilledButton(
            onPressed: onUpdatePressed,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.brandWine,
              foregroundColor: Colors.white,
            ),
            child: const Text('Actualizar ahora'),
          ),
        ],
      ),
    );
  }
}
