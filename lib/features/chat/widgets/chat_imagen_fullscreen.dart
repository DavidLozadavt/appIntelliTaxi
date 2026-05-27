import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

/// Visor a pantalla completa con pinch-to-zoom para imágenes del chat.
class ChatImagenFullscreen extends StatelessWidget {
  const ChatImagenFullscreen({
    super.key,
    required this.imageUrl,
    this.caption,
  });

  final String imageUrl;
  final String? caption;

  static Future<void> open(
    BuildContext context, {
    required String imageUrl,
    String? caption,
  }) {
    return Navigator.of(context).push<void>(
      PageRouteBuilder<void>(
        opaque: false,
        barrierColor: Colors.black,
        transitionDuration: const Duration(milliseconds: 200),
        pageBuilder: (_, _, _) => ChatImagenFullscreen(
          imageUrl: imageUrl,
          caption: caption,
        ),
        transitionsBuilder: (_, animation, _, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final captionText = caption?.trim();

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          InteractiveViewer(
            minScale: 0.8,
            maxScale: 5,
            panEnabled: true,
            scaleEnabled: true,
            boundaryMargin: const EdgeInsets.all(48),
            child: Center(
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.contain,
                width: MediaQuery.sizeOf(context).width,
                placeholder: (_, _) => const Center(
                  child: CircularProgressIndicator(color: Colors.white70),
                ),
                errorWidget: (_, _, _) => const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.broken_image_outlined,
                      color: Colors.white54,
                      size: 64,
                    ),
                    SizedBox(height: 12),
                    Text(
                      'No se pudo cargar la imagen',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Iconsax.close_circle, color: Colors.white),
                    tooltip: 'Cerrar',
                  ),
                ),
                const Spacer(),
                if (captionText != null && captionText.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                    child: Text(
                      captionText,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        height: 1.35,
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    'Pellizca para ampliar',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.45),
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
