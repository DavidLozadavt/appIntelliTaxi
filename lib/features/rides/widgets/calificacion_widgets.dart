import 'package:flutter/material.dart';
import 'package:intellitaxi/features/rides/data/calificacion_model.dart';

/// Widget que muestra el resumen de calificación de un usuario
class CalificacionResumenWidget extends StatelessWidget {
  final double promedio;
  final int totalCalificaciones;
  final bool mostrarTotal;
  final double tamanoIcono;
  final double tamanoTexto;

  const CalificacionResumenWidget({
    super.key,
    required this.promedio,
    required this.totalCalificaciones,
    this.mostrarTotal = true,
    this.tamanoIcono = 16,
    this.tamanoTexto = 14,
  });

  @override
  Widget build(BuildContext context) {
    if (totalCalificaciones == 0) {
      return Text(
        'Sin calificaciones',
        style: TextStyle(fontSize: tamanoTexto, color: Colors.grey.shade600),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.star, color: Colors.amber, size: tamanoIcono),
        const SizedBox(width: 4),
        Text(
          promedio.toStringAsFixed(1),
          style: TextStyle(fontSize: tamanoTexto, fontWeight: FontWeight.bold),
        ),
        if (mostrarTotal) ...[
          const SizedBox(width: 4),
          Text(
            '($totalCalificaciones)',
            style: TextStyle(
              fontSize: tamanoTexto - 2,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ],
    );
  }
}

/// Widget que muestra las estrellas de calificación
class EstrellasCalificacion extends StatelessWidget {
  final int calificacion;
  final double tamano;
  final Color? colorActivo;
  final Color? colorInactivo;

  const EstrellasCalificacion({
    super.key,
    required this.calificacion,
    this.tamano = 20,
    this.colorActivo,
    this.colorInactivo,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        return Icon(
          index < calificacion ? Icons.star : Icons.star_border,
          size: tamano,
          color: index < calificacion
              ? (colorActivo ?? Colors.amber)
              : (colorInactivo ?? Colors.grey.shade400),
        );
      }),
    );
  }
}

/// Card que muestra una calificación individual
class CalificacionCard extends StatelessWidget {
  final CalificacionServicio calificacion;

  const CalificacionCard({super.key, required this.calificacion});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header con estrellas y fecha
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                EstrellasCalificacion(
                  calificacion: calificacion.calificacion,
                  tamano: 18,
                ),
                Text(
                  _formatearFecha(calificacion.fechaCalificacion),
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),

            // Texto de calificación
            const SizedBox(height: 8),
            Text(
              calificacion.textoCalificacion,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
              ),
            ),

            // Comentario si existe
            if (calificacion.comentario != null &&
                calificacion.comentario!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                calificacion.comentario!,
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                ),
              ),
            ],

            // Usuario que calificó
            if (calificacion.usuarioCalifica != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  CircleAvatar(
                    radius: 12,
                    backgroundColor: Colors.grey.shade300,
                    child: Icon(
                      Icons.person,
                      size: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    calificacion.usuarioCalifica!.nombre,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatearFecha(DateTime fecha) {
    final diferencia = DateTime.now().difference(fecha);

    if (diferencia.inDays == 0) {
      if (diferencia.inHours == 0) {
        return 'Hace ${diferencia.inMinutes} min';
      }
      return 'Hace ${diferencia.inHours} h';
    } else if (diferencia.inDays < 7) {
      return 'Hace ${diferencia.inDays} días';
    } else if (diferencia.inDays < 30) {
      return 'Hace ${(diferencia.inDays / 7).floor()} semanas';
    } else if (diferencia.inDays < 365) {
      return 'Hace ${(diferencia.inDays / 30).floor()} meses';
    } else {
      return 'Hace ${(diferencia.inDays / 365).floor()} años';
    }
  }
}

/// Widget que muestra estadísticas de distribución de calificaciones
class DistribucionCalificaciones extends StatelessWidget {
  final EstadisticasCalificacion estadisticas;

  const DistribucionCalificaciones({super.key, required this.estadisticas});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Distribución de calificaciones',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 16),
          _buildBarraCalificacion(
            5,
            estadisticas.distribucion['5_estrellas'] ?? 0,
          ),
          _buildBarraCalificacion(
            4,
            estadisticas.distribucion['4_estrellas'] ?? 0,
          ),
          _buildBarraCalificacion(
            3,
            estadisticas.distribucion['3_estrellas'] ?? 0,
          ),
          _buildBarraCalificacion(
            2,
            estadisticas.distribucion['2_estrellas'] ?? 0,
          ),
          _buildBarraCalificacion(
            1,
            estadisticas.distribucion['1_estrella'] ?? 0,
          ),
        ],
      ),
    );
  }

  Widget _buildBarraCalificacion(int estrellas, int cantidad) {
    final porcentaje = estadisticas.total > 0
        ? (cantidad / estadisticas.total * 100).toInt()
        : 0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(
            '$estrellas',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.star, color: Colors.amber, size: 14),
          const SizedBox(width: 8),
          Expanded(
            child: Stack(
              children: [
                Container(
                  height: 8,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                FractionallySizedBox(
                  widthFactor: porcentaje / 100,
                  child: Container(
                    height: 8,
                    decoration: BoxDecoration(
                      color: Colors.amber,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 50,
            child: Text(
              '$porcentaje% ($cantidad)',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}
