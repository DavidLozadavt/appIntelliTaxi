import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../data/mensaje_taxi_model.dart';
import 'chat_imagen_fullscreen.dart';
import '../../../core/theme/app_colors.dart';

class MensajeBurbujaWidget extends StatelessWidget {
  final MensajeTaxi mensaje;
  final bool esMio;

  const MensajeBurbujaWidget({
    super.key,
    required this.mensaje,
    required this.esMio,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Align(
      alignment: esMio ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        padding: mensaje.esImagen
            ? const EdgeInsets.all(4)
            : const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: esMio
              ? AppColors.accent
              : (isDark ? AppColors.darkCard : Colors.grey[300]),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: Radius.circular(esMio ? 20 : 4),
            bottomRight: Radius.circular(esMio ? 4 : 20),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (mensaje.esImagen && mensaje.imagenUrl != null)
              _buildImagen(context)
            else
              Text(
                mensaje.textoVista,
                style: TextStyle(
                  color: esMio
                      ? Colors.white
                      : (isDark ? AppColors.darkOnSurface : Colors.black87),
                  fontSize: 15,
                ),
              ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _formatTime(mensaje.createdAt),
                  style: TextStyle(
                    color: esMio
                        ? Colors.white70
                        : (isDark ? Colors.grey[500] : Colors.black54),
                    fontSize: 11,
                  ),
                ),
                if (esMio) ...[
                  const SizedBox(width: 4),
                  Icon(
                    mensaje.leido ? Icons.done_all : Icons.done,
                    size: 14,
                    color: mensaje.leido ? AppColors.primary : Colors.white70,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImagen(BuildContext context) {
    final caption = mensaje.caption?.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GestureDetector(
          onTap: () => ChatImagenFullscreen.open(
            context,
            imageUrl: mensaje.imagenUrl!,
            caption: caption,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Stack(
              alignment: Alignment.center,
              children: [
                CachedNetworkImage(
                  imageUrl: mensaje.imagenUrl!,
                  width: 220,
                  height: 160,
                  fit: BoxFit.cover,
                  placeholder: (_, _) => const SizedBox(
                    width: 220,
                    height: 160,
                    child: Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                  errorWidget: (_, _, _) => const SizedBox(
                    width: 220,
                    height: 120,
                    child: Icon(Icons.broken_image_outlined, size: 40),
                  ),
                ),
                Positioned(
                  right: 6,
                  bottom: 6,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(
                      Icons.zoom_out_map,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (caption != null && caption.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 2),
            child: Text(
              caption,
              style: TextStyle(
                color: esMio ? Colors.white : Colors.black87,
                fontSize: 14,
              ),
            ),
          ),
      ],
    );
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays == 0) {
      return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays == 1) {
      return 'Ayer ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays < 7) {
      final dias = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
      return '${dias[dateTime.weekday - 1]} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }
}
