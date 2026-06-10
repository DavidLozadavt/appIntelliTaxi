import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:intellitaxi/core/widgets/app_loading_indicator.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:intellitaxi/core/theme/app_colors.dart';
import 'package:intellitaxi/features/auth/providers/auth_provider.dart';
import 'package:intellitaxi/features/conductor/widgets/vehiculo_selection_sheet.dart';
import 'package:intellitaxi/features/conductor/widgets/documentos_alert_dialog.dart';
import 'package:intellitaxi/features/conductor/widgets/no_assigned_vehicles_dialog.dart';
import 'package:intellitaxi/features/conductor/providers/solicitudes_pendientes_provider.dart';
import 'package:intellitaxi/features/conductor/widgets/conductor_descanso_switch.dart';
import 'package:intellitaxi/features/conductor/widgets/conductor_map_servicios_tabs.dart';
import 'package:intellitaxi/core/utils/json_payload_helper.dart';
import 'package:intellitaxi/features/conductor/utils/conductor_servicio_navegacion.dart';
import 'package:intellitaxi/core/services/app_logger.dart';
import 'package:intellitaxi/core/utils/api_rate_limit_guard.dart';
import 'package:intellitaxi/shared/widgets/standard_map.dart';
import 'package:intellitaxi/features/conductor/providers/conductor_home_provider.dart';
import 'package:intellitaxi/features/emergencias/providers/emergencia_provider.dart';
import 'package:intellitaxi/features/emergencias/utils/emergencia_quick_report.dart';
import 'package:intellitaxi/features/sanciones/data/sancion_model.dart';
import 'package:intellitaxi/features/sanciones/services/sancion_service.dart';
import 'package:intellitaxi/core/services/driver_overlay_permission_flow.dart';
import 'package:intellitaxi/core/services/driver_overlay_service.dart';
import 'package:intellitaxi/core/widgets/location_status_view.dart';
import 'package:intellitaxi/core/services/keep_screen_on_service.dart';
import 'package:intellitaxi/features/conductor/utils/conductor_pending_fcm.dart';
import 'package:intellitaxi/core/perf/runtime_perf_flags.dart';
import 'package:intellitaxi/core/utils/dio_error_message.dart';

class HomeConductor extends StatefulWidget {
  final List<dynamic> stories;

  const HomeConductor({super.key, required this.stories});

  @override
  State<HomeConductor> createState() => _HomeConductorState();
}

