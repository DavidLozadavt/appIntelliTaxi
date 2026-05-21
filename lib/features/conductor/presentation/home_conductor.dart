import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:intellitaxi/core/theme/app_colors.dart';
import 'package:intellitaxi/features/auth/providers/auth_provider.dart';
import 'package:intellitaxi/features/conductor/widgets/vehiculo_selection_sheet.dart';
import 'package:intellitaxi/features/conductor/widgets/documentos_alert_dialog.dart';
import 'package:intellitaxi/features/conductor/widgets/no_assigned_vehicles_dialog.dart';
import 'package:intellitaxi/features/conductor/widgets/solicitud_servicio_card.dart';
import 'package:intellitaxi/features/conductor/presentation/conductor_servicio_activo_screen.dart';
import 'package:intellitaxi/core/services/servicio_payload_adapter.dart';
import 'package:intellitaxi/core/services/app_logger.dart';
import 'package:intellitaxi/shared/widgets/standard_map.dart';
import 'package:intellitaxi/features/conductor/providers/conductor_home_provider.dart';
import 'package:intellitaxi/features/emergencias/providers/emergencia_provider.dart';
import 'package:intellitaxi/features/sanciones/data/sancion_model.dart';
import 'package:intellitaxi/features/sanciones/services/sancion_service.dart';
import 'package:intellitaxi/core/widgets/location_status_view.dart';

class HomeConductor extends StatefulWidget {
  final List<dynamic> stories;

  const HomeConductor({super.key, required this.stories});

  @override
  State<HomeConductor> createState() => _HomeConductorState();
}

