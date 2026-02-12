import 'package:flutter/material.dart';
import 'package:intellitaxi/features/rides/services/calificacion_service.dart';
import 'package:intellitaxi/features/auth/logic/auth_provider.dart';
import 'package:provider/provider.dart';

class CalificacionConductorDialog extends StatefulWidget {
  final int servicioId;
  final Map<String, dynamic>? conductor;

  const CalificacionConductorDialog({
    super.key,
    required this.servicioId,
    this.conductor,
  });

  @override
  State<CalificacionConductorDialog> createState() =>
      _CalificacionConductorDialogState();

  /// Método estático para mostrar el diálogo fácilmente
  static Future<bool?> show(
    BuildContext context, {
    required int servicioId,
    Map<String, dynamic>? conductor,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => CalificacionConductorDialog(
        servicioId: servicioId,
        conductor: conductor,
      ),
    );
  }
}

class _CalificacionConductorDialogState
    extends State<CalificacionConductorDialog> {
  final CalificacionService _calificacionService = CalificacionService();
  final TextEditingController _comentarioController = TextEditingController();
  int _calificacionSeleccionada = 5;

  // Mensajes sugeridos genéricos
  final List<String> _mensajesSugeridos = [
    'Excelente servicio',
    'Muy amable y puntual',
    'Viaje cómodo y seguro',
    'Buen conductor',
  ];

  @override
  void dispose() {
    _comentarioController.dispose();
    super.dispose();
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

  Future<void> _enviarCalificacion() async {
    print('Calificación: $_calificacionSeleccionada');
    print('Comentario: ${_comentarioController.text}');

    // Guardar contexto y navigator
    final ctx = context;
    final scaffoldMessenger = ScaffoldMessenger.of(ctx);

    // Guardar valores antes de async
    final authProvider = Provider.of<AuthProvider>(ctx, listen: false);
    final idPasajero = authProvider.userId;

    if (idPasajero == null) {
      scaffoldMessenger.showSnackBar(
        const SnackBar(
          content: Text('❌ No se pudo obtener ID del usuario'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Obtener ID del conductor de forma segura
    final conductorData = widget.conductor;
    if (conductorData == null) {
      scaffoldMessenger.showSnackBar(
        const SnackBar(
          content: Text('❌ No hay datos del conductor disponibles'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final idConductor = conductorData['conductor_id'] as int?;
    if (idConductor == null) {
      scaffoldMessenger.showSnackBar(
        const SnackBar(
          content: Text('❌ No se pudo obtener ID del conductor'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Mostrar loading
    showDialog(
      context: ctx,
      barrierDismissible: false,
      builder: (loadingContext) => PopScope(
        canPop: false,
        child: const Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Enviando calificación...'),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    try {
      print('📤 Enviando calificación:');
      print('   Servicio: ${widget.servicioId}');
      print('   Pasajero (califica): $idPasajero');
      print('   Conductor (calificado): $idConductor');
      print('   Estrellas: $_calificacionSeleccionada');
      print('   Comentario: ${_comentarioController.text}');

      // Enviar calificación
      final resultado = await _calificacionService.crearCalificacion(
        idServicio: widget.servicioId,
        idUsuarioCalifica: idPasajero,
        idUsuarioCalificado: idConductor,
        tipoCalificacion: 'CONDUCTOR',
        calificacion: _calificacionSeleccionada,
        comentario: _comentarioController.text.trim().isEmpty
            ? null
            : _comentarioController.text.trim(),
      );

      print('✅ Calificación enviada: ID ${resultado.id}');

      // Cerrar loading dialog usando rootNavigator
      if (mounted && ctx.mounted) {
        Navigator.of(ctx, rootNavigator: true).pop();
      }

      // Mostrar mensaje de éxito
      if (mounted && ctx.mounted) {
        scaffoldMessenger.showSnackBar(
          const SnackBar(
            content: Text('✅ ¡Gracias por tu calificación!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }

      // Esperar un poco
      await Future.delayed(const Duration(milliseconds: 300));

      // Cerrar diálogo de calificación principal
      if (mounted && ctx.mounted) {
        Navigator.of(ctx).pop(true);
      }
    } catch (e) {
      print('❌ Error enviando calificación: $e');

      // Cerrar loading dialog usando rootNavigator
      if (mounted && ctx.mounted) {
        Navigator.of(ctx, rootNavigator: true).pop();
      }

      // Mostrar error
      if (mounted && ctx.mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('❌ Error: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }

      // Esperar un momento
      await Future.delayed(const Duration(milliseconds: 500));

      // Cerrar diálogo de calificación principal
      if (mounted && ctx.mounted) {
        Navigator.of(ctx).pop(false);
      }
    }
  }

  Widget _buildMensajeChip(
    String mensaje,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    final isSelected = _comentarioController.text == mensaje;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          setState(() {
            _comentarioController.text = mensaje;
          });
        },
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            gradient: isSelected
                ? LinearGradient(
                    colors: [
                      colorScheme.primary,
                      colorScheme.primary.withOpacity(0.8),
                    ],
                  )
                : null,
            color: isSelected
                ? null
                : colorScheme.surfaceVariant.withOpacity(0.5),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected
                  ? colorScheme.primary
                  : colorScheme.outline.withOpacity(0.3),
              width: isSelected ? 2 : 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: colorScheme.primary.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isSelected)
                const Padding(
                  padding: EdgeInsets.only(right: 4),
                  child: Icon(
                    Icons.check_circle,
                    size: 14,
                    color: Colors.white,
                  ),
                ),
              Flexible(
                child: Text(
                  mensaje,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: isSelected
                        ? colorScheme.onPrimary
                        : colorScheme.onSurface.withOpacity(0.7),
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      elevation: 8,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              colorScheme.surface,
              colorScheme.primary.withOpacity(0.02),
            ],
          ),
          borderRadius: BorderRadius.circular(24),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Icono de éxito animado
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check_circle_rounded,
                  color: Colors.green.shade600,
                  size: 36,
                ),
              ),
              const SizedBox(height: 16),

              Text(
                '¡Viaje Finalizado!',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 6),

              Text(
                '¡Gracias por usar nuestro servicio!',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurface.withOpacity(0.7),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),

              // Nombre del conductor con estilo
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.person_rounded,
                      color: colorScheme.onPrimaryContainer,
                      size: 18,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'Califica a ${widget.conductor?['conductor_nombre'] ?? 'tu conductor'}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onPrimaryContainer,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Estrellas de calificación con mejor diseño
              Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 16,
                ),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceVariant.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: colorScheme.outline.withOpacity(0.2),
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(5, (index) {
                        final starValue = index + 1;
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              _calificacionSeleccionada = starValue;
                            });
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              child: Icon(
                                starValue <= _calificacionSeleccionada
                                    ? Icons.star_rounded
                                    : Icons.star_outline_rounded,
                                color: starValue <= _calificacionSeleccionada
                                    ? Colors.amber.shade600
                                    : colorScheme.outline.withOpacity(0.3),
                                size: 36,
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _obtenerTextoCalificacion(_calificacionSeleccionada),
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: Colors.amber.shade900,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Mensajes sugeridos
              Align(
                alignment: Alignment.centerLeft,
                child: Row(
                  children: [
                    Icon(
                      Icons.chat_bubble_outline_rounded,
                      size: 16,
                      color: colorScheme.onSurface.withOpacity(0.6),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Mensajes rápidos',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Column(
                children: [
                  for (int i = 0; i < _mensajesSugeridos.length; i += 2)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: _buildMensajeChip(
                              _mensajesSugeridos[i],
                              theme,
                              colorScheme,
                            ),
                          ),
                          if (i + 1 < _mensajesSugeridos.length) ...[
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildMensajeChip(
                                _mensajesSugeridos[i + 1],
                                theme,
                                colorScheme,
                              ),
                            ),
                          ] else
                            const Spacer(),
                        ],
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 16),

              // Campo de comentario opcional
              TextField(
                controller: _comentarioController,
                maxLines: 2,
                style: theme.textTheme.bodyMedium,
                decoration: InputDecoration(
                  hintText: 'Escribe tu comentario (opcional)',
                  hintStyle: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurface.withOpacity(0.4),
                  ),
                  filled: true,
                  fillColor: colorScheme.surfaceVariant.withOpacity(0.3),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: colorScheme.outline.withOpacity(0.2),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: colorScheme.outline.withOpacity(0.2),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: colorScheme.primary,
                      width: 2,
                    ),
                  ),
                  contentPadding: const EdgeInsets.all(12),
                  prefixIcon: Icon(
                    Icons.edit_note_rounded,
                    color: colorScheme.onSurface.withOpacity(0.4),
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Botones de acción
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.pop(context, true);
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(
                          color: colorScheme.outline.withOpacity(0.3),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Omitir',
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: colorScheme.onSurface.withOpacity(0.6),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 3,
                    child: ElevatedButton(
                      onPressed: _enviarCalificacion,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colorScheme.primary,
                        foregroundColor: colorScheme.onPrimary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        elevation: 3,
                        shadowColor: colorScheme.primary.withOpacity(0.4),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.send_rounded, size: 18),
                          const SizedBox(width: 6),
                          Text(
                            'Enviar',
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: colorScheme.onPrimary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
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
