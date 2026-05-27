import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intellitaxi/core/theme/app_colors.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:intellitaxi/shared/widgets/standard_map.dart';
import 'package:intellitaxi/features/rides/widgets/calificacion_conductor_dialog.dart';
import 'package:intellitaxi/features/pasajero/providers/pasajero_servicio_activo_provider.dart';
import 'package:intellitaxi/features/chat/utils/chat_helper.dart';
import 'package:intellitaxi/features/auth/providers/auth_provider.dart';
import 'package:intellitaxi/core/services/active_service_screen_registry.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intellitaxi/core/navigation/app_root_navigation.dart';
import 'package:intellitaxi/core/services/app_logger.dart';
import 'package:intellitaxi/core/services/pasajero_servicio_notification_helper.dart';

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
  bool _driverCameraCentered = false;
  String? _lastMapCameraKey;
  bool _terminalFlowStarted = false;
  bool _timeoutDialogShown = false;
  /// Evita que el post-frame dispare salida remota mientras cancelamos manualmente (misma petición).
  bool _cancelacionManualEnCurso = false;

  // 📏 Control de altura del BottomSheet
  double _sheetHeight = 0.45;
  final double _minHeight = 0.25;
  final double _maxHeight = 0.70;

  @override
  void initState() {
    super.initState();
    ActiveServiceScreenRegistry.markVisible(
      type: 'pasajero',
      serviceId: widget.servicioId,
    );
    unawaited(
      PasajeroServicioNotificationHelper.clearForServicio(widget.servicioId),
    );
  }

  Future<void> _mostrarDialogoFinalizado(
    Map<String, dynamic>? conductor,
  ) async {
    final resultado = await CalificacionConductorDialog.show(
      context,
      servicioId: widget.servicioId,
      conductor: conductor,
    );

    // Después de calificar, navegar al home
    if (mounted && resultado == true) {
      // Esperar un poco para que se procesen las actualizaciones
      await Future.delayed(const Duration(milliseconds: 500));

      if (mounted) {
        navigateReplacingStackWithHome(context: context);
      }
    }
  }

  Future<void> _manejarServicioCancelado() async {
    if (!mounted) return;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      const SnackBar(
        content: Text('❌ El servicio fue cancelado'),
        backgroundColor: Colors.grey,
        duration: Duration(seconds: 2),
      ),
    );
    navigateReplacingStackWithHome(context: context);
  }

  Future<void> _abrirChat() async {
    final authProvider = context.read<AuthProvider>();
    await ChatHelper.abrirChat(
      context: context,
      servicioId: widget.servicioId,
      miUserId: authProvider.userId ?? 0,
    );
  }

  Future<void> _llamarConductor(String? telefono) async {
    if (telefono == null || telefono.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No hay teléfono del conductor disponible'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    final limpio = telefono.replaceAll(RegExp(r'[^0-9+]'), '');
    final telUri = Uri.parse('tel:$limpio');

    if (await canLaunchUrl(telUri)) {
      await launchUrl(telUri, mode: LaunchMode.externalApplication);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo abrir la aplicación de llamadas'),
          duration: Duration(seconds: 2),
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
                // color: Colors.blue.shade50,
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
            onPressed: () {
              Navigator.pop(context);
              _cancelarServicio(provider);
            },
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

  /// 🚫 Cancela el servicio y regresa a la pantalla anterior
  Future<void> _cancelarServicio(
    PasajeroServicioActivoProvider provider,
  ) async {
    if (_cancelacionManualEnCurso) return;
    _cancelacionManualEnCurso = true;
    _terminalFlowStarted = true;

    String motivo;
    if (provider.estadoServicio == 'buscando') {
      motivo = 'Cancelado por el pasajero - No se encontró conductor';
    } else {
      motivo = 'Cancelado por el pasajero';
    }

    if (!mounted) {
      _cancelacionManualEnCurso = false;
      _terminalFlowStarted = false;
      return;
    }

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (ctx) => Center(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildCustomLoader(size: 54),
                const SizedBox(height: 16),
                Text(
                  'Cancelando solicitud...',
                  style: Theme.of(ctx).textTheme.bodyLarge,
                ),
              ],
            ),
          ),
        ),
      ),
    );

    var okRemoto = false;
    try {
      okRemoto = await provider.cancelarServicio(motivo: motivo);
    } catch (e) {
      AppLogger.d('❌ Error cancelando servicio: $e');
      okRemoto = false;
    }

    if (!mounted) {
      _cancelacionManualEnCurso = false;
      _terminalFlowStarted = false;
      return;
    }

    // Cierra el overlay de “Cancelando…” sin asumir qué hay encima de la pila.
    try {
      Navigator.of(context, rootNavigator: true).pop();
    } catch (e) {
      AppLogger.d('⚠️ Cerrando diálogo de cancelación: $e');
    }

    if (!okRemoto) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(
          content: Text(
            'No se pudo confirmar la cancelación en el servidor. '
            'Puedes revisar tu servicio en el mapa o intentar de nuevo.',
          ),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 4),
        ),
      );
    }

    if (!mounted) {
      _cancelacionManualEnCurso = false;
      _terminalFlowStarted = false;
      return;
    }
    navigateReplacingStackWithHome(context: context);
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
          _tryUpdateMapCamera(provider);
          _tryCenterToDriver(provider);

          // Listener para mostrar diálogos según el estado
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;

            if (provider.estadoServicio == 'timeout' && !_timeoutDialogShown) {
              _timeoutDialogShown = true;
              _mostrarDialogoTimeout(context, provider).whenComplete(() {
                _timeoutDialogShown = false;
              });
              return;
            }

            if (_terminalFlowStarted) return;

            if (provider.estadoServicio == 'cancelado' &&
                !_cancelacionManualEnCurso) {
              _terminalFlowStarted = true;
              _manejarServicioCancelado();
            } else if (provider.estadoServicio == 'finalizado') {
              _terminalFlowStarted = true;
              _mostrarDialogoFinalizado(provider.conductor);
            }
          });

          return PopScope(
            canPop: false,
            onPopInvokedWithResult: (didPop, _) {
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
                title: Text(
                  provider.isBuscando
                      ? 'Buscando conductor'
                      : 'Servicio activo',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                automaticallyImplyLeading: false,
              ),
              body: Stack(
                children: [
                  // Mapa de Google Maps
                  StandardMap(
                    initialPosition: LatLng(
                      _parseDouble(widget.datosServicio['origen_lat']) != 0.0
                          ? _parseDouble(widget.datosServicio['origen_lat'])
                          : -12.0464, // Lima, Perú como fallback
                      _parseDouble(widget.datosServicio['origen_lng']) != 0.0
                          ? _parseDouble(widget.datosServicio['origen_lng'])
                          : -77.0428,
                    ),
                    zoom: 14,
                    markers: provider.markers,
                    polylines: provider.polylines,
                    onMapCreated: (controller) {
                      _mapController = controller;
                      _lastMapCameraKey = null;
                      _tryUpdateMapCamera(provider);
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

  void _tryUpdateMapCamera(PasajeroServicioActivoProvider provider) {
    if (_mapController == null) return;
    if (provider.polylines.isEmpty && provider.conductorUbicacion == null) {
      return;
    }

    final cameraKey =
        '${provider.polylines.length}_'
        '${provider.conductorUbicacion?.latitude}_'
        '${provider.conductorUbicacion?.longitude}';
    if (cameraKey == _lastMapCameraKey) return;
    _lastMapCameraKey = cameraKey;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _mapController == null) return;
      try {
        _mapController!.animateCamera(
          CameraUpdate.newLatLngBounds(provider.calcularBounds(), 90),
        );
      } catch (_) {
        // Ignorar errores de cámara intermitentes durante reconstrucción del mapa.
      }
    });
  }

  void _tryCenterToDriver(PasajeroServicioActivoProvider provider) {
    if (_driverCameraCentered) return;
    if (_mapController == null) return;
    if (provider.conductorUbicacion == null) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          _mapController == null ||
          provider.conductorUbicacion == null) {
        return;
      }
      try {
        final bounds = provider.calcularBounds();
        _mapController!.animateCamera(
          CameraUpdate.newLatLngBounds(bounds, 100),
        );
        _driverCameraCentered = true;
      } catch (_) {
        // Ignorar errores de cámara intermitentes durante reconstrucción del mapa.
      }
    });
  }

  Widget _buildBuscandoConductor(PasajeroServicioActivoProvider provider) {
    final remainingSeconds = provider.remainingSeconds;
    final minutes = remainingSeconds ~/ 60;
    final seconds = remainingSeconds % 60;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final origenAddr =
        widget.datosServicio['origen_address']?.toString().trim() ?? '';
    final destinoAddr =
        widget.datosServicio['destino_address']?.toString().trim() ?? '';
    final cerca = provider.conductoresCercanosCount;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 14,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildCustomLoader(
                size: 52,
                progress: provider.elapsedSeconds / 120,
                color: remainingSeconds > 30 ? AppColors.accent : Colors.orange,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$minutes:${seconds.toString().padLeft(2, '0')}',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      'Tiempo de búsqueda',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.textTheme.bodySmall?.color
                            ?.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
              _buildConductoresCercaChip(
                theme: theme,
                count: cerca,
                loading: provider.cargandoConductoresCercanos,
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildPasosBusqueda(provider.elapsedSeconds),
          const SizedBox(height: 14),
          if (origenAddr.isNotEmpty) ...[
            _buildDireccionResumen(
              label: 'Recogida',
              address: origenAddr,
              color: AppColors.green,
              icon: Iconsax.location_copy,
            ),
            if (destinoAddr.isNotEmpty &&
                destinoAddr != 'Destino no definido') ...[
              const SizedBox(height: 8),
              _buildDireccionResumen(
                label: 'Destino',
                address: destinoAddr,
                color: AppColors.primary,
                icon: Iconsax.routing_2_copy,
              ),
            ],
            const SizedBox(height: 14),
          ],
          Text(
            provider.mensajeActividadBusqueda,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            provider.subtituloActividadBusqueda,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.78),
              height: 1.35,
            ),
          ),
          const SizedBox(height: 18),
          TextButton.icon(
            onPressed: () => _cancelarServicio(provider),
            icon: const Icon(Iconsax.close_circle_copy, size: 18),
            label: const Text('Cancelar búsqueda'),
            style: TextButton.styleFrom(foregroundColor: cs.error),
          ),
        ],
      ),
    );
  }

  Widget _buildConductoresCercaChip({
    required ThemeData theme,
    required int count,
    required bool loading,
  }) {
    final Color bg;
    final String label;
    final IconData icon;
    if (loading && count == 0) {
      bg = AppColors.primary.withValues(alpha: 0.12);
      label = 'Revisando…';
      icon = Iconsax.refresh_copy;
    } else if (count > 0) {
      bg = AppColors.green.withValues(alpha: 0.14);
      label = count == 1 ? '1 cerca' : '$count cerca';
      icon = Iconsax.car_copy;
    } else {
      bg = Colors.orange.withValues(alpha: 0.12);
      label = 'Sin taxis';
      icon = Iconsax.search_normal_1_copy;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: bg.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.primary),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPasosBusqueda(int elapsedSeconds) {
    final step = elapsedSeconds < 8
        ? 0
        : elapsedSeconds < 40
        ? 1
        : 2;
    const labels = [
      'Solicitud enviada',
      'Avisando conductores',
      'Esperando respuesta',
    ];

    return Row(
      children: List.generate(labels.length * 2 - 1, (i) {
        if (i.isOdd) {
          final lineDone = (i ~/ 2) < step;
          return Expanded(
            child: Container(
              height: 2,
              margin: const EdgeInsets.only(bottom: 18),
              color: lineDone
                  ? AppColors.green
                  : AppColors.primary.withValues(alpha: 0.2),
            ),
          );
        }
        final index = i ~/ 2;
        final done = index < step;
        final active = index == step;
        return Expanded(
          child: Column(
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: done || active
                      ? (done ? AppColors.green : AppColors.accent)
                      : AppColors.primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  done
                      ? Icons.check
                      : active
                      ? Icons.more_horiz
                      : Icons.circle,
                  size: done ? 16 : 10,
                  color: done || active ? Colors.white : AppColors.grey,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                labels[index],
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: active ? FontWeight.w800 : FontWeight.w500,
                  color: active ? AppColors.accent : AppColors.grey,
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildDireccionResumen({
    required String label,
    required String address,
    required Color color,
    required IconData icon,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: color,
                  letterSpacing: 0.4,
                ),
              ),
              Text(
                address,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPanelInfo(PasajeroServicioActivoProvider provider) {
    final estadosInfo = {
      'aceptado': {
        'texto': 'Conductor en camino',
        'color': AppColors.green,
        'icono': Iconsax.car_copy,
      },
      'en_camino': {
        'texto': 'Conductor en camino',
        'color': AppColors.green,
        'icono': Iconsax.car_copy,
      },
      'llegue': {
        'texto': 'Conductor ha llegado',
        'color': AppColors.accent,
        'icono': Iconsax.location_copy,
      },
      'en_curso': {
        'texto': 'Viaje en curso',
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
            color: Colors.black.withValues(alpha: 0.15),
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
                  color: AppColors.primary.withValues(alpha: 0.5),
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
      children: [
        Expanded(
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: (info['color'] as Color).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  info['icono'] as IconData,
                  color: info['color'] as Color,
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  info['texto'] as String,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: info['color'] as Color,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        _buildAccionRapida(
          icon: Iconsax.call,
          color: AppColors.green,
          tooltip: 'Llamar conductor',
          onTap: () =>
              _llamarConductor(provider.conductor?['conductor_telefono']),
        ),
        const SizedBox(width: 6),
        _buildAccionRapida(
          icon: Iconsax.messages_copy,
          color: AppColors.accent,
          tooltip: 'Mensaje',
          onTap: _abrirChat,
        ),
      ],
    );
  }

  Widget _buildAccionRapida({
    required IconData icon,
    required Color color,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Material(
      color: color.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Tooltip(
          message: tooltip,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Icon(icon, color: color, size: 22),
          ),
        ),
      ),
    );
  }

  Widget _buildConductorInfo(PasajeroServicioActivoProvider provider) {
    final conductor = provider.conductor;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Avatar
          conductor?['conductor_foto'] != null &&
                  conductor!['conductor_foto'].toString().isNotEmpty
              ? CircleAvatar(
                  radius: 22,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                  backgroundImage: NetworkImage(conductor['conductor_foto']),
                  onBackgroundImageError: (exception, stackTrace) {
                    AppLogger.d(
                      '⚠️ Error cargando foto del conductor: $exception',
                    );
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
        onPressed: () => _cancelarServicio(provider),
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

  Widget _buildCustomLoader({
    double size = 44,
    double? progress,
    Color color = AppColors.accent,
  }) {
    final logoSize = size * 0.48;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              value: progress,
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(color),
              backgroundColor: AppColors.primary.withValues(alpha: 0.15),
            ),
          ),
          Container(
            width: logoSize,
            height: logoSize,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            // Tin de marca en modo claro para mantener identidad visual.
            foregroundDecoration: Theme.of(context).brightness == Brightness.dark
                ? null
                : BoxDecoration(
                    color: AppColors.brandWine.withValues(alpha: 0.6),
                    backgroundBlendMode: BlendMode.modulate,
                  ),
            child: Image.asset('assets/images/logoTaxbel.webp'),
          ),
        ],
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
    ActiveServiceScreenRegistry.markHidden(
      type: 'pasajero',
      serviceId: widget.servicioId,
    );
    _mapController?.dispose();
    super.dispose();
  }
}
