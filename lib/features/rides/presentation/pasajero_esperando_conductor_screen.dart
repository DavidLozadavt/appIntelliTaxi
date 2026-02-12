import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intellitaxi/core/theme/app_colors.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:intellitaxi/shared/widgets/standard_map.dart';
import 'package:intellitaxi/features/rides/services/calificacion_service.dart';
import 'package:intellitaxi/features/auth/logic/auth_provider.dart';
import 'package:intellitaxi/features/rides/logic/pasajero_servicio_activo_provider.dart';
import 'package:provider/provider.dart';

class PasajeroEsperandoConductorScreen extends StatefulWidget {
  final int servicioId;
  final Map<String, dynamic> datosServicio;

  const PasajeroEsperandoConductorScreen({
    super.key,
    required this.servicioId,
    required this.datosServicio,
  });

  @override
  State<PasajeroEsperandoConductorScreen> createState() =>
      _PasajeroEsperandoConductorScreenState();
}

class _PasajeroEsperandoConductorScreenState
    extends State<PasajeroEsperandoConductorScreen> {
  GoogleMapController? _mapController;
  final CalificacionService _calificacionService = CalificacionService();

  // 📏 Control de altura del BottomSheet
  double _sheetHeight = 0.45;
  final double _minHeight = 0.25;
  final double _maxHeight = 0.70;

  @override
  void initState() {
    super.initState();
    // La lógica ahora está en el provider
  }

  void _mostrarDialogoFinalizado(Map<String, dynamic>? conductor) {
    int calificacionSeleccionada = 5;
    final TextEditingController comentarioController = TextEditingController();

    // Mensajes sugeridos genéricos
    final List<String> mensajesSugeridos = [
      'Excelente servicio',
      'Muy amable y puntual',
      'Viaje cómodo y seguro',
      'Buen conductor',
    ];

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green, size: 32),
              SizedBox(width: 12),
              Expanded(child: Text('Viaje Finalizado')),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '¡Gracias por usar nuestro servicio!',
                  style: TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 20),
                Text(
                  'Califica a ${conductor?['conductor_nombre'] ?? 'tu conductor'}',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),

                // Estrellas de calificación
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (index) {
                    final starValue = index + 1;
                    return IconButton(
                      iconSize: 40,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      onPressed: () {
                        setDialogState(() {
                          calificacionSeleccionada = starValue;
                        });
                      },
                      icon: Icon(
                        starValue <= calificacionSeleccionada
                            ? Icons.star
                            : Icons.star_border,
                        color: Colors.amber,
                      ),
                    );
                  }),
                ),

                const SizedBox(height: 8),
                Center(
                  child: Text(
                    _obtenerTextoCalificacion(calificacionSeleccionada),
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[700],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Mensajes sugeridos
                const Text(
                  'Mensajes rápidos:',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: mensajesSugeridos.map((mensaje) {
                    return InkWell(
                      onTap: () {
                        setDialogState(() {
                          comentarioController.text = mensaje;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: AppColors.primary.withOpacity(0.3),
                          ),
                        ),
                        child: Text(
                          mensaje,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 16),

                // Campo de comentario opcional
                TextField(
                  controller: comentarioController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'Escribe tu comentario (opcional)',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    contentPadding: const EdgeInsets.all(12),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context); // Cerrar diálogo
                Navigator.pop(context, true); // Regresar a home
              },
              child: const Text('Omitir', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.send, color: Colors.white),
              label: const Text(
                'Enviar Calificación',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () async {
                print('Calificación: $calificacionSeleccionada');
                print('Comentario: ${comentarioController.text}');

                // Guardar BuildContext del State antes de operaciones async
                final scaffoldContext = this.context;

                // Cerrar diálogo de calificación
                Navigator.of(context).pop();

                // Mostrar loading usando el context del scaffold
                showDialog(
                  context: scaffoldContext,
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
                  // Obtener ID del usuario pasajero desde AuthProvider
                  final authProvider = Provider.of<AuthProvider>(
                    context,
                    listen: false,
                  );
                  final idPasajero = authProvider.userId;

                  if (idPasajero == null) {
                    throw Exception('No se pudo obtener ID del pasajero');
                  }

                  // Obtener ID del conductor de forma segura
                  final conductorData = conductor;
                  if (conductorData == null) {
                    throw Exception('No hay datos del conductor disponibles');
                  }

                  final idConductor = conductorData['conductor_id'] as int?;
                  if (idConductor == null) {
                    throw Exception('No se pudo obtener ID del conductor');
                  }

                  print('📤 Enviando calificación:');
                  print('   Servicio: ${widget.servicioId}');
                  print('   Pasajero (califica): $idPasajero');
                  print('   Conductor (calificado): $idConductor');
                  print('   Estrellas: $calificacionSeleccionada');
                  print('   Comentario: ${comentarioController.text}');

                  // Enviar calificación
                  final resultado = await _calificacionService
                      .crearCalificacion(
                        idServicio: widget.servicioId,
                        idUsuarioCalifica: idPasajero,
                        idUsuarioCalificado: idConductor,
                        tipoCalificacion: 'CONDUCTOR',
                        calificacion: calificacionSeleccionada,
                        comentario: comentarioController.text.trim().isEmpty
                            ? null
                            : comentarioController.text.trim(),
                      );

                  print('✅ Calificación enviada: ID ${resultado.id}');

                  // Cerrar loading de forma segura
                  if (mounted) {
                    Navigator.of(scaffoldContext, rootNavigator: true).pop();
                  }

                  // Mostrar mensaje de éxito
                  if (mounted) {
                    ScaffoldMessenger.of(scaffoldContext).showSnackBar(
                      const SnackBar(
                        content: Text('✅ ¡Gracias por tu calificación!'),
                        backgroundColor: Colors.green,
                        duration: Duration(seconds: 2),
                      ),
                    );
                  }

                  // Esperar un momento para que se vea el snackbar
                  await Future.delayed(const Duration(milliseconds: 500));

                  // Regresar a home
                  if (mounted) {
                    Navigator.of(scaffoldContext).pop(true);
                  }
                } catch (e) {
                  print('❌ Error enviando calificación: $e');

                  // Cerrar loading de forma segura
                  if (mounted) {
                    Navigator.of(scaffoldContext, rootNavigator: true).pop();
                  }

                  // Mostrar error
                  if (mounted) {
                    ScaffoldMessenger.of(scaffoldContext).showSnackBar(
                      SnackBar(
                        content: Text('Error al enviar calificación: $e'),
                        backgroundColor: Colors.red,
                        duration: const Duration(seconds: 3),
                      ),
                    );
                  }

                  // Esperar un momento
                  await Future.delayed(const Duration(milliseconds: 500));

                  // Regresar a home de todas formas
                  if (mounted) {
                    Navigator.of(scaffoldContext).pop(true);
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
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

  Future<void> _llamarConductor(String? telefono) async {
    if (telefono != null) {
      // TODO: Implementar llamada telefónica
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Llamar a: $telefono'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  /// ⏰ Muestra diálogo cuando se agota el tiempo de espera
  Future<void> _mostrarDialogoTimeout(
    BuildContext context,
    PasajeroServicioActivoProvider provider,
  ) async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.timer_off, color: Colors.orange.shade700, size: 32),
            const SizedBox(width: 12),
            const Expanded(child: Text('Sin conductores disponibles')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'No hemos encontrado conductores disponibles en este momento.',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '💡 Sugerencias:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text('• Intenta nuevamente en unos momentos'),
                  Text('• Verifica tu ubicación'),
                  Text('• Puede ser hora de alta demanda'),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => _cancelarServicio(context, provider),
            child: const Text(
              'Cancelar solicitud',
              style: TextStyle(color: Colors.red),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              provider.reintentar();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('🔄 Buscando conductor nuevamente...'),
                  backgroundColor: Colors.blue,
                  duration: Duration(seconds: 2),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.white,
            ),
            child: const Text('Reintentar'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmarCancelarServicioActivo() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Cancelar servicio?'),
        content: const Text(
          'Estás a punto de cancelar tu servicio activo. '
          'El conductor ya está en camino. ¿Estás seguro?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Sí, cancelar'),
          ),
        ],
      ),
    );

    if (confirmar == true && mounted) {
      final provider = Provider.of<PasajeroServicioActivoProvider>(
        context,
        listen: false,
      );
      await _cancelarServicio(context, provider);
    }
  }

  /// 🚫 Cancela el servicio y regresa a la pantalla anterior
  Future<void> _cancelarServicio(
    BuildContext dialogContext,
    PasajeroServicioActivoProvider provider,
  ) async {
    try {
      // Determinar el motivo según el estado
      String motivo;
      if (provider.estadoServicio == 'buscando') {
        motivo = 'Cancelado por el pasajero - No se encontró conductor';
      } else {
        motivo = 'Cancelado por el pasajero';
      }

      // Mostrar loading
      Navigator.pop(dialogContext);
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Cancelando solicitud...'),
                ],
              ),
            ),
          ),
        ),
      );

      // Llamar al provider para cancelar
      await provider.cancelarServicio(motivo: motivo);

      if (!mounted) return;

      // Cerrar loading
      Navigator.pop(context);

      // Volver a la pantalla anterior
      Navigator.pop(context);

      // Mostrar mensaje de confirmación
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Servicio cancelado'),
          backgroundColor: Colors.grey,
          duration: Duration(seconds: 3),
        ),
      );
    } catch (e) {
      print('❌ Error cancelando servicio: $e');

      if (!mounted) return;

      Navigator.pop(context); // Cerrar loading
      Navigator.pop(context); // Volver a home

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al cancelar: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => PasajeroServicioActivoProvider(
        servicioId: widget.servicioId,
        datosServicio: widget.datosServicio,
      ),
      child: Consumer<PasajeroServicioActivoProvider>(
        builder: (context, provider, _) {
          // Listener para mostrar diálogos según el estado
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (provider.estadoServicio == 'timeout' && mounted) {
              _mostrarDialogoTimeout(context, provider);
            } else if (provider.estadoServicio == 'finalizado' && mounted) {
              _mostrarDialogoFinalizado(provider.conductor);
            }
          });

          return PopScope(
            canPop: false,
            onPopInvoked: (didPop) {
              if (!didPop) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'No puedes salir hasta que el servicio termine',
                    ),
                    backgroundColor: AppColors.accent,
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            },
            child: Scaffold(
              appBar: AppBar(
                title: const Text(
                  'Servicio Activo',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                automaticallyImplyLeading: false,
              ),
              body: Stack(
                children: [
                  StandardMap(
                    initialPosition: LatLng(
                      _parseDouble(widget.datosServicio['origen_lat']),
                      _parseDouble(widget.datosServicio['origen_lng']),
                    ),
                    zoom: 14,
                    markers: provider.markers,
                    polylines: provider.polylines,
                    onMapCreated: (controller) {
                      _mapController = controller;
                      // Centrar mapa si hay ubicación del conductor
                      if (provider.conductorUbicacion != null) {
                        final bounds = provider.calcularBounds();
                        controller.animateCamera(
                          CameraUpdate.newLatLngBounds(bounds, 100),
                        );
                      }
                    },
                  ),

                  // Panel de información draggable
                  if (!provider.isBuscando)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: GestureDetector(
                        onVerticalDragUpdate: (details) {
                          setState(() {
                            final screenHeight = MediaQuery.of(
                              context,
                            ).size.height;
                            final delta = -details.primaryDelta! / screenHeight;
                            _sheetHeight = (_sheetHeight + delta).clamp(
                              _minHeight,
                              _maxHeight,
                            );
                          });
                        },
                        onVerticalDragEnd: (details) {
                          final velocity = details.primaryVelocity ?? 0;
                          if (velocity.abs() > 500) {
                            setState(() {
                              if (velocity > 0) {
                                _sheetHeight = _minHeight;
                              } else {
                                _sheetHeight = _maxHeight;
                              }
                            });
                          }
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          height:
                              MediaQuery.of(context).size.height * _sheetHeight,
                          child: _buildPanelInfo(provider),
                        ),
                      ),
                    ),

                  // Loading mientras busca conductor
                  if (provider.isBuscando)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: _buildBuscandoConductor(provider),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBuscandoConductor(PasajeroServicioActivoProvider provider) {
    final remainingSeconds = provider.remainingSeconds;
    final minutes = remainingSeconds ~/ 60;
    final seconds = remainingSeconds % 60;

    return Container(
      padding: const EdgeInsets.all(30),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 60,
                height: 60,
                child: CircularProgressIndicator(
                  value: provider.elapsedSeconds / 120,
                  strokeWidth: 4,
                  backgroundColor: Colors.grey.shade300,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    remainingSeconds > 30 ? AppColors.accent : Colors.orange,
                  ),
                ),
              ),
              Text(
                '$minutes:${seconds.toString().padLeft(2, '0')}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Text(
            'Buscando conductor disponible...',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Text(
            'Por favor espera mientras encontramos un conductor cerca de ti',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[600]),
          ),
          const SizedBox(height: 16),
          TextButton.icon(
            onPressed: () => _cancelarServicio(context, provider),
            icon: const Icon(Iconsax.close_circle_copy, size: 18),
            label: const Text('Cancelar búsqueda'),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
          ),
        ],
      ),
    );
  }

  Widget _buildPanelInfo(PasajeroServicioActivoProvider provider) {
    final estadosInfo = {
      'aceptado': {
        'texto': '🚗 Conductor en camino',
        'color': AppColors.green,
        'icono': Iconsax.car_copy,
      },
      'en_camino': {
        'texto': '🚗 Conductor en camino',
        'color': AppColors.green,
        'icono': Iconsax.car_copy,
      },
      'llegue': {
        'texto': '📍 Conductor ha llegado',
        'color': AppColors.accent,
        'icono': Iconsax.location_copy,
      },
      'en_curso': {
        'texto': '🏁 Viaje en curso',
        'color': AppColors.green,
        'icono': Iconsax.routing_2_copy,
      },
    };

    final info =
        estadosInfo[provider.estadoServicio] ??
        {
          'texto': 'Servicio activo',
          'color': AppColors.grey,
          'icono': Iconsax.info_circle_copy,
        };

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 15,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle draggable
          GestureDetector(
            onTap: () {
              setState(() {
                _sheetHeight = _sheetHeight < 0.4 ? 0.45 : _minHeight;
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Container(
                width: 50,
                height: 5,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildEstadoRow(info, provider),
                  const SizedBox(height: 12),
                  _buildConductorInfo(provider),
                  const SizedBox(height: 12),
                  _buildCancelarButton(provider),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEstadoRow(
    Map<String, dynamic> info,
    PasajeroServicioActivoProvider provider,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: (info['color'] as Color).withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                info['icono'] as IconData,
                color: info['color'] as Color,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              info['texto'] as String,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: info['color'] as Color,
              ),
            ),
          ],
        ),
        IconButton(
          icon: Icon(Iconsax.call, color: AppColors.green, size: 26),
          onPressed: () =>
              _llamarConductor(provider.conductor?['conductor_telefono']),
          tooltip: 'Llamar conductor',
        ),
      ],
    );
  }

  Widget _buildConductorInfo(PasajeroServicioActivoProvider provider) {
    final conductor = provider.conductor;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withOpacity(0.2), width: 1),
      ),
      child: Row(
        children: [
          // Avatar
          conductor?['conductor_foto'] != null &&
                  conductor!['conductor_foto'].toString().isNotEmpty
              ? CircleAvatar(
                  radius: 22,
                  backgroundColor: AppColors.primary.withOpacity(0.1),
                  backgroundImage: NetworkImage(conductor['conductor_foto']),
                  onBackgroundImageError: (exception, stackTrace) {
                    print('⚠️ Error cargando foto del conductor: $exception');
                  },
                )
              : CircleAvatar(
                  radius: 22,
                  backgroundColor: AppColors.primary,
                  child: const Icon(
                    Iconsax.user_copy,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        conductor?['conductor_nombre'] ?? 'Conductor',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(
                      Iconsax.star_1_copy,
                      color: AppColors.secondary,
                      size: 14,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      '${conductor?['conductor_calificacion'] ?? 5.0}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Text(
                      '${conductor?['vehiculo_marca'] ?? ''} ${conductor?['vehiculo_modelo'] ?? ''}'
                          .trim(),
                      style: TextStyle(fontSize: 12, color: AppColors.grey),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black87,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        conductor?['vehiculo_placa'] ?? '---',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCancelarButton(PasajeroServicioActivoProvider provider) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () => _confirmarCancelarServicioActivo(),
        icon: const Icon(Iconsax.close_circle_copy, size: 18),
        label: const Text(
          'Cancelar servicio',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.error,
          side: const BorderSide(color: AppColors.error, width: 1.5),
          padding: const EdgeInsets.symmetric(vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
    );
  }

  double _parseDouble(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }
}
