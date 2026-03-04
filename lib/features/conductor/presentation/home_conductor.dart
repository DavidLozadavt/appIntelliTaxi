import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import 'package:intellitaxi/core/theme/app_colors.dart';
import 'package:intellitaxi/features/auth/providers/auth_provider.dart';
import 'package:intellitaxi/features/conductor/widgets/vehiculo_selection_sheet.dart';
import 'package:intellitaxi/features/conductor/widgets/documentos_alert_dialog.dart';
import 'package:intellitaxi/features/conductor/widgets/solicitud_servicio_card.dart';
import 'package:intellitaxi/features/conductor/presentation/conductor_servicio_activo_screen.dart';
import 'package:intellitaxi/core/services/servicio_payload_adapter.dart';
import 'package:intellitaxi/core/services/app_logger.dart';
import 'package:intellitaxi/shared/widgets/standard_map.dart';
import 'package:intellitaxi/features/conductor/providers/conductor_home_provider.dart';
import 'package:intellitaxi/features/sanciones/data/sancion_model.dart';
import 'package:intellitaxi/features/sanciones/services/sancion_service.dart';
import 'package:intellitaxi/core/widgets/location_status_view.dart';

class HomeConductor extends StatefulWidget {
  final List<dynamic> stories;

  const HomeConductor({super.key, required this.stories});

  @override
  State<HomeConductor> createState() => _HomeConductorState();
}

class _HomeConductorState extends State<HomeConductor> {
  GoogleMapController? _mapController;
  late ConductorHomeProvider _provider;

  // Sanciones
  final SancionService _sancionService = SancionService();
  List<Sancion> _sanciones = [];
  bool _bannerVisible = true;
  Timer? _bannerTimer;

  // Marcador personalizado
  BitmapDescriptor? _dotMarker;
  final GlobalKey _tutorialMapKey = GlobalKey();
  final GlobalKey _tutorialStatusKey = GlobalKey();
  final GlobalKey _tutorialLocationKey = GlobalKey();
  bool _tutorialShown = false;
  bool _tutorialInProgress = false;

  @override
  void initState() {
    super.initState();
    _provider = ConductorHomeProvider();
    _provider.initialize();
    _cargarSanciones();
    _crearDotMarker();
  }

  Future<void> _crearDotMarker() async {
    const double s = 36;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const color = Color(0xFFFF6B35); // Naranja

    // Sombra
    canvas.drawCircle(
      const Offset(s / 2, s / 2 + 1),
      s / 3,
      Paint()
        ..color = color.withValues(alpha: 0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    // Borde blanco
    canvas.drawCircle(
      const Offset(s / 2, s / 2),
      s / 3,
      Paint()..color = Colors.white,
    );
    // Círculo interior naranja
    canvas.drawCircle(
      const Offset(s / 2, s / 2),
      s / 4,
      Paint()..color = color,
    );

    final picture = recorder.endRecording();
    final image = await picture.toImage(s.toInt(), s.toInt());
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);

    if (mounted) {
      setState(() {
        _dotMarker = BitmapDescriptor.bytes(bytes!.buffer.asUint8List());
      });
    }
  }

  Future<void> _cargarSanciones() async {
    try {
      final sanciones = await _sancionService.getMisSanciones();
      if (mounted) {
        setState(() {
          _sanciones = sanciones;
        });
        if (_sancionesActivas.isNotEmpty) {
          _bannerTimer?.cancel();
          _bannerTimer = Timer(const Duration(seconds: 5), () {
            if (mounted) setState(() => _bannerVisible = false);
          });
        }
      }
    } catch (_) {
      // Silencioso - no bloquear el home si falla
    }
  }

  List<Sancion> get _sancionesActivas =>
      _sanciones.where((s) => s.estaActiva).toList();

  Future<void> _tryShowConductorTutorial() async {
    if (!mounted || _tutorialShown || _tutorialInProgress) return;
    if (_provider.currentPosition == null) return;

    _tutorialInProgress = true;
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final uid = auth.user?.id ?? 0;
      final prefs = await SharedPreferences.getInstance();
      final prefKey = 'tutorial_conductor_home_v1_$uid';
      final alreadySeen = prefs.getBool(prefKey) ?? false;
      if (alreadySeen) {
        _tutorialShown = true;
        return;
      }

      await Future.delayed(const Duration(milliseconds: 220));
      if (!mounted) return;

      final targets = <TargetFocus>[
        TargetFocus(
          identify: 'mapa_conductor',
          keyTarget: _tutorialMapKey,
          contents: [
            TargetContent(
              align: ContentAlign.bottom,
              child: const _TutorialBubble(
                title: 'Mapa de operación',
                text:
                    'Aquí ves tu ubicación en tiempo real mientras recibes servicios.',
              ),
            ),
          ],
        ),
        TargetFocus(
          identify: 'estado_conductor',
          keyTarget: _tutorialStatusKey,
          contents: [
            TargetContent(
              align: ContentAlign.bottom,
              child: const _TutorialBubble(
                title: 'Tu estado',
                text:
                    'Toca aquí para ponerte en línea o desconectarte del sistema.',
              ),
            ),
          ],
        ),
        TargetFocus(
          identify: 'ubicacion_conductor',
          keyTarget: _tutorialLocationKey,
          contents: [
            TargetContent(
              align: ContentAlign.left,
              child: const _TutorialBubble(
                title: 'Actualizar ubicación',
                text:
                    'Usa este botón para refrescar tu ubicación si cambias de zona.',
              ),
            ),
          ],
        ),
      ];

      TutorialCoachMark(
        targets: targets,
        colorShadow: Colors.black,
        opacityShadow: 0.75,
        textSkip: 'Saltar',
        paddingFocus: 10,
        onFinish: () async {
          await prefs.setBool(prefKey, true);
          _tutorialShown = true;
        },
        onSkip: () {
          prefs.setBool(prefKey, true);
          _tutorialShown = true;
          return true;
        },
      ).show(context: context);
    } finally {
      _tutorialInProgress = false;
    }
  }