class _HomeConductorState extends State<HomeConductor>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  GoogleMapController? _mapController;
  late ConductorHomeProvider _provider;
  late final AnimationController _emergencyPulseController;
  late final Animation<double> _emergencyPulseAnimation;
  /// Modo navegación: mapa rotado, inclinado y siguiendo la calle.
  bool _modoNavegacionActivo = true;
  bool _moviendoCamaraProgramaticamente = false;
  LatLng? _ultimaUbicacionCamara;
  double _bearingNavegacion = 0;
  bool _bearingInicializado = false;
  Timer? _reanudarNavegacionTimer;

  static const double _tiltNavegacion = 50;
  static const double _zoomConduciendo = 18.5;
  static const double _zoomDetenido = 17;
  static const Duration _reanudarNavegacionTras = Duration(seconds: 12);

  // Sanciones
  final SancionService _sancionService = SancionService();
  List<Sancion> _sanciones = [];
  bool _bannerVisible = true;
  Timer? _bannerTimer;

  BitmapDescriptor? _dotMarker;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _provider = context.read<ConductorHomeProvider>();
    _emergencyPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _emergencyPulseAnimation = CurvedAnimation(
      parent: _emergencyPulseController,
      curve: Curves.easeInOut,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _provider.initialize();
    });
    _cargarSanciones();
    _crearDotMarker();
  }

  EdgeInsets _paddingMapaNavegacion(ConductorHomeProvider provider) {
    final bottom = provider.solicitudesOrdenadas.isNotEmpty ? 220.0 : 180.0;
    return EdgeInsets.only(top: 88, bottom: bottom, left: 24, right: 24);
  }

  Future<void> _crearDotMarker() async {
    const double s = 36;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const color = AppColors.primary;

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
    // Círculo interior principal
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
    WidgetsBinding.instance.removeObserver(this);
    _bannerTimer?.cancel();
    _reanudarNavegacionTimer?.cancel();
    _emergencyPulseController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (_provider.currentPosition == null) {
        unawaited(_provider.initializeLocation());
      }
      unawaited(_provider.sincronizarSolicitudesPublicadasConductor());
    }
  }

  String _getSolicitudId(Map<String, dynamic> solicitud) {
    return (solicitud['solicitud_id'] ??
            solicitud['servicio_id'] ??
            solicitud['id'] ??
            solicitud['request_id'] ??
            '')
        .toString();
  }

  double _resolverBearing(Position pos, LatLng? desde) {
    final speed = pos.speed.isFinite && pos.speed >= 0 ? pos.speed : 0;
    final headingValido =
        pos.heading.isFinite && pos.heading >= 0 && pos.heading <= 360;

    if (headingValido && speed > 1.2) {
      return pos.heading;
    }

    if (desde != null) {
      final dist = Geolocator.distanceBetween(
        desde.latitude,
        desde.longitude,
        pos.latitude,
        pos.longitude,
      );
      if (dist >= 3) {
        return Geolocator.bearingBetween(
          desde.latitude,
          desde.longitude,
          pos.latitude,
          pos.longitude,
        );
      }
    }

    return _bearingInicializado ? _bearingNavegacion : 0;
  }

  double _suavizarBearing(double objetivo, double factor) {
    if (!_bearingInicializado) {
      _bearingInicializado = true;
      return objetivo;
    }

    var diff = objetivo - _bearingNavegacion;
    if (diff > 180) diff -= 360;
    if (diff < -180) diff += 360;

    var suavizado = _bearingNavegacion + diff * factor;
    if (suavizado < 0) suavizado += 360;
    if (suavizado >= 360) suavizado -= 360;
    return suavizado;
  }

  bool _debeActualizarCamara(Position pos) {
    final target = LatLng(pos.latitude, pos.longitude);
    final last = _ultimaUbicacionCamara;
    if (last == null) return true;

    final moved = Geolocator.distanceBetween(
      last.latitude,
      last.longitude,
      target.latitude,
      target.longitude,
    );
    if (moved >= 2) return true;

    final bearing = _resolverBearing(pos, last);
    final diff = (bearing - _bearingNavegacion).abs();
    return diff > 4 && diff < 356;
  }

  Future<void> _aplicarCamaraNavegacion(ConductorHomeProvider provider) async {
    final pos = provider.currentPosition;
    final controller = _mapController;
    if (pos == null || controller == null) return;

    final target = LatLng(pos.latitude, pos.longitude);
    final last = _ultimaUbicacionCamara;
    final bearingRaw = _resolverBearing(pos, last);
    final bearing = _suavizarBearing(bearingRaw, 0.35);
    final speed = pos.speed.isFinite && pos.speed >= 0 ? pos.speed : 0;
    final zoom = speed > 2.5 ? _zoomConduciendo : _zoomDetenido;

    _ultimaUbicacionCamara = target;
    _bearingNavegacion = bearing;

    _moviendoCamaraProgramaticamente = true;
    try {
      await controller.moveCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: target,
            zoom: zoom,
            bearing: bearing,
            tilt: _tiltNavegacion,
          ),
        ),
      );
    } finally {
      _moviendoCamaraProgramaticamente = false;
    }
  }

  void _sincronizarCamaraNavegacion(ConductorHomeProvider provider) {
    if (!_modoNavegacionActivo) return;
    final pos = provider.currentPosition;
    if (pos == null || _mapController == null) return;
    if (!_debeActualizarCamara(pos)) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_modoNavegacionActivo) return;
      unawaited(_aplicarCamaraNavegacion(provider));
    });
  }

  void _pausarNavegacionTemporalmente() {
    if (!_modoNavegacionActivo) return;
    setState(() => _modoNavegacionActivo = false);
    _reanudarNavegacionTimer?.cancel();
    _reanudarNavegacionTimer = Timer(_reanudarNavegacionTras, () {
      if (!mounted) return;
      setState(() {
        _modoNavegacionActivo = true;
        _ultimaUbicacionCamara = null;
      });
      unawaited(_aplicarCamaraNavegacion(_provider));
    });
  }

  Future<void> _reanudarNavegacionAhora(ConductorHomeProvider provider) async {
    _reanudarNavegacionTimer?.cancel();
    if (provider.currentPosition == null) {
      await provider.initializeLocation();
    }
    if (!mounted) return;
    setState(() {
      _modoNavegacionActivo = true;
      _ultimaUbicacionCamara = null;
      _bearingInicializado = false;
    });
    await _aplicarCamaraNavegacion(provider);
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
      await showDialog<void>(
        context: context,
        barrierDismissible: true,
        builder: (_) => const NoAssignedVehiclesDialog(),
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
        onRefresh: () async {
          await _provider.cargarVehiculos();
          final refreshedVencidosPorVehiculo = <int, int>{};
          for (final vehiculo in _provider.vehiculosDisponibles) {
            final bloqueo = await _provider.verificarBloqueoVehiculo(
              vehiculo.id,
            );
            final vencidos = (bloqueo['vencidos'] as List?)?.length ?? 0;
            refreshedVencidosPorVehiculo[vehiculo.id] = vencidos;
          }
          return VehiculoSelectionRefreshData(
            vehiculos: _provider.vehiculosDisponibles,
            vencidosPorVehiculo: refreshedVencidosPorVehiculo,
          );
        },
        onVehiculoSelected: (vehiculo) async {
          final vencidos = vencidosPorVehiculo[vehiculo.id] ?? 0;
          final bloqueado =
              vencidos >= 2 || !vehiculo.puedeOperarPorVinculacion;

          if (bloqueado) {
            if (!mounted) return;
            final mensaje = !vehiculo.puedeOperarPorVinculacion
                ? 'No puedes operar este vehículo: ${vehiculo.motivoBloqueoVinculacion}'
                : 'No puedes seleccionar este vehículo: tiene $vencidos documentos vencidos';
            messenger.showSnackBar(
              SnackBar(
                content: Text(mensaje),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 4),
              ),
            );
            return;
          }

          // Iniciar turno; el provider sincroniza el vehículo seleccionado
          // cuando el turno queda activo.
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
            unawaited(_reanudarNavegacionAhora(_provider));
          } else if (mounted) {
            final errorMessage = _provider.lastTurnoError;
            if (_esVehiculoOcupadoError(errorMessage)) {
              final continuar = await _mostrarVehiculoOcupadoDialog(
                errorMessage!,
              );

              if (continuar == true) {
                final finalizado = await _provider
                    .finalizarTurnoActivoAnterior();
                if (!mounted) return;

                if (finalizado) {
                  final reintento = await _provider.iniciarTurno(vehiculo.id);
                  if (!mounted) return;

                  if (reintento) {
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text(
                          'Turno iniciado con vehículo ${vehiculo.placa}',
                        ),
                        backgroundColor: Colors.green,
                      ),
                    );
                    _verificarDocumentos();
                    unawaited(_reanudarNavegacionAhora(_provider));
                  } else {
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text(
                          _provider.lastTurnoError ??
                              'No se pudo iniciar el turno',
                        ),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                } else {
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text('No se pudo finalizar el turno anterior'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            } else {
              messenger.showSnackBar(
                SnackBar(
                  content: Text(
                    errorMessage?.isNotEmpty == true
                        ? errorMessage!
                        : 'No se pudo iniciar el turno con este vehiculo',
                  ),
                  backgroundColor: Colors.red,
                  duration: const Duration(seconds: 4),
                ),
              );
            }
          }
        },
      ),
    );
  }

  bool _esVehiculoOcupadoError(String? message) {
    if (message == null || message.trim().isEmpty) return false;
    final normalized = message.toLowerCase();
    return normalized.contains('turno activo') ||
        normalized.contains('turno abierto') ||
        (normalized.contains('vehiculo') && normalized.contains('ocupado')) ||
        (normalized.contains('vehículo') && normalized.contains('ocupado'));
  }

  Future<bool?> _mostrarVehiculoOcupadoDialog(String message) async {
    if (!mounted) return false;

    return showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final isDark = Theme.of(dialogContext).brightness == Brightness.dark;

        final surfaceColor = isDark ? AppColors.darkCard : Colors.white;

        final bodyColor = isDark
            ? AppColors.darkOnSurface.withValues(alpha: 0.78)
            : Colors.black87;

        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(
                          Iconsax.warning_2_copy,
                          color: Colors.orange,
                          size: 24,
                        ),
                      ),

                      const SizedBox(width: 14),

                      const Expanded(
                        child: Text(
                          'Turno activo detectado',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  Text(
                    message,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.4,
                      color: bodyColor,
                    ),
                  ),

                  const SizedBox(height: 14),

                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      'Parece que tienes un turno abierto desde otro dispositivo o una sesión anterior.',
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.35,
                        color: bodyColor,
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(0, 44),
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                          ),
                          onPressed: () {
                            Navigator.pop(dialogContext, false);
                          },
                          child: const FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              'Cancelar',
                              maxLines: 1,
                              softWrap: false,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(width: 12),

                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(0, 44),
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                          ),
                          onPressed: () {
                            Navigator.pop(dialogContext, true);
                          },
                          child: const FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              'Finalizar',
                              maxLines: 1,
                              softWrap: false,
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
      },
    );
  }

  /// Cambia el estado del conductor (online/offline)
  Future<void> _cambiarEstadoConductor() async {
    if (!_provider.isOnline) {
      // Activándose: abrir siempre el selector para evitar reintentos
      // silenciosos si antes se canceló un diálogo de turno activo.
      await _mostrarSelectorVehiculo();
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
    return Consumer<ConductorHomeProvider>(
      builder: (context, provider, child) {
        _sincronizarCamaraNavegacion(provider);
        return Stack(
          children: [
            // Mapa de Google Maps
            provider.currentPosition == null
                ? LocationStatusView(
                    isLoading: provider.isLoadingLocation,
                    message: provider.locationMessage,
                    onRetry: provider.handleLocationRecoveryAction,
                    actionLabel: provider.locationActionLabel,
                    actionIcon: provider.locationActionIcon,
                  )
                : RepaintBoundary(
                    child: StandardMap(
                      initialPosition: LatLng(
                        provider.currentPosition!.latitude,
                        provider.currentPosition!.longitude,
                      ),
                      zoom: _zoomDetenido,
                      tilt: _tiltNavegacion,
                      bearing: _resolverBearing(
                        provider.currentPosition!,
                        null,
                      ),
                      myLocationEnabled: false,
                      myLocationButtonEnabled: false,
                      compassEnabled: false,
                      zoomControlsEnabled: false,
                      mapPadding: _paddingMapaNavegacion(provider),
                      markers: {
                        Marker(
                          markerId: const MarkerId('current_location'),
                          position: LatLng(
                            provider.currentPosition!.latitude,
                            provider.currentPosition!.longitude,
                          ),
                          infoWindow: InfoWindow(
                            title: 'Tu ubicación',
                            snippet: provider.zonaActual?.isNotEmpty == true
                                ? provider.zonaActual
                                : 'Estás aquí',
                          ),
                          icon: _dotMarker ?? BitmapDescriptor.defaultMarker,
                          anchor: const Offset(0.5, 0.5),
                          rotation: 0,
                        ),
                      },
                      onMapCreated: (controller) {
                        _mapController = controller;
                        unawaited(_reanudarNavegacionAhora(provider));
                      },
                      onCameraMoveStarted: () {
                        if (_moviendoCamaraProgramaticamente) return;
                        _pausarNavegacionTemporalmente();
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
                    onTap: _cambiarEstadoConductor,
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.sizeOf(context).width - 32,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: provider.isOnline
                              ? [AppColors.accent, AppColors.accent]
                              : [Colors.grey.shade400, Colors.grey.shade600],
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Icon(
                            provider.isOnline
                                ? Icons.check_circle
                                : Icons.cancel,
                            color: Colors.white,
                            size: 18,
                          ),
                          Text(
                            provider.isOnline ? 'En Línea' : 'Desconectado',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (provider.isOnline &&
                              provider.vehiculoSeleccionado != null) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),

                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.yellow.withValues(
                                        alpha: 0.25,
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          provider.vehiculoSeleccionado!.placa,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 15,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),

                                        const SizedBox(width: 8),

                                        Text(
                                          'Nro orden: ${provider.vehiculoSeleccionado!.asignacionPropietarios[0].afiliacion.numero}',
                                          style: const TextStyle(
                                            color: Colors.white70,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          if (provider.isOnline &&
                              provider.zonaActual != null &&
                              provider.zonaActual!.isNotEmpty) ...[
                            Container(
                              constraints: BoxConstraints(
                                maxWidth: MediaQuery.sizeOf(context).width - 60,
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.location_on,
                                    size: 12,
                                    color: Colors.white.withValues(alpha: 0.95),
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      'Barrio: ${provider.zonaActual!}',
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                      style: TextStyle(
                                        color: Colors.white.withValues(
                                          alpha: 0.95,
                                        ),
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
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

            if (provider.currentPosition != null)
              Positioned(
                right: 16,
                bottom: provider.solicitudesOrdenadas.isNotEmpty ? 196 : 80,
                child: Consumer<EmergenciaProvider>(
                  builder: (context, emergenciaProvider, _) {
                    if (!emergenciaProvider.estaEnEmergencia) {
                      return FloatingActionButton.small(
                        heroTag: 'fab_emergencias',
                        onPressed: () =>
                            Navigator.pushNamed(context, '/emergencias'),
                        backgroundColor: Colors.red.shade600,
                        elevation: 4,
                        child: const Icon(Icons.emergency, color: Colors.white),
                      );
                    }

                    return AnimatedBuilder(
                      animation: _emergencyPulseAnimation,
                      builder: (context, child) {
                        final pulse = _emergencyPulseAnimation.value;
                        return Transform.scale(
                          scale: 1 + (pulse * 0.05),
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(18),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.red.withValues(
                                    alpha: 0.28 - (pulse * 0.12),
                                  ),
                                  blurRadius: 14 + (pulse * 14),
                                  spreadRadius: 2 + (pulse * 5),
                                ),
                              ],
                            ),
                            child: child,
                          ),
                        );
                      },
                      child: FloatingActionButton.extended(
                        heroTag: 'fab_emergencias',
                        onPressed: () =>
                            Navigator.pushNamed(context, '/emergencias'),
                        backgroundColor: Colors.red.shade700,
                        foregroundColor: Colors.white,
                        elevation: 6,
                        icon: const Icon(Icons.emergency_share),
                        label: const Text(
                          'EN EMERGENCIA',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

            // Botón de centrar mapa en ubicación actual
            if (provider.currentPosition != null)
              Positioned(
                right: 16,
                bottom: provider.solicitudesOrdenadas.isNotEmpty ? 140 : 24,
                child: FloatingActionButton.small(
                  heroTag: 'fab_ubicacion',
                  onPressed: () => _reanudarNavegacionAhora(provider),
                  backgroundColor: Colors.white.withValues(alpha: 0.88),
                  elevation: 4,
                  tooltip: _modoNavegacionActivo
                      ? 'Modo navegación activo'
                      : 'Volver al modo navegación',
                  child: Icon(
                    _modoNavegacionActivo
                        ? Icons.navigation_rounded
                        : Icons.explore_outlined,
                    color: AppColors.accent,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
