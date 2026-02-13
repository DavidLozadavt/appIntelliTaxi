// lib/features/chat/widgets/mensaje_burbuja_widget.dart

import 'package:flutter/material.dart';
import '../data/mensaje_taxi_model.dart';
import '../../../core/theme/app_colors.dart';

class MensajeBurbujaWidget extends StatelessWidget {
  final MensajeTaxi mensaje;
  final bool esMio;

  const MensajeBurbujaWidget({
    Key? key,
    required this.mensaje,
    required this.esMio,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Align(
      alignment: esMio ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
              color: Colors.black.withOpacity(0.05),
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Texto del mensaje
            Text(
              mensaje.mensaje,
              style: TextStyle(
                color: esMio 
                    ? Colors.white 
                    : (isDark ? AppColors.darkOnSurface : Colors.black87),
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 4),

            // Hora y estado
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
                    color: mensaje.leido
                        ? AppColors.primary
                        : Colors.white70,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays == 0) {
      // Hoy - mostrar hora
      return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays == 1) {
      // Ayer
      return 'Ayer ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays < 7) {
      // Esta semana - mostrar día
      final dias = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
      return '${dias[dateTime.weekday - 1]} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else {
      // Más antiguo - mostrar fecha
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }
}