  double get _porcentajeRiesgo {
    final activas = _sancionesActivas;
    if (activas.isEmpty) return 0.0;
    double puntos = 0;
    for (final s in activas) {
      switch (s.gravedad.toUpperCase()) {
        case 'GRAVE':
          puntos += 4;
          break;
        case 'ALTO':
          puntos += 2;
          break;
        default:
          puntos += 1;
          break;
      }
    }
    return (puntos / 10).clamp(0.0, 1.0);
  }

  @override
  void dispose() {
    _bannerTimer?.cancel();
    _mapController?.dispose();
    _provider.dispose();
    super.dispose();
  }

  String _getSolicitudId(Map<String, dynamic> solicitud) {
    return (solicitud['solicitud_id'] ??
            solicitud['servicio_id'] ??
            solicitud['id'] ??
            solicitud['request_id'] ??
            '')
        .toString();
  }

  /// Acepta la solicitud de servicio
  void _aceptarSolicitud(String solicitudId) async {
    final solicitud = _provider.solicitudesOrdenadas.firstWhere(
      (s) => _getSolicitudId(s) == solicitudId,
      orElse: () => {},
    );

    if (solicitud.isEmpty) {
      AppLogger.d('⚠️ Solicitud no encontrada: $solicitudId');
      return;
    }

    AppLogger.d('👉 Intentando aceptar solicitud ID: $solicitudId');

    // Obtener datos necesarios
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final conductorId = authProvider.user?.id;

    if (conductorId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error: No se pudo identificar al conductor'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Nota: No se calcula precio porque funciona con taxímetro

    // Mostrar loading
    bool loadingShown = false;
    if (mounted) {
      loadingShown = true;
      showDialog(
        context: context,
        useRootNavigator: true,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );
    }

    void closeLoadingIfNeeded() {
      if (!mounted || !loadingShown) return;
      loadingShown = false;
      Navigator.of(context, rootNavigator: true).pop();
    }

    try {
      // Llamar al provider para aceptar
      final response = await _provider.aceptarSolicitud(
        solicitudId,
        _provider.vehiculoSeleccionado?.id ?? 0,
      );

      closeLoadingIfNeeded();

      if (response == null) {
        throw Exception(
          _provider.lastAcceptError ?? 'No se pudo aceptar la solicitud',
        );
      }

      // Mostrar éxito
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '✅ Servicio aceptado: ${solicitud['pasajero_nombre'] ?? 'Pasajero'}',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }

      AppLogger.d('✅ Solicitud $solicitudId aceptada exitosamente');

      // Navegar a la pantalla de servicio activo del conductor
      if (mounted && response['servicio'] != null) {
        try {
          // Obtener conductor ID del auth provider
          final authProvider = Provider.of<AuthProvider>(
            context,
            listen: false,
          );
          final conductorId = authProvider.user?.id ?? 0;

          final servicioNormalizado = ServicioPayloadAdapter.normalize(
            servicio: Map<String, dynamic>.from(response['servicio']),
            pasajero: response['pasajero'] != null
                ? Map<String, dynamic>.from(response['pasajero'])
                : null,
            conductor: response['conductor'] != null
                ? Map<String, dynamic>.from(response['conductor'])
                : null,
            vehiculo: response['vehiculo'] != null
                ? Map<String, dynamic>.from(response['vehiculo'])
                : null,
          );

          // Navegar a ConductorServicioActivoScreen pasando el objeto servicio
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ConductorServicioActivoScreen(
                servicio: servicioNormalizado,
                conductorId: conductorId,
              ),
            ),
          );
        } catch (e) {
          AppLogger.d('⚠️ Error procesando servicio activo: $e');
        }
      }
    } catch (e) {
      closeLoadingIfNeeded();

      // Mostrar error con el mensaje del backend
      String errorMsg = e.toString().replaceAll('Exception: ', '');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }

      AppLogger.d('⚠️ Error al aceptar solicitud: $e');
    }
  }

  /// Rechaza la solicitud de servicio
  void _rechazarSolicitud(String solicitudId) async {
    AppLogger.d('❌ Solicitud rechazada: $solicitudId');

    final solicitud = _provider.solicitudesOrdenadas.firstWhere(
      (s) => _getSolicitudId(s) == solicitudId,
      orElse: () => {},
    );
    final isOfertaDirecta = solicitud['status'] == 'oferta_directa';
    final servicioId = int.tryParse(solicitudId);

    if (isOfertaDirecta && servicioId != null) {
      final ok = await _provider.cancelarServicio(
        servicioId: servicioId,
        motivo: 'Oferta directa rechazada por conductor',
      );

      if (!mounted) return;

      if (ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Oferta directa rechazada y cancelada'),
            backgroundColor: Colors.orange,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo cancelar la oferta directa'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Solicitud rechazada'),
          backgroundColor: Colors.red,
        ),
      );
    }

    _provider.rechazarSolicitud(solicitudId);
  }

  /// Verifica documentos del conductor y muestra alertas
  Future<void> _verificarDocumentos() async {
    if (!mounted) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userId = authProvider.user?.id;
    if (userId == null) return;

    final resultado = await _provider.verificarDocumentos(userId);
    final vencidos = resultado['vencidos'] ?? [];
    final porVencer = resultado['porVencer'] ?? [];

    if ((vencidos.isNotEmpty || porVencer.isNotEmpty) && mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => DocumentosAlertDialog(
          documentosVencidos: vencidos,
          documentosPorVencer: porVencer,
        ),
      );
    }
  }

  /// Muestra el selector de vehículo
  Future<void> _mostrarSelectorVehiculo() async {
    if (!mounted) return;

    // Guardar referencia al messenger antes de operaciones asíncronas
    final messenger = ScaffoldMessenger.of(context);

    if (_provider.vehiculosDisponibles.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('No tienes vehículos asignados'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final Map<int, int> vencidosPorVehiculo = {};
    for (final vehiculo in _provider.vehiculosDisponibles) {
      final bloqueo = await _provider.verificarBloqueoVehiculo(vehiculo.id);
      final vencidos = (bloqueo['vencidos'] as List?)?.length ?? 0;
      vencidosPorVehiculo[vehiculo.id] = vencidos;
    }
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => VehiculoSelectionSheet(
        vehiculos: _provider.vehiculosDisponibles,
        vencidosPorVehiculo: vencidosPorVehiculo,
        maxVencidosBloqueo: 2,
        onVehiculoSelected: (vehiculo) async {
          final vencidos = vencidosPorVehiculo[vehiculo.id] ?? 0;
          final bloqueado = vencidos >= 2;

          if (bloqueado) {
            if (!mounted) return;
            messenger.showSnackBar(
              SnackBar(
                content: Text(
                  'No puedes seleccionar este vehículo: tiene $vencidos documentos vencidos',
                ),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 4),
              ),
            );
            return;
          }

          // Seleccionar vehículo e iniciar turno
          _provider.seleccionarVehiculo(vehiculo);
          final turnoIniciado = await _provider.iniciarTurno(vehiculo.id);

          if (turnoIniciado && mounted) {
            messenger.showSnackBar(
              SnackBar(
                content: Text('Turno iniciado con vehículo ${vehiculo.placa}'),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 2),
              ),
            );

            // Verificar documentos después de iniciar turno
            _verificarDocumentos();
          }
        },
      ),
    );
  }

  /// Cambia el estado del conductor (online/offline)
  Future<void> _cambiarEstadoConductor() async {
    if (!_provider.isOnline) {
      // Activándose: debe seleccionar vehículo primero
      if (_provider.vehiculoSeleccionado == null) {
        await _mostrarSelectorVehiculo();
      } else {
        await _provider.toggleOnlineStatus();
      }
    } else {
      // Desactivándose: finalizar turno
      final success = await _provider.finalizarTurno();
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Turno finalizado correctamente'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  Widget _buildSancionesBanner() {
    final activas = _sancionesActivas;
    final p = _porcentajeRiesgo;

    // Colores según nivel
    final Color color;
    final IconData icono;
    final String titulo;
    final String subtitulo;

    if (p >= 0.5) {
      color = Colors.red;
      icono = Iconsax.danger_copy;
      titulo = 'Peligro de bloqueo';
      subtitulo =
          'Tienes ${activas.length} sanción(es) graves. Mejora tu comportamiento.';
    } else if (p > 0.2) {
      color = Colors.orange;
      icono = Iconsax.warning_2_copy;
      titulo = 'Advertencia';
      subtitulo =
          'Tienes ${activas.length} sanción(es) activa(s). Cuida tu conducta.';
    } else {
      color = Colors.amber.shade700;
      icono = Iconsax.info_circle_copy;
      titulo = 'Precaución';
      subtitulo = 'Tienes ${activas.length} sanción(es) activa(s).';
    }

    return Material(
      elevation: 6,
      borderRadius: BorderRadius.circular(14),
      shadowColor: color.withValues(alpha: 0.3),
      child: InkWell(
        onTap: () => Navigator.pushNamed(context, '/mis-sanciones'),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: LinearGradient(
              colors: [color, color.withValues(alpha: 0.85)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              // Icono
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icono, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              // Texto
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      titulo,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitulo,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 11,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Botón cerrar
              GestureDetector(
                onTap: () => setState(() => _bannerVisible = false),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, color: Colors.white, size: 16),
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
    return ChangeNotifierProvider.value(
      value: _provider,
      child: Consumer<ConductorHomeProvider>(
        builder: (context, provider, child) {
          if (provider.currentPosition != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _tryShowConductorTutorial();
            });
          }
          return Stack(
            children: [
              // Mapa de Google Maps
              provider.currentPosition == null
                  ? LocationStatusView(
                      isLoading: provider.isLoadingLocation,
                      message: provider.locationMessage,
                      onRetry: provider.initializeLocation,
                    )
                  : RepaintBoundary(
                      child: StandardMap(
                        key: _tutorialMapKey,
                        initialPosition: LatLng(
                          provider.currentPosition!.latitude,
                          provider.currentPosition!.longitude,
                        ),
                        zoom: 15,
                        markers: {
                          Marker(
                            markerId: const MarkerId('current_location'),
                            position: LatLng(
                              provider.currentPosition!.latitude,
                              provider.currentPosition!.longitude,
                            ),
                            infoWindow: const InfoWindow(
                              title: 'Tu ubicación',
                              snippet: 'Estás aquí',
                            ),
                            icon: _dotMarker ?? BitmapDescriptor.defaultMarker,
                            anchor: const Offset(0.5, 0.5),
                          ),
                        },
                        onMapCreated: (controller) {
                          _mapController = controller;
                        },
                      ),
                    ),

              // Chip de estado del conductor (superior izquierda)
              if (provider.currentPosition != null)
                Positioned(
                  top: 16,
                  left: 16,
                  child: Material(
                    elevation: 4,
                    borderRadius: BorderRadius.circular(20),
                    shadowColor: provider.isOnline
                        ? AppColors.accent.withValues(alpha: 0.3)
                        : Colors.grey.withValues(alpha: 0.3),
                    child: InkWell(
                      key: _tutorialStatusKey,
                      onTap: _cambiarEstadoConductor,
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: provider.isOnline
                                ? [AppColors.accent, Colors.orangeAccent]
                                : [Colors.grey.shade400, Colors.grey.shade600],
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              provider.isOnline
                                  ? Icons.check_circle
                                  : Icons.cancel,
                              color: Colors.white,
                              size: 18,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              provider.isOnline ? 'En Línea' : 'Desconectado',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (provider.vehiculoSeleccionado != null) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.25),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  provider.vehiculoSeleccionado!.placa,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

              // Botón de recarga de ubicación
              if (provider.currentPosition != null)
                Positioned(
                  top: 16,
                  right: 16,
                  child: FloatingActionButton.small(
                    key: _tutorialLocationKey,
                    onPressed: () => provider.initializeLocation(),
                    backgroundColor: Colors.white,
                    elevation: 4,
                    child: const Icon(Icons.my_location, color: Colors.blue),
                  ),
                ),

              // Banner de sanciones
              if (_sancionesActivas.isNotEmpty && _bannerVisible)
                Positioned(
                  top: 60,
                  left: 16,
                  right: 16,
                  child: _buildSancionesBanner(),
                ),

              // Vista híbrida tipo inDriver: solicitud principal + cola scrolleable
              if (provider.solicitudesOrdenadas.isNotEmpty)
                Positioned(
                  top: 100,
                  left: 0,
                  right: 0,
                  bottom: 20,
                  child: RepaintBoundary(
                    child: Builder(
                      builder: (context) {
                        final solicitudes = provider.solicitudesOrdenadas;
                        return ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          physics: const BouncingScrollPhysics(),
                          itemCount: solicitudes.length,
                          itemBuilder: (context, index) {
                            final solicitud = solicitudes[index];
                            final solicitudId = _getSolicitudId(solicitud);

                            if (solicitudId.isEmpty) {
                              return const SizedBox.shrink();
                            }

                            final esPrincipal = index == 0;
                            final segundosRestantes = provider
                                .obtenerSegundosRestantes(solicitudId);

                            return Column(
                              children: [
                                if (esPrincipal)
                                  Container(
                                    width: double.infinity,
                                    margin: const EdgeInsets.only(bottom: 8),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withValues(
                                        alpha: 0.95,
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Text(
                                      'Solicitud recomendada',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.black,
                                      ),
                                    ),
                                  ),
                                Dismissible(
                                  key: Key('solicitud_$solicitudId'),
                                  direction: DismissDirection.horizontal,
                                  onDismissed: (direction) {
                                    provider.rechazarSolicitud(solicitudId);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Solicitud descartada'),
                                        duration: Duration(seconds: 1),
                                      ),
                                    );
                                  },
                                  background: Container(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    decoration: BoxDecoration(
                                      color: Colors.red,
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    alignment: Alignment.centerLeft,
                                    padding: const EdgeInsets.only(left: 20),
                                    child: const Icon(
                                      Icons.delete,
                                      color: Colors.white,
                                      size: 32,
                                    ),
                                  ),
                                  secondaryBackground: Container(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    decoration: BoxDecoration(
                                      color: Colors.red,
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    alignment: Alignment.centerRight,
                                    padding: const EdgeInsets.only(right: 20),
                                    child: const Icon(
                                      Icons.delete,
                                      color: Colors.white,
                                      size: 32,
                                    ),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: SolicitudServicioCard(
                                      solicitud: solicitud,
                                      segundosRestantes: segundosRestantes,
                                      destacada: esPrincipal,
                                      onAceptar: () =>
                                          _aceptarSolicitud(solicitudId),
                                      onRechazar: () =>
                                          _rechazarSolicitud(solicitudId),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        );
                      },
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _TutorialBubble extends StatelessWidget {
  final String title;
  final String text;

  const _TutorialBubble({required this.title, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 290),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}
