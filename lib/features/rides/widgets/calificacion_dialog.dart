import 'package:flutter/material.dart';
import 'package:intellitaxi/features/rides/services/calificacion_service.dart';

/// Diálogo para calificar un servicio (conductor o pasajero)
class CalificacionDialog extends StatefulWidget {
  final int idServicio;
  final int idUsuarioCalifica;
  final int idUsuarioCalificado;
  final String tipoCalificacion; // 'CONDUCTOR' o 'PASAJERO'
  final String nombreCalificado;
  final String? fotoCalificado;

  const CalificacionDialog({
    super.key,
    required this.idServicio,
    required this.idUsuarioCalifica,
    required this.idUsuarioCalificado,
    required this.tipoCalificacion,
    required this.nombreCalificado,
    this.fotoCalificado,
  });

  @override
  State<CalificacionDialog> createState() => _CalificacionDialogState();
}

class _CalificacionDialogState extends State<CalificacionDialog> {
  final CalificacionService _calificacionService = CalificacionService();
  final TextEditingController _comentarioController = TextEditingController();
  int _calificacion = 0;
  bool _isLoading = false;

  @override
  void dispose() {
    _comentarioController.dispose();
    super.dispose();
  }

  Future<void> _enviarCalificacion() async {
    if (_calificacion == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor selecciona una calificación'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Guardar contexto y scaffoldMessenger antes de operaciones async
    final ctx = context;
    final scaffoldMessenger = ScaffoldMessenger.of(ctx);

    setState(() => _isLoading = true);

    try {
      await _calificacionService.crearCalificacion(
        idServicio: widget.idServicio,
        idUsuarioCalifica: widget.idUsuarioCalifica,
        idUsuarioCalificado: widget.idUsuarioCalificado,
        tipoCalificacion: widget.tipoCalificacion,
        calificacion: _calificacion,
        comentario: _comentarioController.text.trim(),
      );

      // Cerrar diálogo
      if (mounted && ctx.mounted) {
        Navigator.of(ctx).pop(true); // Retornar true indicando éxito
      }

      // Mostrar mensaje de éxito
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          const SnackBar(
            content: Text('¡Gracias por tu calificación!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);

        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  String get _tituloDialog {
    return widget.tipoCalificacion == 'CONDUCTOR'
        ? 'Califica a tu conductor'
        : 'Califica a tu pasajero';
  }

  String get _subtituloDialog {
    return widget.tipoCalificacion == 'CONDUCTOR'
        ? '¿Cómo fue tu experiencia con ${widget.nombreCalificado}?'
        : '¿Cómo fue tu experiencia con el pasajero?';
  }

  String _obtenerTextoCalificacion(int calificacion) {
    switch (calificacion) {
      case 1:
        return 'Muy malo';
      case 2:
        return 'Malo';
      case 3:
        return 'Regular';
      case 4:
        return 'Bueno';
      case 5:
        return 'Excelente';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Avatar
              if (widget.fotoCalificado != null)
                CircleAvatar(
                  radius: 45,
                  backgroundImage: NetworkImage(widget.fotoCalificado!),
                  backgroundColor: Colors.grey.shade300,
                )
              else
                CircleAvatar(
                  radius: 45,
                  backgroundColor: Colors.deepOrange.shade100,
                  child: Icon(
                    widget.tipoCalificacion == 'CONDUCTOR'
                        ? Icons.person
                        : Icons.person_outline,
                    size: 50,
                    color: Colors.deepOrange,
                  ),
                ),

              const SizedBox(height: 16),

              // Título
              Text(
                _tituloDialog,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 8),

              // Subtítulo
              Text(
                _subtituloDialog,
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 24),

              // Estrellas
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  final estrella = index + 1;
                  return GestureDetector(
                    onTap: () {
                      setState(() => _calificacion = estrella);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Icon(
                        _calificacion >= estrella
                            ? Icons.star
                            : Icons.star_border,
                        size: 45,
                        color: _calificacion >= estrella
                            ? Colors.amber
                            : Colors.grey.shade400,
                      ),
                    ),
                  );
                }),
              ),

              const SizedBox(height: 12),

              // Texto de calificación
              if (_calificacion > 0)
                Text(
                  _obtenerTextoCalificacion(_calificacion),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.deepOrange.shade700,
                  ),
                ),

              const SizedBox(height: 24),

              // Campo de comentario
              TextField(
                controller: _comentarioController,
                maxLines: 3,
                maxLength: 500,
                decoration: InputDecoration(
                  hintText: 'Cuéntanos más sobre tu experiencia (opcional)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: isDark
                      ? Colors.grey.shade800
                      : Colors.grey.shade100,
                  contentPadding: const EdgeInsets.all(16),
                ),
              ),

              const SizedBox(height: 24),

              // Botones
              Row(
                children: [
                  // Botón Cancelar
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isLoading
                          ? null
                          : () => Navigator.pop(context, false),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        side: BorderSide(color: Colors.grey.shade400),
                      ),
                      child: const Text(
                        'Cancelar',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 12),

                  // Botón Enviar
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _enviarCalificacion,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepOrange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : const Text(
                              'Enviar',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
