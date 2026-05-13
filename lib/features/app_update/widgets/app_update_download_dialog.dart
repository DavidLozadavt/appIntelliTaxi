import 'package:flutter/material.dart';
import 'package:intellitaxi/core/theme/app_colors.dart';
import 'package:intellitaxi/core/widgets/app_loading_indicator.dart';

class AppUpdateDownloadDialog extends StatelessWidget {
  const AppUpdateDownloadDialog({
    super.key,
    required this.version,
    required this.progressListenable,
    required this.statusListenable,
    required this.forceUpdate,
    this.onCancelPressed,
  });

  final String version;
  final ValueNotifier<double?> progressListenable;
  final ValueNotifier<String> statusListenable;
  final bool forceUpdate;
  final VoidCallback? onCancelPressed;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !forceUpdate,
      child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('Actualizando aplicación'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Versión: $version'),
            const SizedBox(height: 16),
            ValueListenableBuilder<String>(
              valueListenable: statusListenable,
              builder: (context, status, child) => Text(status),
            ),
            const SizedBox(height: 16),
            ValueListenableBuilder<double?>(
              valueListenable: progressListenable,
              builder: (context, progress, child) {
                if (progress == null) {
                  return const Row(
                    children: [
                      AppLoadingIndicator(size: 18, strokeWidth: 2.2),
                      SizedBox(width: 12),
                      Expanded(child: Text('Preparando descarga...')),
                    ],
                  );
                }

                final progressValue = progress.clamp(0, 1).toDouble();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LinearProgressIndicator(
                      value: progressValue,
                      minHeight: 10,
                      borderRadius: BorderRadius.circular(999),
                      backgroundColor: Colors.grey.withValues(alpha: 0.2),
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        AppColors.brandWine,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text('${(progressValue * 100).toStringAsFixed(0)}%'),
                  ],
                );
              },
            ),
          ],
        ),
        actions: [
          if (!forceUpdate)
            TextButton(
              onPressed: onCancelPressed,
              child: const Text('Actualizar más tarde'),
            ),
        ],
      ),
    );
  }
}