class _HomeConductorState extends State<HomeConductor>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  GoogleMapController? _mapController;
  /// Evita `moveCamera` sobre un controller de un mapa ya destruido.
  int? _mapControllerBoundGeneration;
  late ConductorHomeProvider _provider;
  late SolicitudesPendientesProvider _pendientesProvider;
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
  final DriverOverlayService _overlayService = DriverOverlayService.instance;
  List<Sancion> _sanciones = [];
  bool _bannerVisible = true;
  Timer? _bannerTimer;
  Timer? _validandoTurnoTimeout;

  BitmapDescriptor? _dotMarker;
  /// Fuerza recrear GoogleMap al volver del overlay/segundo plano (evita mapa negro).
  int _mapResumeGeneration = 0;
  late TabController _serviciosTabController;
  /// Solo true si aún no sabemos si hay turno (evita bloquear al volver de un viaje).
  bool _validandoTurno = false;
  bool _selectorVehiculoAbierto = false;
  bool _accionTurnoUiEnCurso = false;
  void _irATabEnEspera() {
    if (_serviciosTabController.index != 1) {
      _serviciosTabController.animateTo(1);
    }
    unawaited(_pendientesProvider.refrescar(silencioso: true));
  }

  void _onNuevaSolicitudRecibida(Map<String, dynamic> solicitud) {
    if (!mounted) return;
    if (_serviciosTabController.index != 0) {
      _serviciosTabController.animateTo(0);
    }
    if (_panelServiciosVisible(_provider) ||
        (_provider.tieneTurnoActivo && _provider.isOnline)) {
      setState(() {});
      return;
    }

    final nombre = solicitud['pasajero_nombre']?.toString().trim();
    final origen = solicitud['origen']?.toString().trim();
    final detalle = [
      if (nombre != null && nombre.isNotEmpty) nombre,
      if (origen != null && origen.isNotEmpty) origen,
    ].join(' · ');
    final tieneTurno = _provider.tieneTurnoActivo;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          detalle.isNotEmpty
              ? (tieneTurno
                  ? 'Nueva solicitud: $detalle. Pásate En línea para verla en el mapa.'
                  : 'Nueva solicitud: $detalle. Inicia tu turno para verla en el mapa.')
              : (tieneTurno
                  ? 'Nueva solicitud. Pásate En línea para verla en el mapa.'
                  : 'Nueva solicitud. Inicia tu turno para verla en el mapa.'),
        ),
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: tieneTurno ? 'En línea' : 'Turno',
          onPressed: () => unawaited(_mostrarSelectorVehiculo()),
        ),
      ),
    );
    setState(() {});
  }

  void _avisarSolicitudesRecibidasFueraDeLinea() {
    if (!mounted || _panelServiciosVisible(_provider)) return;
    if (_provider.tieneTurnoActivo && _provider.isOnline) return;
    final enMapa = _provider.solicitudesOrdenadas.length;
    final enEspera = _provider.totalSolicitudesEnEspera;
    final total = enMapa + enEspera;
    if (total <= 0) return;

    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          total == 1
              ? 'Tienes 1 solicitud pendiente. Pásate En línea para verla en el mapa.'
              : 'Tienes $total solicitudes pendientes. Pásate En línea para verlas en el mapa.',
        ),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 6),
        action: SnackBarAction(
          label: 'En línea',
          onPressed: () => unawaited(_mostrarSelectorVehiculo()),
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _provider = context.read<ConductorHomeProvider>();
    _validandoTurno = true;
    _validandoTurnoTimeout = Timer(
      const Duration(seconds: 10),
      _finalizarValidacionTurno,
    );
    _provider.addNuevaSolicitudListener(_onNuevaSolicitudRecibida);
    _provider.addListener(_syncKeepScreenOn);
    _provider.addListener(_onProviderForNavigation);
    _provider.addListener(_onProviderUiMensajes);
    unawaited(KeepScreenOnService.loadPreference().then((_) {
      if (mounted) _syncKeepScreenOn();
    }));
    _pendientesProvider = SolicitudesPendientesProvider();
    _emergencyPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _emergencyPulseAnimation = CurvedAnimation(
      parent: _emergencyPulseController,
      curve: Curves.easeInOut,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrapHome());
    _serviciosTabController = TabController(length: 2, vsync: this);
    _serviciosTabController.addListener(() {
      if (_serviciosTabController.indexIsChanging) return;
      setState(() {});
      if (_serviciosTabController.index == 1) {
        unawaited(_pendientesProvider.refrescar(silencioso: true));
      }
    });
    _cargarSanciones();
    _crearDotMarker();
  }

  bool _panelServiciosVisible(ConductorHomeProvider provider) =>
      provider.isOnline &&
      !provider.enServicio &&
      !provider.enDescanso &&
      provider.tieneTurnoActivo &&
      !provider.tieneOfertaExclusivaActiva;

  EdgeInsets _paddingMapaNavegacion(ConductorHomeProvider provider) {
    final panelVisible = _panelServiciosVisible(provider);
    final compact = ConductorMapServiciosTabs.pantallaCompacta(context);
    final chipH = _chipEstadoAltura(provider, compact: compact);
    var top = panelVisible
        ? ConductorMapServiciosTabs.headerBlockHeight(
              context,
              provider,
              chipAltura: chipH,
              avisoEsperaEnLlegando: false,
            )
        : chipH + 24;
    if (panelVisible &&
        ConductorMapServiciosTabs.shouldShowPanel(
          controller: _serviciosTabController,
          home: provider,
          pendientes: _pendientesProvider,
        )) {
      final items = _serviciosTabController.index == 0
          ? provider.solicitudesOrdenadas.length
          : _pendientesProvider.total;
      final enLlegando = _serviciosTabController.index == 0;
      top += ConductorMapServiciosTabs.panelOuterHeight(
            context,
            conBarraRefresh: !enLlegando,
            itemCount: items > 0 ? items : 1,
            tightPanel: enLlegando &&
                ConductorMapServiciosTabs.usarPanelAjustadoLlegando(
                  context,
                  items,
                ),
          );
    }
    const bottom = 100.0;
    return EdgeInsets.only(top: top, bottom: bottom, left: 20, right: 20);
  }

  double _fabBottomOffset(ConductorHomeProvider provider) {
    return _panelServiciosVisible(provider) ? 100.0 : 24.0;
  }

  void _finalizarValidacionTurno() {
    _validandoTurnoTimeout?.cancel();
    if (!mounted || !_validandoTurno) return;
    setState(() => _validandoTurno = false);
  }

  Future<void> _bootstrapHome() async {
    if (!mounted) return;

    try {
      await _provider.initialize().timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          AppLogger.d(
            '⏱️ Conductor initialize timeout — desbloqueando home',
            tag: 'Turno',
          );
        },
      );
    } catch (e) {
      AppLogger.d('⚠️ _bootstrapHome initialize: $e', tag: 'Turno');
    } finally {
      _finalizarValidacionTurno();
    }
    if (!mounted) return;

    unawaited(ConductorPendingFcm.flush(context));
    _avisarSolicitudesRecibidasFueraDeLinea();

    _pendientesProvider.attachHome(_provider);
    if (!ApiRateLimitGuard.instance.isBlocked) {
      unawaited(_pendientesProvider.refrescar(silencioso: true));
    }
    _pendientesProvider.iniciarRefrescoPeriodico();

    if (!mounted) return;
    unawaited(_navigateToActiveServiceIfNeeded());

    // Burbuja overlay: no bloquear el arranque del mapa.
    if (!mounted) return;
    unawaited(
      Future<void>.delayed(const Duration(seconds: 2), () async {
        if (!mounted) return;
        await DriverOverlayPermissionFlow.promptOnConductorHomeEntered(context);
      }),
    );
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

  void _invalidateMapController({bool dispose = true}) {
    if (dispose) {
      try {
        _mapController?.dispose();
      } catch (_) {
        // Controller ya liberado por recreación del PlatformView.
      }
    }
    _mapController = null;
    _mapControllerBoundGeneration = null;
  }

  bool get _mapControllerListo =>
      _mapController != null &&
      _mapControllerBoundGeneration == _mapResumeGeneration;

  void _onProviderForNavigation() {
    if (!_modoNavegacionActivo || !_mapControllerListo) return;
    _sincronizarCamaraNavegacion(_provider);
  }

  void _onProviderUiMensajes() {
    if (!mounted) return;
    final msg = _provider.takeLastRadioDismissMessage();
    if (msg == null || msg.isEmpty) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _syncKeepScreenOn() {
    if (!KeepScreenOnService.userEnabled) {
      unawaited(KeepScreenOnService.release('conductor_turno'));
      return;
    }
    if (_provider.isOnline && _provider.tieneTurnoActivo) {
      unawaited(KeepScreenOnService.acquire('conductor_turno'));
    } else {
      unawaited(KeepScreenOnService.release('conductor_turno'));
    }
  }

  @override
  void dispose() {
    _provider.removeListener(_syncKeepScreenOn);
    _provider.removeListener(_onProviderForNavigation);
    _provider.removeListener(_onProviderUiMensajes);
    unawaited(KeepScreenOnService.release('conductor_turno'));
    _provider.removeNuevaSolicitudListener(_onNuevaSolicitudRecibida);
    WidgetsBinding.instance.removeObserver(this);
    _bannerTimer?.cancel();
    _validandoTurnoTimeout?.cancel();
    _reanudarNavegacionTimer?.cancel();
    _emergencyPulseController.dispose();
    _serviciosTabController.dispose();
    _invalidateMapController();
    _pendientesProvider.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _invalidateMapController();
      setState(() => _mapResumeGeneration++);
      unawaited(_overlayService.hide());
      unawaited(_provider.refrescarEnResume());
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      unawaited(_provider.onAppLifecyclePaused());
      if (!_overlayService.isRequestingPermission) {
        unawaited(_overlayService.syncBubbleForConductor(_provider));
      }
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
    if (!mounted || !_mapControllerListo) return;

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
    } catch (e) {
      AppLogger.d('⚠️ moveCamera omitido (mapa no listo): $e');
      if (!_mapControllerListo) {
        _invalidateMapController(dispose: false);
      }
    } finally {
      if (mounted) {
        _moviendoCamaraProgramaticamente = false;
      }
    }
  }

  void _sincronizarCamaraNavegacion(ConductorHomeProvider provider) {
    if (!_modoNavegacionActivo || !_mapControllerListo) return;
    final pos = provider.currentPosition;
    if (pos == null) return;
    if (!_debeActualizarCamara(pos)) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_modoNavegacionActivo || !_mapControllerListo) return;
      unawaited(_aplicarCamaraNavegacion(provider));
    });
  }

  void _pausarNavegacionTemporalmente() {
    if (!_modoNavegacionActivo) return;
    setState(() => _modoNavegacionActivo = false);
    _reanudarNavegacionTimer?.cancel();
    _reanudarNavegacionTimer = Timer(_reanudarNavegacionTras, () {
      if (!mounted || !_mapControllerListo) return;
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
    if (!mounted || !_mapControllerListo) return;
    setState(() {
      _modoNavegacionActivo = true;
      _ultimaUbicacionCamara = null;
      _bearingInicializado = false;
    });
    await _aplicarCamaraNavegacion(provider);
  }

  Future<void> _navigateToActiveServiceIfNeeded() async {
    if (!_provider.enServicio) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final conductorId = authProvider.user?.id;
    if (conductorId == null) return;

    await ConductorServicioNavegacion.abrirTrasAceptar(
      context,
      home: _provider,
      conductorId: conductorId,
      acceptResponse: _provider.servicioActivoPendienteNavegacion,
      reemplazar: true,
    );
  }

  /// Acepta la solicitud de servicio
  void _aceptarSolicitud(
    String solicitudId, [
    Map<String, dynamic>? solicitudData,
  ]) async {
    Map<String, dynamic> solicitud;
    if (solicitudData != null) {
      solicitud = solicitudData;
    } else {
      solicitud = _provider.buscarSolicitudPorId(solicitudId) ??
          _provider.solicitudesOrdenadas.firstWhere(
            (s) => _getSolicitudId(s) == solicitudId,
            orElse: () => {},
          );
      if (solicitud.isEmpty) {
        solicitud = {};
      }
    }

    if (solicitud.isEmpty) {
      AppLogger.d('⚠️ Solicitud no encontrada: $solicitudId');
      return;
    }

    AppLogger.d('👉 Intentando aceptar solicitud ID: $solicitudId');

    unawaited(_provider.detenerAlertasSolicitudEntrante());

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
        builder: (context) => const Center(child: AppLoadingIndicator()),
      );
    }

    void closeLoadingIfNeeded() {
      if (!mounted || !loadingShown) return;
      loadingShown = false;
      Navigator.of(context, rootNavigator: true).pop();
    }

    try {
      // Llamar al provider para aceptar
      final precio = JsonPayloadHelper.parseDouble(
        solicitud['precio_ofertado'],
      );
      final response = await _provider.aceptarSolicitud(
        solicitudId,
        _provider.vehiculoSeleccionado?.id ?? 0,
        precioOfertado: precio > 0 ? precio : null,
      );

      closeLoadingIfNeeded();

      if (response == null) {
        if (_provider.enServicio && _provider.servicioActivoId != null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  _provider.lastAcceptError ??
                      'Ya tienes un viaje en curso. Abriendo servicio activo…',
                ),
                backgroundColor: Colors.orange,
              ),
            );
          }
          await _navigateToActiveServiceIfNeeded();
          return;
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                _provider.lastAcceptError ??
                    'No se pudo aceptar la solicitud',
              ),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 5),
            ),
          );
        }
        return;
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
      _pendientesProvider.quitarPorId(solicitudId);

      if (mounted) {
        await ConductorServicioNavegacion.abrirTrasAceptar(
          context,
          home: _provider,
          conductorId: conductorId,
          acceptResponse: response,
        );
      }
    } catch (e) {
      closeLoadingIfNeeded();

      final errorMsg = DioErrorMessage.from(
        e,
        fallback: 'No se pudo aceptar el servicio. Intenta de nuevo.',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
          ),
        );
      }

      AppLogger.d('⚠️ Error al aceptar solicitud: $errorMsg');
    }
  }

  /// Rechaza para este conductor (cola «Llegando» / «En espera»); no cancela el viaje del pasajero.
  void _rechazarSolicitud(String solicitudId) async {
    AppLogger.d('❌ Rechazo local conductor: $solicitudId');

    final okRemoto = await _provider.rechazarSolicitudParaConductor(solicitudId);
    _pendientesProvider.quitarPorId(solicitudId);

    if (!mounted) return;

    if (okRemoto) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No te volverá a salir este servicio. Sigue disponible para otros conductores.',
          ),
          backgroundColor: Colors.orange,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Ocultado en la app. Si vuelve a aparecer, revisa tu conexión.',
          ),
          backgroundColor: Colors.orange,
        ),
      );
    }
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
      await showDialog<void>(
        context: context,
        useRootNavigator: true,
        barrierDismissible: false,
        builder: (context) => DocumentosAlertDialog(
          documentosVencidos: vencidos,
          documentosPorVencer: porVencer,
        ),
      );
    }
  }

  /// Tras turno OK: documentos (sin avisos extra de burbuja).
  Future<void> _trasTurnoIniciadoConExito() async {
    if (!mounted) return;
    unawaited(_reanudarNavegacionAhora(_provider));
    await _verificarDocumentos();
  }

  Future<T?> _conDialogoCarga<T>(
    String mensaje,
    Future<T> Function() trabajo,
  ) async {
    if (!mounted) return null;
    _accionTurnoUiEnCurso = true;
    try {
      return await showDialog<T>(
        context: context,
        barrierDismissible: false,
        useRootNavigator: true,
        builder: (dialogContext) => _DialogoCarga<T>(
          mensaje: mensaje,
          trabajo: trabajo,
        ),
      );
    } finally {
      _accionTurnoUiEnCurso = false;
    }
  }

  /// Muestra el selector de vehículo
  Future<void> _mostrarSelectorVehiculo() async {
    if (!mounted ||
        _selectorVehiculoAbierto ||
        _accionTurnoUiEnCurso ||
        _provider.procesandoTurno) {
      return;
    }

    final messenger = ScaffoldMessenger.of(context);

    final preparado = await _conDialogoCarga<(List<dynamic>, Map<int, int>)?>(
      'Cargando vehículos...',
      () async {
        await _provider.cargarVehiculos();
        if (_provider.vehiculosDisponibles.isEmpty) {
          return null;
        }
        final vencidosPorVehiculo = <int, int>{};
        for (final vehiculo in _provider.vehiculosDisponibles) {
          final bloqueo = await _provider.verificarBloqueoVehiculo(vehiculo.id);
          vencidosPorVehiculo[vehiculo.id] =
              (bloqueo['vencidos'] as List?)?.length ?? 0;
        }
        return (_provider.vehiculosDisponibles, vencidosPorVehiculo);
      },
    );
    if (!mounted) return;

    if (preparado == null) {
      if (_provider.vehiculosDisponibles.isEmpty) {
        final loadError = _provider.lastVehiculosLoadError;
        if (loadError != null && loadError.isNotEmpty) {
          messenger.showSnackBar(
            SnackBar(
              content: Text(loadError),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 5),
              action: SnackBarAction(
                label: 'Reintentar',
                onPressed: () => unawaited(_mostrarSelectorVehiculo()),
              ),
            ),
          );
          return;
        }

        await showDialog<void>(
          context: context,
          barrierDismissible: true,
          builder: (_) => const NoAssignedVehiclesDialog(),
        );
      }
      return;
    }

    final vencidosPorVehiculo = preparado.$2;
    final vehiculos = _provider.vehiculosDisponibles;
    setState(() => _selectorVehiculoAbierto = true);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: !_provider.procesandoTurno,
      enableDrag: !_provider.procesandoTurno,
      builder: (context) => VehiculoSelectionSheet(
        vehiculos: vehiculos,
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
            if (!mounted) return false;
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
            return false;
          }

          final turnoIniciado = await _provider.iniciarTurno(vehiculo.id);

          if (turnoIniciado && mounted) {
            messenger.showSnackBar(
              SnackBar(
                content: Text('Turno iniciado con vehículo ${vehiculo.placa}'),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 2),
              ),
            );
            await _trasTurnoIniciadoConExito();
            return true;
          }

          if (!mounted) return false;
          final errorMessage = _provider.lastTurnoError;
          if (_esVehiculoOcupadoError(errorMessage)) {
            final continuar = await _mostrarVehiculoOcupadoDialog(
              errorMessage!,
            );

            if (continuar == true) {
              final finalizado =
                  await _provider.finalizarTurnoActivoAnterior();
              if (!mounted) return false;

              if (finalizado) {
                final reintento = await _provider.iniciarTurno(vehiculo.id);
                if (!mounted) return false;

                if (reintento) {
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(
                        'Turno iniciado con vehículo ${vehiculo.placa}',
                      ),
                      backgroundColor: Colors.green,
                    ),
                  );
                  await _trasTurnoIniciadoConExito();
                  return true;
                }
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(
                      _provider.lastTurnoError ??
                          'No se pudo iniciar el turno',
                    ),
                    backgroundColor: Colors.red,
                  ),
                );
                return false;
              }
              messenger.showSnackBar(
                const SnackBar(
                  content: Text('No se pudo finalizar el turno anterior'),
                  backgroundColor: Colors.red,
                ),
              );
              return false;
            }
            return false;
          }

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
          return false;
        },
      ),
    ).whenComplete(() {
      if (mounted) setState(() => _selectorVehiculoAbierto = false);
    });
  }

  bool _esVehiculoOcupadoError(String? message) {
    if (message == null || message.trim().isEmpty) return false;
    final normalized = message.toLowerCase();
    return normalized.contains('turno activo') ||
        normalized.contains('turno abierto') ||
        normalized.contains('ya tiene un turno') ||
        normalized.contains('ya tienes un turno') ||
        normalized.contains('turno en curso') ||
        normalized.contains('turno pendiente') ||
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
    if (_accionTurnoUiEnCurso ||
        _provider.procesandoTurno ||
        _selectorVehiculoAbierto) {
      return;
    }

    if (!_provider.isOnline) {
      await _mostrarSelectorVehiculo();
      return;
    }

    final resultado = await showDialog<_CerrarTurnoResultado>(
      context: context,
      barrierDismissible: true,
      builder: (_) => _DialogCerrarTurno(
        enDescanso: _provider.enDescanso,
        onConfirmar: () async {
          final ok = await _provider.finalizarTurno();
          return (
            ok,
            _provider.lastTurnoError ??
                'No se pudo finalizar el turno. Intenta de nuevo.',
          );
        },
      ),
    );
    if (!mounted || resultado == null) return;

    if (resultado.exito) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Turno cerrado correctamente'),
          backgroundColor: Colors.green,
        ),
      );
    } else if (resultado.mensajeError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(resultado.mensajeError!),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
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

  /// Altura del chip: fila 1 (estado + vehículo) + zona abajo si aplica.
  static double _chipEstadoAltura(
    ConductorHomeProvider provider, {
    required bool compact,
  }) {
    var h = compact ? 14.0 : 16.0;
    h += compact ? 22.0 : 24.0;
    final zona = provider.zonaActual?.trim() ?? '';
    if (provider.isOnline && zona.isNotEmpty) {
      h += 4;
      // Reservar hasta 2 líneas («Zona: …») para no solapar el panel de tarjetas.
      h += compact ? 36.0 : 40.0;
    }
    return h;
  }

  Widget _buildBotonDescansoEnChip(
    ConductorHomeProvider provider, {
    required bool compact,
  }) {
    if (!provider.isOnline) return const SizedBox.shrink();
    if (!provider.puedeUsarModoDescanso && !provider.enDescanso) {
      return const SizedBox.shrink();
    }

    final enDescanso = provider.enDescanso;
    final loading = provider.cambiandoDescanso;
    final size = compact ? 30.0 : 32.0;

    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: Tooltip(
        message: enDescanso ? 'Volver a servicios' : 'Modo descanso',
        child: Material(
          color: Colors.white.withValues(alpha: enDescanso ? 0.28 : 0.18),
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: loading || _accionTurnoUiEnCurso || provider.procesandoTurno
                ? null
                : () => ConductorDescansoSwitch.toggle(
                      context,
                      activar: !enDescanso,
                    ),
            child: SizedBox(
              width: size,
              height: size,
              child: Center(
                child: loading
                    ? const AppBrandLoaderCompact(ringSize: 16)
                    : Icon(
                        enDescanso
                            ? Icons.play_arrow_rounded
                            : Icons.coffee_outlined,
                        size: compact ? 17 : 18,
                        color: Colors.white,
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChipEstadoConductor(
    BuildContext context,
    ConductorHomeProvider provider, {
    bool compact = false,
  }) {
    final vehiculo = provider.vehiculoSeleccionado;
    final zona = provider.zonaActual?.trim() ?? '';
    final fs = compact ? 12.0 : 13.0;
    final fsPlaca = compact ? 14.0 : 15.0;

    final enLinea = provider.isOnline && !provider.enDescanso;
    final conTurno = provider.isOnline;
    final procesando = provider.procesandoTurno;
    final chipBloqueado =
        procesando || _accionTurnoUiEnCurso || _selectorVehiculoAbierto;

    return Material(
      color: _validandoTurno
          ? AppColors.accent
          : provider.enDescanso
          ? const Color(0xFFF59E0B)
          : enLinea
          ? AppColors.accent
          : Colors.grey.shade600,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: 10,
          vertical: compact ? 7 : 8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: InkWell(
                    onTap: chipBloqueado ? null : _cambiarEstadoConductor,
                    borderRadius: BorderRadius.circular(6),
                    child: Row(
                      children: [
                        if (procesando) ...[
                          const AppBrandLoaderCompact(ringSize: 16),
                          const SizedBox(width: 8),
                          Text(
                            provider.isOnline
                                ? 'Cerrando turno...'
                                : 'Conectando...',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ] else if (_validandoTurno) ...[
                          const AppBrandLoaderCompact(ringSize: 16),
                          const SizedBox(width: 8),
                          const Text(
                            'Validando turno',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ] else if (provider.enDescanso) ...[
                          const Icon(
                            Icons.nightlight_round,
                            color: Colors.white,
                            size: 18,
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            'Descanso',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ] else if (enLinea) ...[
                          const Icon(
                            Icons.check_circle,
                            color: AppColors.green,
                            size: 18,
                          ),
                          const SizedBox(width: 5),
                          const Text(
                            'En línea',
                            style: TextStyle(
                              color: AppColors.green,
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ] else ...[
                          const Icon(
                            Icons.power_settings_new,
                            color: Colors.white,
                            size: 18,
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            'Fuera de línea',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                        if (conTurno && vehiculo != null) ...[
                          const SizedBox(width: 10),
                          Flexible(
                            child: Text(
                              '${vehiculo.placa.toUpperCase()} · Orden '
                              '${vehiculo.asignacionPropietarios.first.afiliacion.numero}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.95),
                                fontSize: fsPlaca,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                _buildBotonDescansoEnChip(provider, compact: compact),
              ],
            ),
            if (conTurno && zona.isNotEmpty) ...[
              const SizedBox(height: 4),
              InkWell(
                onTap: chipBloqueado ? null : _cambiarEstadoConductor,
                borderRadius: BorderRadius.circular(6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.location_on,
                      size: compact ? 15 : 16,
                      color: Colors.white.withValues(alpha: 0.95),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        'Zona: $zona',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.95),
                          fontSize: fs,
                          fontWeight: FontWeight.w800,
                          height: 1.25,
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
    );
  }

  double _topPanelServicios(BuildContext context, ConductorHomeProvider provider) {
    final compact = ConductorMapServiciosTabs.pantallaCompacta(context);
    return ConductorMapServiciosTabs.headerBlockHeight(
      context,
      provider,
      chipAltura: _chipEstadoAltura(provider, compact: compact),
      avisoEsperaEnLlegando: false,
    );
  }

  Widget _buildMapLayer() {
    return Selector<ConductorHomeProvider, _ConductorMapViewData>(
      selector: (_, provider) => _ConductorMapViewData(
        position: provider.currentPosition,
        isLoadingLocation: provider.isLoadingLocation,
        locationMessage: provider.locationMessage,
        zonaActual: provider.zonaActual,
      ),
      shouldRebuild: (prev, next) => prev.shouldRebuildMap(next),
      builder: (context, mapData, _) {
        if (mapData.position == null) {
          final provider = context.read<ConductorHomeProvider>();
          return LocationStatusView(
            isLoading: mapData.isLoadingLocation,
            message: mapData.locationMessage,
            onRetry: provider.handleLocationRecoveryAction,
            actionLabel: provider.locationActionLabel,
            actionIcon: provider.locationActionIcon,
          );
        }

        final pos = mapData.position!;
        final provider = context.read<ConductorHomeProvider>();
        return RepaintBoundary(
          child: StandardMap(
            key: ValueKey('conductor_map_$_mapResumeGeneration'),
            initialPosition: LatLng(pos.latitude, pos.longitude),
            zoom: _zoomDetenido,
            tilt: _tiltNavegacion,
            bearing: _resolverBearing(pos, null),
            myLocationEnabled: false,
            myLocationButtonEnabled: false,
            compassEnabled: false,
            zoomControlsEnabled: false,
            mapPadding: _paddingMapaNavegacion(provider),
            markers: {
              Marker(
                markerId: const MarkerId('current_location'),
                position: LatLng(pos.latitude, pos.longitude),
                infoWindow: InfoWindow(
                  title: 'Tu ubicación',
                  snippet: mapData.zonaActual?.isNotEmpty == true
                      ? mapData.zonaActual
                      : 'Estás aquí',
                ),
                icon: _dotMarker ?? BitmapDescriptor.defaultMarker,
                anchor: const Offset(0.5, 0.5),
                rotation: 0,
              ),
            },
            onMapCreated: (controller) {
              _invalidateMapController();
              _mapController = controller;
              _mapControllerBoundGeneration = _mapResumeGeneration;
              unawaited(_reanudarNavegacionAhora(provider));
            },
            onCameraMoveStarted: () {
              if (_moviendoCamaraProgramaticamente) return;
              _pausarNavegacionTemporalmente();
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ConductorHomeProvider>(
      builder: (context, provider, child) {
        final mostrarTabsServicios = _panelServiciosVisible(provider);
        final compact = ConductorMapServiciosTabs.pantallaCompacta(context);
        return Stack(
          fit: StackFit.expand,
          children: [
            _buildMapLayer(),
            // Chip + TabBar compactos (no ocupan toda la pantalla)
            if (provider.currentPosition != null && mostrarTabsServicios)
              Positioned(
                top: 12,
                left: 10,
                right: 10,
                child: Material(
                  elevation: 3,
                  borderRadius: BorderRadius.circular(10),
                  clipBehavior: Clip.antiAlias,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFF1E1E1E)
                      : Colors.white,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildChipEstadoConductor(
                        context,
                        provider,
                        compact: compact,
                      ),
                      ConductorMapServiciosTabs.tabBar(
                        context: context,
                        controller: _serviciosTabController,
                        llegando: provider.solicitudesOrdenadas.length,
                        enEspera: provider.totalSolicitudesEnEspera,
                      ),
                    ],
                  ),
                ),
              )
            else if (provider.currentPosition != null)
              Positioned(
                top: 12,
                left: 10,
                right: 10,
                child: Material(
                  elevation: 3,
                  borderRadius: BorderRadius.circular(10),
                  clipBehavior: Clip.antiAlias,
                  child: _buildChipEstadoConductor(
                    context,
                    provider,
                    compact: compact,
                  ),
                ),
              ),

            // Panel de solicitudes (altura limitada; vacío en Llegando = solo mapa)
            if (provider.currentPosition != null && mostrarTabsServicios)
              ListenableBuilder(
                listenable: _pendientesProvider,
                builder: (context, _) {
                  if (!ConductorMapServiciosTabs.shouldShowPanel(
                    controller: _serviciosTabController,
                    home: provider,
                    pendientes: _pendientesProvider,
                  )) {
                    return const SizedBox.shrink();
                  }
                  return Positioned(
                    top: _topPanelServicios(context, provider) - 3,
                    left: 12,
                    right: 12,
                    child: ConductorMapServiciosTabs.panel(
                      context: context,
                      controller: _serviciosTabController,
                      home: provider,
                      pendientes: _pendientesProvider,
                      getSolicitudId: _getSolicitudId,
                      segundosRestantes: provider.obtenerSegundosRestantes,
                      onAceptarLlegando: (id) => _aceptarSolicitud(id),
                      onRechazarLlegando: _rechazarSolicitud,
                      onAceptarEspera: _aceptarSolicitud,
                      onDescartarEspera: _rechazarSolicitud,
                      onVerEnEspera: _irATabEnEspera,
                    ),
                  );
                },
              ),

            // Banner de sanciones
            if (_sancionesActivas.isNotEmpty && _bannerVisible)
              Positioned(
                top: mostrarTabsServicios
                    ? _topPanelServicios(context, provider) + 8
                    : _chipEstadoAltura(provider, compact: compact) + 20,
                left: 16,
                right: 16,
                child: _buildSancionesBanner(),
              ),

            // Emergencia siempre visible (no depende del GPS; las coords se resuelven al enviar).
            Positioned(
                right: 16,
                bottom: _fabBottomOffset(provider) + 72,
                child: Consumer<EmergenciaProvider>(
                  builder: (context, emergenciaProvider, _) {
                    if (!emergenciaProvider.estaEnEmergencia) {
                      return Tooltip(
                        message: 'Toca: opciones · Mantén pulsado: envío inmediato',
                        child: GestureDetector(
                          onLongPress: emergenciaProvider.isLoading
                              ? null
                              : () => EmergenciaQuickReport.enviar(
                                    context: context,
                                  ),
                          child: FloatingActionButton.small(
                            heroTag: 'fab_emergencias',
                            onPressed: () => Navigator.pushNamed(
                              context,
                              '/emergencias',
                            ),
                            backgroundColor: Colors.red.shade600,
                            elevation: 4,
                            child: const Icon(
                              Icons.emergency,
                              color: Colors.white,
                            ),
                          ),
                        ),
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
                bottom: _fabBottomOffset(provider) + 16,
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

/// Ejecuta [trabajo] dentro del diálogo y se cierra solo al terminar (evita quedar colgado).
class _DialogoCarga<T> extends StatefulWidget {
  const _DialogoCarga({
    required this.mensaje,
    required this.trabajo,
  });

  final String mensaje;
  final Future<T> Function() trabajo;

  @override
  State<_DialogoCarga<T>> createState() => _DialogoCargaState<T>();
}

class _DialogoCargaState<T> extends State<_DialogoCarga<T>> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_ejecutar()));
  }

  Future<void> _ejecutar() async {
    try {
      final result = await widget.trabajo();
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop(result);
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Dialog(
        backgroundColor: Theme.of(context).cardColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 26),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const AppBrandLoaderCompact(ringSize: 32),
              const SizedBox(height: 16),
              Text(
                widget.mensaje,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CerrarTurnoResultado {
  const _CerrarTurnoResultado._({
    required this.exito,
    this.mensajeError,
  });

  final bool exito;
  final String? mensajeError;

  factory _CerrarTurnoResultado.cancelado() =>
      const _CerrarTurnoResultado._(exito: false);

  factory _CerrarTurnoResultado.ok() =>
      const _CerrarTurnoResultado._(exito: true);

  factory _CerrarTurnoResultado.error(String mensaje) =>
      _CerrarTurnoResultado._(exito: false, mensajeError: mensaje);
}

class _DialogCerrarTurno extends StatefulWidget {
  const _DialogCerrarTurno({
    required this.enDescanso,
    required this.onConfirmar,
  });

  final bool enDescanso;
  final Future<(bool, String)> Function() onConfirmar;

  @override
  State<_DialogCerrarTurno> createState() => _DialogCerrarTurnoState();
}

class _DialogCerrarTurnoState extends State<_DialogCerrarTurno> {
  bool _cerrando = false;

  Future<void> _confirmar() async {
    if (_cerrando) return;
    setState(() => _cerrando = true);
    try {
      final (ok, mensaje) = await widget.onConfirmar();
      if (!mounted) return;
      Navigator.pop(
        context,
        ok ? _CerrarTurnoResultado.ok() : _CerrarTurnoResultado.error(mensaje),
      );
    } finally {
      if (mounted) setState(() => _cerrando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? AppColors.darkCard : Colors.white;
    final bodyColor = isDark
        ? AppColors.darkOnSurface.withValues(alpha: 0.78)
        : Colors.black87;

    return PopScope(
      canPop: !_cerrando,
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 28),
        child: Container(
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: BorderRadius.circular(24),
          ),
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
                      color: Colors.red.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.power_settings_new_rounded,
                      color: Colors.red,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Text(
                      'Cerrar turno',
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
                widget.enDescanso
                    ? '¿Deseas cerrar tu turno? Saldrás del modo descanso y '
                        'dejarás de aparecer en el mapa.'
                    : '¿Deseas desconectarte? Dejarás de aparecer en el mapa '
                        'y no recibirás servicios.',
                style: TextStyle(
                  fontSize: 14,
                  height: 1.45,
                  color: bodyColor,
                ),
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _cerrando
                          ? null
                          : () => Navigator.pop(
                                context,
                                _CerrarTurnoResultado.cancelado(),
                              ),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 46),
                      ),
                      child: const Text('Cancelar'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: _cerrando ? null : _confirmar,
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(0, 46),
                      ),
                      child: _cerrando
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Cerrar turno'),
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

/// Datos mínimos para el mapa; evita rebuild por ticker de solicitudes / chip.
class _ConductorMapViewData {
  const _ConductorMapViewData({
    required this.position,
    required this.isLoadingLocation,
    required this.locationMessage,
    required this.zonaActual,
  });

  final Position? position;
  final bool isLoadingLocation;
  final String locationMessage;
  final String? zonaActual;

  bool shouldRebuildMap(_ConductorMapViewData other) {
    if (isLoadingLocation != other.isLoadingLocation) return true;
    if (locationMessage != other.locationMessage) return true;
    if (zonaActual != other.zonaActual) return true;
    final a = position;
    final b = other.position;
    if (a == null || b == null) return a != b;
    final moved = Geolocator.distanceBetween(
      a.latitude,
      a.longitude,
      b.latitude,
      b.longitude,
    );
    return moved >= RuntimePerfFlags.conductorGpsUiMinMoveMetersNav;
  }
}
