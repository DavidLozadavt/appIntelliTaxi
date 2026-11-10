import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intellitaxi/core/widgets/app_loading_indicator.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:intellitaxi/core/services/reverse_geocoding_service.dart';
import 'package:intellitaxi/features/conductor/controllers/conductor_servicio_socket_controller.dart';
import 'package:intellitaxi/features/conductor/services/conductor_servicio_map_service.dart';
import 'package:intellitaxi/features/conductor/services/conductor_servicio_state_transitions.dart';
import 'package:intellitaxi/features/rides/services/servicio_tracking_service.dart';
import 'package:intellitaxi/features/rides/services/servicio_persistencia_service.dart';
import 'package:intellitaxi/features/rides/services/servicio_notificacion_foreground.dart';
import 'package:intellitaxi/features/conductor/providers/conductor_home_provider.dart';
import 'package:intellitaxi/features/conductor/utils/conductor_servicio_estado_helper.dart';
import 'package:intellitaxi/features/conductor/utils/conductor_servicio_pasajero_helper.dart';
import 'package:intellitaxi/features/conductor/utils/solicitud_display_helper.dart';
import 'package:intellitaxi/features/conductor/widgets/conductor_servicio_bottom_panel.dart';
import 'package:intellitaxi/features/conductor/widgets/ofertas_en_ruta_panel.dart';
import 'package:intellitaxi/core/utils/phone_launcher.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:intellitaxi/shared/widgets/standard_map.dart';
import 'package:intellitaxi/features/rides/widgets/calificacion_dialog.dart';
import 'package:intellitaxi/features/chat/utils/chat_helper.dart';
import 'package:intellitaxi/features/chat/widgets/chat_badge_wrap.dart';
import 'package:intellitaxi/features/auth/providers/auth_provider.dart';
import 'package:intellitaxi/core/services/active_service_screen_registry.dart';
import 'package:intellitaxi/core/services/driver_overlay_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:dio/dio.dart';
import 'package:intellitaxi/core/services/active_service_restoration_service.dart';
import 'package:intellitaxi/core/navigation/app_root_navigation.dart';
import 'package:intellitaxi/core/services/app_logger.dart';
import 'package:intellitaxi/core/services/gps_address_hold.dart';
import 'package:intellitaxi/core/services/precise_gps.dart';
import 'package:intellitaxi/core/geo/map_marker_bearing_helper.dart';
import 'package:intellitaxi/core/services/keep_screen_on_service.dart';

class ConductorServicioActivoScreen extends StatefulWidget {
  final Map<String, dynamic> servicio;
  final int conductorId;

  const ConductorServicioActivoScreen({
    super.key,
    required this.servicio,
    required this.conductorId,
  });

  @override
  State<ConductorServicioActivoScreen> createState() =>
      _ConductorServicioActivoScreenState();
}

class _ConductorServicioActivoScreenState
    extends State<ConductorServicioActivoScreen>
    with WidgetsBindingObserver {
  GoogleMapController? _mapController;
  final ServicioTrackingService _trackingService = ServicioTrackingService();
  final ConductorServicioMapService _mapService = ConductorServicioMapService();
  final ConductorServicioSocketController _socketController =
      ConductorServicioSocketController();
  final ReverseGeocodingService _reverseGeocoding = ReverseGeocodingService();
  final ServicioPersistenciaService _persistencia =
      ServicioPersistenciaService();
  final ServicioNotificacionForeground _notificacionService =
      ServicioNotificacionForeground();
  final DriverOverlayService _driverOverlayService =
      DriverOverlayService.instance;
  final ActiveServiceRestorationService _restoration =
      ActiveServiceRestorationService();

  String _estadoActual = 'aceptado';
  Position? _lastGpsPosition;
  final GpsAddressHold _gpsHold = GpsAddressHold();
  LatLng? _miUbicacion;
  double _miBearing = 0;
  bool _miBearingInicializado = false;
  LatLng? _destinoActual;
  Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  bool _isLoading = false;
  BitmapDescriptor? _carIcon;
  StreamSubscription<Position>? _locationSubscription;
  Timer? _estadoPollTimer;
  bool _terminalNavigationInProgress = false;
  /// Evita doble flujo calificación + home (botón y Pusher).
  bool _finalizacionEnCurso = false;
  /// Evita doble `pushNamedAndRemoveUntil` (p. ej. cancel manual + evento Pusher).
  bool _homeNavigationScheduled = false;

  void _safeSetState(VoidCallback fn) {
    if (!mounted) return;
    setState(fn);
  }

  bool get _canUpdateUi => mounted && !_terminalNavigationInProgress;

  final DraggableScrollableController _sheetController =
      DraggableScrollableController();
  static const double _sheetMin = 0.22;
  /// Tope si el contenido no cabe en la pantalla. El alto real lo marca el panel.
  static const double _sheetTope = 0.92;
  double _sheetFit = 0.78;
  double _sheetSize = 0.78;

  void _alMedirContenido(double alto) {
    if (!mounted) return;
    final pantalla = MediaQuery.sizeOf(context).height;
    if (pantalla <= 0 || alto <= 0) return;
    // Un poco más alta que el contenido, para que el mapa no se coma el viaje.
    final fraccion =
        ((alto + 96) / pantalla).clamp(_sheetMin + 0.04, _sheetTope);
    if ((fraccion - _sheetFit).abs() < 0.012) return;
    final anterior = _sheetFit;
    setState(() => _sheetFit = fraccion);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_sheetController.isAttached || !mounted) return;
      final actual = _sheetController.size;
      if ((actual - anterior).abs() > 0.06 && actual < fraccion - 0.02) {
        return;
      }
      if ((actual - fraccion).abs() < 0.012) return;
      _sheetController.animateTo(
        fraccion,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
    });
  }

  void _onSheetChanged() {
    if (!_sheetController.isAttached || !mounted) return;
    final size = _sheetController.size;
    if ((size - _sheetSize).abs() < 0.012) return;
    setState(() => _sheetSize = size);
  }

  @override
  void initState() {
    super.initState();
    _sheetController.addListener(_onSheetChanged);
    WidgetsBinding.instance.addObserver(this);
    unawaited(KeepScreenOnService.acquire('conductor_servicio_activo'));
    _requestOverlayPermissionSafely();
    _estadoActual = _resolverEstadoInicial(widget.servicio);
    ActiveServiceScreenRegistry.markVisible(
      type: 'conductor',
      serviceId: _safeServiceId(),
    );
    ActiveServiceScreenRegistry.onRemoteTerminal =
        ({required int serviceId, required bool cancelado}) {
      if (!mounted || serviceId != _safeServiceId()) return;
      if (_terminalNavigationInProgress) return;
      _terminalNavigationInProgress = true;
      if (cancelado) {
        unawaited(_salirPorServicioCancelado());
      } else {
        unawaited(_salirPorServicioCerradoRemoto());
      }
    };
    _estadoPollTimer = Timer.periodic(
      const Duration(seconds: 28),
      (_) => unawaited(_sincronizarServicioRemotoEnResume()),
    );
    _inicializar();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final provider = context.read<ConductorHomeProvider>();
      final servicioId = widget.servicio['id'];
      final idInt = servicioId is int
          ? servicioId
          : int.tryParse(servicioId?.toString() ?? '');
      if (idInt != null) {
        unawaited(provider.marcarEnServicio(servicioId: idInt));
      }
    });
  }

  @override
  void dispose() {
    _terminalNavigationInProgress = true;
    _sheetController.removeListener(_onSheetChanged);
    _sheetController.dispose();
    _estadoPollTimer?.cancel();
    _estadoPollTimer = null;
    if (ActiveServiceScreenRegistry.onRemoteTerminal != null) {
      ActiveServiceScreenRegistry.onRemoteTerminal = null;
    }
    WidgetsBinding.instance.removeObserver(this);
    _locationSubscription?.cancel();
    _locationSubscription = null;
    _desuscribirEventosServicio();
    _driverOverlayService.hide();
    ActiveServiceScreenRegistry.markHidden(
      type: 'conductor',
      serviceId: _safeServiceId(),
    );
    _trackingService.detenerSeguimiento();
    unawaited(KeepScreenOnService.release('conductor_servicio_activo'));
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_sincronizarServicioRemotoEnResume());
    }
  }

  Future<void> _sincronizarServicioRemotoEnResume() async {
    if (_terminalNavigationInProgress || !mounted) return;
    final sid = _safeServiceId();
    if (sid <= 0) return;
    try {
      final bundle = await _restoration.obtenerServicioActivoConductorOCerrado();
      if (!mounted || _terminalNavigationInProgress) return;
      if (bundle == null) {
        _terminalNavigationInProgress = true;
        await _salirPorServicioCerradoRemoto();
        return;
      }
      final serv = bundle['servicio'];
      if (serv is! Map<String, dynamic>) return;
      final rid = serv['id'] is int
          ? serv['id'] as int
          : int.tryParse(serv['id']?.toString() ?? '') ?? 0;
      if (rid != sid) return;
      if (!_canUpdateUi) return;

      if (!_restoration.esServicioActivo(serv)) {
        _terminalNavigationInProgress = true;
        final idEst = serv['idEstado'] is int
            ? serv['idEstado'] as int
            : int.tryParse(serv['idEstado']?.toString() ?? '');
        final ui =
            _estadoDesdeId(idEst) ?? _normalizarEstadoBackend(serv['estado']);
        if (idEst == 6 || ui == 'cancelado') {
          await _salirPorServicioCancelado();
        } else if (idEst == 22 || ui == 'finalizado') {
          await _programarFinalizacionViaje();
        } else {
          await _salirPorServicioCerradoRemoto();
        }
        return;
      }

      _safeSetState(() {
        widget.servicio.addAll(serv);
        final idEst = serv['idEstado'] is int
            ? serv['idEstado'] as int
            : int.tryParse(serv['idEstado']?.toString() ?? '');
        if (idEst != null) widget.servicio['idEstado'] = idEst;
        final ui =
            _estadoDesdeId(idEst) ?? _normalizarEstadoBackend(serv['estado']);
        if (ui != null) _estadoActual = ui;
        _actualizarDestinoSegunEstado(ui);
      });

      if (_estadoUiEfectivo == 'cancelado') {
        _terminalNavigationInProgress = true;
        await _salirPorServicioCancelado();
        return;
      }
      if (_estadoUiEfectivo == 'finalizado') {
        await _programarFinalizacionViaje();
        return;
      }

      await _guardarServicioActivo();
      _actualizarMarcadores();
      unawaited(_dibujarRuta());
    } on DioException {
      // Fallo de red: no cerrar pantalla
    } catch (e) {
      AppLogger.d('⚠️ Resume sync servicio conductor: $e');
    }
  }

  void _hidratarCoordenadasSolicitud() {
    final n = SolicitudDisplayHelper.normalizeSolicitudMap(widget.servicio);
    widget.servicio.addAll(n);
  }

  /// Punto donde pidieron el servicio (recogida). WhatsApp no trae destino.
  LatLng? _puntoSolicitud() {
    final n = SolicitudDisplayHelper.normalizeSolicitudMap(widget.servicio);
    final lat = SolicitudDisplayHelper.parseCoordinate(n['origen_lat']);
    final lng = SolicitudDisplayHelper.parseCoordinate(n['origen_lng']);
    if (lat == null || lng == null) return null;
    if (lat.abs() < 1e-6 && lng.abs() < 1e-6) return null;
    return LatLng(lat, lng);
  }

  void _actualizarDestinoSegunEstado(String? ui) {
    if (ui == null) return;
    _destinoActual = ConductorServicioStateTransitions.resolveDestinoNavegacion(
      servicio: widget.servicio,
      estadoUi: ui,
    );
    if (_destinoActual == null &&
        (ui == 'aceptado' || ui == 'en_camino')) {
      _destinoActual = _puntoSolicitud();
    }
  }

  bool _debeTrazarRutaAlPunto() {
    if (_estadoUiEfectivo == 'aceptado' || _estadoUiEfectivo == 'en_camino') {
      return true;
    }
    if (_estadoUiEfectivo == 'llegue' || _estadoUiEfectivo == 'en_curso') {
      return _tieneDestinoDefinido();
    }
    return false;
  }

  Future<void> _salirPorServicioCerradoRemoto() async {
    try {
      _trackingService.detenerSeguimiento();
      await _notificacionService.cancelarNotificacion(
        _safeServiceId(),
        tipo: 'conductor',
      );
      await _persistencia.limpiarServicioActivo();
    } catch (_) {}

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('El servicio ya no está activo en el servidor'),
        backgroundColor: Colors.grey,
      ),
    );
    await _navegarAlHomeRaiz();
  }

  Future<void> _requestOverlayPermissionSafely() async {
    // Evita pelear con el primer frame y transiciones de Android.
    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;
    await _driverOverlayService.requestPermissionIfNeeded();
  }

  int _safeServiceId() {
    final rawId = widget.servicio['id'];
    if (rawId is int) return rawId;
    return int.tryParse(rawId?.toString() ?? '') ?? 0;
  }

  /// Vuelve al home: cierra overlay flotante (Android), deja de escuchar Pusher y reemplaza la pila
  /// por [NavigationScreen] (mismo módulo que usa el pasajero tras cancelar).
  Future<void> _navegarAlHomeRaiz() async {
    if (_homeNavigationScheduled) return;
    _homeNavigationScheduled = true;
    _terminalNavigationInProgress = true;
    try {
      _desuscribirEventosServicio();
    } catch (_) {}
    try {
      if (mounted) {
        await context.read<ConductorHomeProvider>().marcarDisponible();
      }
    } catch (_) {}
    try {
      await _driverOverlayService.hide();
    } catch (_) {}

    // Sin setState el overlay de cancelación (Colors.black54) sigue pintado aunque _isLoading sea false.
    _isLoading = false;
    if (_canUpdateUi) {
      _safeSetState(() {});
    }

    navigateReplacingStackWithHome(
      context: _canUpdateUi ? context : null,
      onSettled: (ok) {
        if (ok) return;
        _homeNavigationScheduled = false;
        _terminalNavigationInProgress = false;
        AppLogger.d('⚠️ _navegarAlHomeRaiz: navegación no aplicada, flags liberados');
        if (_canUpdateUi) _safeSetState(() {});
      },
    );
  }

  bool _tieneDestinoDefinido() =>
      ConductorServicioEstadoHelper.tieneDestinoDefinido(widget.servicio);

  Future<String?> _resolverDireccionDesdeCoordenadas(LatLng punto) =>
      _reverseGeocoding.resolveFormattedAddress(
        lat: punto.latitude,
        lng: punto.longitude,
      );

  String _resolverEstadoInicial(Map<String, dynamic> servicio) =>
      ConductorServicioEstadoHelper.resolverEstadoInicial(servicio);

  String? _normalizarEstadoBackend(dynamic estadoRaw) =>
      ConductorServicioEstadoHelper.normalizarEstadoBackend(estadoRaw);

  String? _estadoDesdeId(int? idEstado) =>
      ConductorServicioEstadoHelper.estadoDesdeId(idEstado);

  String get _estadoUiEfectivo =>
      ConductorServicioEstadoHelper.estadoUiEfectivo(
        servicio: widget.servicio,
        estadoActual: _estadoActual,
      );

  double _parseDouble(dynamic value) =>
      ConductorServicioEstadoHelper.parseDouble(value);

  String _getNombrePasajero() =>
      ConductorServicioPasajeroHelper.nombre(widget.servicio);

  String? _getTelefonoPasajero() =>
      ConductorServicioPasajeroHelper.telefonoParaMostrar(widget.servicio);

  Future<void> _copiarTelefonoPasajero() async {
    final telefono = _getTelefonoPasajero();
    if (telefono == null || telefono.trim().isEmpty) {
      _mostrarError('No hay teléfono para copiar');
      return;
    }
    await Clipboard.setData(ClipboardData(text: telefono.trim()));
    if (!mounted) return;
    _mostrarMensaje('Teléfono copiado al portapapeles');
  }

  String? _getFotoPasajero() =>
      ConductorServicioPasajeroHelper.fotoUrl(widget.servicio);

  Future<void> _cargarIconoCarro() async {
    try {
      _carIcon = await BitmapDescriptor.asset(
        const ImageConfiguration(size: Size(30, 30)),
        'assets/images/marker.png',
      );
      AppLogger.d('✅ CONDUCTOR: Ícono del carro cargado');
    } catch (e) {
      AppLogger.d('⚠️ Error cargando ícono del carro: $e');
    }
  }

  Future<void> _inicializar() async {
    _estadoActual = _estadoUiEfectivo;
    if (_estadoUiEfectivo == 'cancelado') {
      await _salirPorServicioCancelado();
      return;
    }

    // Debug: Ver estructura completa del servicio
    AppLogger.d('🔍 DATOS DEL SERVICIO RECIBIDOS:');
    AppLogger.d('   ID: ${widget.servicio['id']}');
    AppLogger.d(
      '   Pasajero nombre directo: ${widget.servicio['pasajero_nombre']}',
    );
    AppLogger.d('   Pasajero objeto: ${widget.servicio['pasajero']}');
    AppLogger.d('   Precio final: ${widget.servicio['precio_final']}');
    AppLogger.d('   Precio estimado: ${widget.servicio['precio_estimado']}');
    AppLogger.d('   Origen: ${widget.servicio['origen_address']}');
    AppLogger.d('   Destino: ${widget.servicio['destino_address']}');
    AppLogger.d('');

    // Cargar iconos personalizados
    await _cargarIconoCarro();
    if (!_canUpdateUi) return;
    await _crearDotMarkers();
    if (!_canUpdateUi) return;

    // Inicializar servicio de notificaciones
    await _notificacionService.inicializar();
    if (!_canUpdateUi) return;

    // Guardar servicio activo localmente
    await _guardarServicioActivo();
    if (!_canUpdateUi) return;

    // Mostrar notificación persistente
    await _mostrarNotificacionPersistente();
    if (!_canUpdateUi) return;

    // Iniciar seguimiento
    await _trackingService.iniciarSeguimiento(
      servicioId: widget.servicio['id'],
      conductorId: widget.conductorId,
    );
    if (!_canUpdateUi) return;

    // WhatsApp / sin destino: la línea va de mi carro al punto de la solicitud.
    _hidratarCoordenadasSolicitud();
    _safeSetState(() {
      _destinoActual = ConductorServicioStateTransitions.resolveDestinoNavegacion(
            servicio: widget.servicio,
            estadoUi: _estadoUiEfectivo,
          ) ??
          _puntoSolicitud();
    });

    // Obtener ubicación actual
    await _obtenerUbicacionActual();
    if (!_canUpdateUi) return;

    // Actualizar marcadores
    _actualizarMarcadores();

    // Escuchar cancelación/finalización remota del servicio.
    await _suscribirEventosServicio();
  }

  Future<void> _suscribirEventosServicio() async {
    if (!_canUpdateUi) return;
    await _socketController.subscribe(
      servicioId: _safeServiceId(),
      onEstado: _manejarEventoEstadoServicio,
    );
  }

  void _desuscribirEventosServicio() {
    _socketController.unsubscribe(_safeServiceId());
  }

  void _manejarEventoEstadoServicio(ConductorServicioEstadoSocketEvent event) {
    if (!mounted || _terminalNavigationInProgress) return;

    if (event.estadoId != null) {
      widget.servicio['idEstado'] = event.estadoId;
    }
    if (event.estadoNombre != null && event.estadoNombre!.isNotEmpty) {
      widget.servicio['estado'] = event.estadoNombre;
    }

    if (event.cancelado) {
      _terminalNavigationInProgress = true;
      unawaited(_salirPorServicioCancelado());
      return;
    }

    if (event.finalizado) {
      unawaited(_programarFinalizacionViaje());
      return;
    }

    final estadoUi = event.estadoUi;
    if (!_canUpdateUi) return;
    _safeSetState(() {
      if (estadoUi != null) {
        _estadoActual = estadoUi;
      }
      _actualizarDestinoSegunEstado(estadoUi);
    });

    unawaited(_guardarServicioActivo());
    _actualizarMarcadores();
    unawaited(_dibujarRuta());

    unawaited(
      _notificacionService.actualizarNotificacion(
        servicioId: _safeServiceId(),
        tipo: 'conductor',
        estado: estadoUi ?? _estadoActual,
        origen: widget.servicio['origen_address'] ?? 'Origen',
        destino: widget.servicio['destino_address'] ?? 'A convenir',
      ),
    );
  }

  Future<void> _guardarServicioActivo() async {
    try {
      AppLogger.d('📋 Intentando guardar servicio activo...');
      AppLogger.d('📦 Datos del servicio: ${widget.servicio}');

      final servicioId = widget.servicio['id'];
      if (servicioId == null) {
        AppLogger.d('❌ Error: servicioId es null');
        AppLogger.d('📦 Keys disponibles: ${widget.servicio.keys}');
        return;
      }

      await _persistencia.guardarServicioActivo(
        servicioId: servicioId,
        tipo: 'conductor',
        datosServicio: widget.servicio,
      );
      AppLogger.d('✅ Servicio activo guardado: $servicioId');
    } catch (e, stackTrace) {
      AppLogger.d('❌ Error guardando servicio activo: $e');
      AppLogger.d('Stack trace: $stackTrace');
    }
  }

  Future<void> _mostrarNotificacionPersistente() async {
    await _notificacionService.mostrarNotificacionConductor(
      servicioId: widget.servicio['id'],
      estado: _estadoUiEfectivo,
      origen: widget.servicio['origen_address'] ?? 'Origen',
      destino: widget.servicio['destino_address'] ?? 'Destino',
    );
  }

  Future<void> _obtenerUbicacionActual() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: PreciseGps.currentPosition(
          timeLimit: const Duration(seconds: 12),
        ),
      );

      // Verificar que el widget siga montado antes de llamar setState
      if (!mounted) return;

      _lastGpsPosition = position;
      _aplicarUbicacionConductor(_gpsHold.apply(position));
      unawaited(_alinearPinConDireccion(position));

      // Actualizar marcadores y ruta
      _actualizarMarcadores();
      _dibujarRuta();

      _ajustarCamaraARuta();

      // Iniciar escucha continua de ubicación
      _iniciarStreamUbicacion();
    } catch (e) {
      AppLogger.d('❌ Error obteniendo ubicación: $e');
    }
  }

  DateTime _ultimoRedibujoRuta = DateTime.now();

  void _iniciarStreamUbicacion() {
    _locationSubscription?.cancel();
    _locationSubscription =
        Geolocator.getPositionStream(
          locationSettings: PreciseGps.stream(
            use: PreciseGpsUse.navigation,
            distanceFilter: 2,
          ),
        ).listen((position) {
          if (!_canUpdateUi) return;
          if (!PreciseGps.shouldAccept(position, _lastGpsPosition)) return;
          _lastGpsPosition = position;

          _aplicarUbicacionConductor(_gpsHold.apply(position));
          _actualizarMarcadores();
          if (_gpsHold.shouldRefresh(position.latitude, position.longitude)) {
            unawaited(_alinearPinConDireccion(position));
          }

          // Redibujar ruta máximo cada 30 segundos para no abusar de la API
          final ahora = DateTime.now();
          if (ahora.difference(_ultimoRedibujoRuta).inSeconds >= 30) {
            _ultimoRedibujoRuta = ahora;
            _dibujarRuta();
          }
        });
  }

  Future<void> _alinearPinConDireccion(Position raw) async {
    final changed = await _gpsHold.refresh(
      ReverseGeocodingService.shared,
      raw,
    );
    if (!changed || !mounted) return;
    final latest = _lastGpsPosition;
    if (latest == null) return;
    final moved = Geolocator.distanceBetween(
      raw.latitude,
      raw.longitude,
      latest.latitude,
      latest.longitude,
    );
    if (moved > GpsAddressHold.releaseMeters) return;
    _aplicarUbicacionConductor(_gpsHold.apply(latest));
    _actualizarMarcadores();
  }

  void _aplicarUbicacionConductor(Position position) {
    final nueva = LatLng(position.latitude, position.longitude);
    final anterior = _miUbicacion;
    final speed = position.speed.isFinite && position.speed >= 0
        ? position.speed
        : 0.0;
    final headingValido =
        position.heading.isFinite &&
        position.heading >= 0 &&
        position.heading <= 360;

    double objetivo;
    if (headingValido && speed > 1.2) {
      objetivo = position.heading;
    } else {
      objetivo = MapMarkerBearingHelper.resolveBearing(
        to: nueva,
        from: anterior,
        backendRumbo: null,
        fallback: _miBearing,
      );
    }

    final suavizado = MapMarkerBearingHelper.smoothBearing(
      current: _miBearing,
      target: objetivo,
      factor: 0.35,
      initialized: _miBearingInicializado,
    );

    _safeSetState(() {
      _miUbicacion = nueva;
      _miBearing = suavizado;
      _miBearingInicializado = true;
    });
  }

  Future<void> _crearDotMarkers() => _mapService.ensureDotMarkers();

  void _actualizarMarcadores() {
    if (!_canUpdateUi) return;
    _safeSetState(() {
      _markers = _mapService.buildMarkers(
        servicio: widget.servicio,
        miUbicacion: _miUbicacion,
        carIcon: _carIcon,
        miBearing: _miBearing,
      );
    });
  }

  Future<void> _dibujarRuta() async {
    if (!_debeTrazarRutaAlPunto()) {
      if (!_canUpdateUi) return;
      _safeSetState(_polylines.clear);
      if (_miUbicacion != null) {
        _mapController?.animateCamera(CameraUpdate.newLatLng(_miUbicacion!));
      }
      return;
    }

    _destinoActual ??= _puntoSolicitud();
    if (_miUbicacion == null || _destinoActual == null) return;

    final color = _estadoUiEfectivo == 'en_curso' && _tieneDestinoDefinido()
        ? Colors.green
        : Colors.blue;
    final polyline = await _mapService.buildRoutePolyline(
      origin: _miUbicacion!,
      destination: _destinoActual!,
      color: color,
    );

    if (!mounted || polyline == null) return;

    _safeSetState(() {
      _polylines
        ..clear()
        ..add(polyline);
    });
    _ajustarCamaraARuta();
  }

  void _ajustarCamaraARuta() {
    if (_mapController == null || _miUbicacion == null) return;
    final destino = _destinoActual;
    if (destino == null) {
      _mapController!.animateCamera(CameraUpdate.newLatLng(_miUbicacion!));
      return;
    }

    final south = _miUbicacion!.latitude < destino.latitude
        ? _miUbicacion!.latitude
        : destino.latitude;
    final north = _miUbicacion!.latitude > destino.latitude
        ? _miUbicacion!.latitude
        : destino.latitude;
    final west = _miUbicacion!.longitude < destino.longitude
        ? _miUbicacion!.longitude
        : destino.longitude;
    final east = _miUbicacion!.longitude > destino.longitude
        ? _miUbicacion!.longitude
        : destino.longitude;

    try {
      _mapController!.animateCamera(
        CameraUpdate.newLatLngBounds(
          LatLngBounds(
            southwest: LatLng(south, west),
            northeast: LatLng(north, east),
          ),
          56,
        ),
      );
    } catch (_) {
      _mapController!.animateCamera(CameraUpdate.newLatLng(_miUbicacion!));
    }
  }

  Future<void> _cambiarEstado(String nuevoEstado) async {
    if (!mounted || _finalizacionEnCurso || _homeNavigationScheduled) return;
    _safeSetState(() => _isLoading = true);

    double? destinoFinalLat;
    double? destinoFinalLng;
    String? destinoFinalAddress;
    try {
      if (nuevoEstado == 'finalizado' &&
          !_tieneDestinoDefinido() &&
          _miUbicacion != null) {
        destinoFinalLat = _miUbicacion!.latitude;
        destinoFinalLng = _miUbicacion!.longitude;
        final resolved =
            await _resolverDireccionDesdeCoordenadas(_miUbicacion!);
        destinoFinalAddress =
            resolved ??
            'Destino final (${destinoFinalLat.toStringAsFixed(5)}, ${destinoFinalLng.toStringAsFixed(5)})';
      }

      final success = await ServicioTrackingService.cambiarEstadoStatic(
        servicioId: widget.servicio['id'],
        conductorId: widget.conductorId,
        estado: nuevoEstado,
        destinoFinalLat: destinoFinalLat,
        destinoFinalLng: destinoFinalLng,
        destinoFinalAddress: destinoFinalAddress,
      );

      if (!mounted) return;

      if (!success) {
        if (!_finalizacionEnCurso) {
          _mostrarError('No se pudo actualizar el estado');
        }
        return;
      }

      if (nuevoEstado == 'finalizado') {
        if (!_tieneDestinoDefinido() &&
            destinoFinalLat != null &&
            destinoFinalLng != null) {
          ConductorServicioStateTransitions.applyDestinoFinalOnMap(
            servicio: widget.servicio,
            lat: destinoFinalLat,
            lng: destinoFinalLng,
            address: destinoFinalAddress,
          );
        }
        await _programarFinalizacionViaje();
        return;
      }

      if (!_canUpdateUi) return;
      _safeSetState(() {
        _estadoActual = nuevoEstado;
        ConductorServicioStateTransitions.applyIdEstadoForUi(
          widget.servicio,
          nuevoEstado,
        );
        _actualizarDestinoSegunEstado(nuevoEstado);
      });

      // Actualizar notificación persistente
      await _notificacionService.actualizarNotificacion(
        servicioId: _safeServiceId(),
        tipo: 'conductor',
        estado: nuevoEstado,
        origen: widget.servicio['origen_address'] ?? 'Origen',
        destino: widget.servicio['destino_address'] ?? 'A convenir',
      );

      _mostrarMensaje(_getMensajeEstado(nuevoEstado));
      _actualizarMarcadores();
      _dibujarRuta();
    } finally {
      if (mounted && !_finalizacionEnCurso && _isLoading) {
        _safeSetState(() => _isLoading = false);
      }
    }
  }

  /// Un solo camino al terminar el viaje (evita loading colgado si Pusher llega antes que el API).
  Future<void> _programarFinalizacionViaje() async {
    if (_finalizacionEnCurso || _homeNavigationScheduled) return;
    _finalizacionEnCurso = true;

    if (mounted) {
      _safeSetState(() {
        _isLoading = false;
        _estadoActual = 'finalizado';
        widget.servicio['idEstado'] = 22;
        widget.servicio['estado'] = 'finalizado';
      });
    }

    await _finalizarServicio();
  }

  Future<void> _finalizarServicio() async {
    try {
      _trackingService.detenerSeguimiento();

      await _notificacionService.cancelarNotificacion(
        _safeServiceId(),
        tipo: 'conductor',
      );

      await _persistencia.limpiarServicioActivo();

      if (mounted) {
        await _mostrarDialogoCalificacionPasajero();
      }

      await _navegarAlHomeRaiz();
    } catch (e, st) {
      AppLogger.e(
        'Error en finalización de viaje',
        tag: 'ConductorServicio',
        error: e,
        stackTrace: st,
      );
      if (mounted && !_homeNavigationScheduled) {
        _finalizacionEnCurso = false;
        _safeSetState(() => _isLoading = false);
        _mostrarError('No se pudo cerrar el viaje. Intenta de nuevo.');
      }
    }
  }

  Future<void> _salirPorServicioCancelado() async {
    try {
      _trackingService.detenerSeguimiento();
      await _notificacionService.cancelarNotificacion(
        _safeServiceId(),
        tipo: 'conductor',
      );
      await _persistencia.limpiarServicioActivo();
    } catch (_) {
      // Ignorar errores de limpieza para priorizar salida de pantalla.
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('❌ El servicio fue cancelado'),
        backgroundColor: Colors.grey,
      ),
    );
    await _navegarAlHomeRaiz();
  }

  /// Muestra el diálogo para calificar al pasajero
  Future<void> _mostrarDialogoCalificacionPasajero() async {
    try {
      // Obtener IDs necesarios
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final conductorId = authProvider.user?.id;

      if (conductorId == null) {
        AppLogger.d('⚠️ No se pudo obtener ID del conductor');
        return;
      }

      // Obtener ID del pasajero
      int? pasajeroId;
      String nombrePasajero = _getNombrePasajero();
      String? fotoPasajero = _getFotoPasajero();

      // Intentar obtener el ID del pasajero de diferentes fuentes
      if (widget.servicio['usuario_pasajero'] != null) {
        final usuarioPasajero = widget.servicio['usuario_pasajero'];
        if (usuarioPasajero is Map) {
          pasajeroId = usuarioPasajero['id'] ?? usuarioPasajero['usuario_id'];

        }
      } else if (widget.servicio['pasajero_id'] != null) {
        pasajeroId = widget.servicio['pasajero_id'] is int
            ? widget.servicio['pasajero_id']
            : int.tryParse(widget.servicio['pasajero_id'].toString());
      }

      if (pasajeroId == null) {
        AppLogger.d('⚠️ No se pudo obtener ID del pasajero');
        return;
      }

      // Mostrar diálogo de calificación
      final resultado = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => CalificacionDialog(
          idServicio: widget.servicio['id'],
          idUsuarioCalifica: conductorId,
          idUsuarioCalificado: pasajeroId!,
          tipoCalificacion: 'PASAJERO',
          nombreCalificado: nombrePasajero,
          fotoCalificado: fotoPasajero,
        ),
      );

      if (resultado == true) {
        AppLogger.d('✅ Calificación del pasajero registrada');
      }
    } catch (e) {
      AppLogger.d('❌ Error al mostrar diálogo de calificación: $e');
    }
  }

  String _getMensajeEstado(String estado) =>
      ConductorServicioEstadoHelper.mensajeEstado(estado);

  void _mostrarMensaje(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _mostrarError(String error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _llamarPasajero() async {
    await PhoneLauncher.dial(
      _getTelefonoPasajero(),
      context: context,
    );
  }

  String _nombreConductorParaMensaje() {
    final auth = context.read<AuthProvider>();
    final nombre = auth.user?.nombreCompleto.trim() ?? '';
    if (nombre.isNotEmpty) return nombre.split(RegExp(r'\s+')).first;
    return 'tu conductor';
  }

  String? _placaConductorParaMensaje() {
    final vehiculo = widget.servicio['vehiculo'];
    if (vehiculo is Map) {
      final p = vehiculo['placa']?.toString().trim();
      if (p != null && p.isNotEmpty) return p;
    }
    for (final key in const [
      'vehiculo_placa',
      'placa_vehiculo',
      'placa',
    ]) {
      final p = widget.servicio[key]?.toString().trim();
      if (p != null && p.isNotEmpty) return p;
    }
    try {
      return context.read<ConductorHomeProvider>().vehiculoSeleccionado?.placa;
    } catch (_) {
      return null;
    }
  }

  Future<void> _whatsappPasajero() async {
    final mensaje = PhoneLauncher.mensajeConductorParaPasajero(
      nombreConductor: _nombreConductorParaMensaje(),
      placa: _placaConductorParaMensaje(),
    );
    await PhoneLauncher.openWhatsApp(
      _getTelefonoPasajero(),
      mensaje: mensaje,
      context: context,
    );
  }

  Future<void> _abrirChatPasajero() async {
    final servicioId = _servicioActivoId;
    if (servicioId == null || servicioId <= 0) {
      _mostrarError('No se pudo abrir el chat (servicio no válido)');
      return;
    }

    final authProvider = context.read<AuthProvider>();
    final miUserId = authProvider.userId ?? 0;
    await ChatHelper.abrirChat(
      context: context,
      servicioId: servicioId,
      miUserId: miUserId,
    );
  }

  int? get _servicioActivoId {
    final raw = widget.servicio['id'];
    if (raw is int) return raw;
    return int.tryParse(raw?.toString() ?? '');
  }

  /// Punto de referencia para filtrar ofertas hacia el sector del viaje actual.
  LatLng? _puntoReferenciaRuta() {
    final destinoLat = _parseDouble(widget.servicio['destino_lat']);
    final destinoLng = _parseDouble(widget.servicio['destino_lng']);
    if (destinoLat != 0 && destinoLng != 0) {
      return LatLng(destinoLat, destinoLng);
    }
    final origenLat = _parseDouble(widget.servicio['origen_lat']);
    final origenLng = _parseDouble(widget.servicio['origen_lng']);
    if (origenLat != 0 && origenLng != 0) {
      return LatLng(origenLat, origenLng);
    }
    return _destinoActual ?? _miUbicacion;
  }

  Future<void> _aceptarOfertaEnRuta(
    Map<String, dynamic> solicitud,
    String solicitudId,
  ) async {
    final origen = SolicitudDisplayHelper.pickupAddress(solicitud);
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Aceptar esta oferta?'),
        content: Text(
          'Tienes un viaje en curso.\n\n$origen\n\nSe intentará asignar este servicio. Si el sistema no permite dos viajes a la vez, verás un mensaje del servidor.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Aceptar'),
          ),
        ],
      ),
    );
    if (confirmar != true || !mounted) return;

    final provider = context.read<ConductorHomeProvider>();
    final vehiculoId = provider.vehiculoSeleccionado?.id ?? 0;

    _safeSetState(() => _isLoading = true);
    try {
      final response = await provider.aceptarSolicitud(solicitudId, vehiculoId);
      if (!_canUpdateUi) return;
      if (response != null) {
        _mostrarMensaje(
          'Oferta aceptada. Continúa tu viaje actual; revisa el servicio al finalizar.',
        );
      } else {
        _mostrarError(
          provider.lastAcceptError ?? 'No se pudo aceptar la oferta',
        );
      }
    } finally {
      if (_canUpdateUi) _safeSetState(() => _isLoading = false);
    }
  }

  void _rechazarOfertaEnRuta(String solicitudId) {
    unawaited(
      context.read<ConductorHomeProvider>().rechazarSolicitudParaConductor(
        solicitudId,
      ),
    );
  }

  Future<void> _llamarOfertaEnRuta(Map<String, dynamic> solicitud) async {
    final telefono = ConductorServicioPasajeroHelper.telefono(solicitud);

    if (telefono == null || telefono.isEmpty) {
      _mostrarError('No hay teléfono de contacto en esta solicitud');
      return;
    }

    final ok = await PhoneLauncher.dial(telefono, context: context);
    if (!ok && mounted) {
      _mostrarError('No se pudo abrir la aplicación de llamadas');
    }
  }

  Future<void> _abrirNavegacion() async {
    if (_destinoActual == null) return;

    final lat = _destinoActual!.latitude;
    final lng = _destinoActual!.longitude;

    // Intentar abrir Waze primero
    final wazeUrl = Uri.parse('waze://?ll=$lat,$lng&navigate=yes');
    if (await canLaunchUrl(wazeUrl)) {
      await launchUrl(wazeUrl, mode: LaunchMode.externalApplication);
      return;
    }

    // Fallback: abrir Google Maps
    final gmapsUrl = Uri.parse('google.navigation:q=$lat,$lng&mode=d');
    if (await canLaunchUrl(gmapsUrl)) {
      await launchUrl(gmapsUrl, mode: LaunchMode.externalApplication);
      return;
    }

    // Fallback final: abrir en navegador
    final webUrl = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving',
    );
    await launchUrl(webUrl, mode: LaunchMode.externalApplication);
  }

  Widget _barraMapa() {
    final ia = ConductorServicioPasajeroHelper.esGestionadoPorIa(
      widget.servicio,
    );
    final titulo = switch (_estadoUiEfectivo) {
      'en_curso' => 'Viaje en curso',
      'llegue' => 'En el punto',
      _ => 'Servicio en curso',
    };
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Color(0xFF22C55E),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                titulo,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
        const Spacer(),
        if (ia) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF3EEFF),
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Iconsax.cpu, size: 14, color: Color(0xFF6D28D9)),
                SizedBox(width: 6),
                Text(
                  'IA Activa',
                  style: TextStyle(
                    color: Color(0xFF6D28D9),
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
        ],
        PopupMenuButton<String>(
          tooltip: 'Más',
          onSelected: (value) {
            switch (value) {
              case 'chat':
                _abrirChatPasajero();
              case 'navegar':
                _abrirNavegacion();
              case 'copiar':
                unawaited(_copiarTelefonoPasajero());
            }
          },
          itemBuilder: (context) => const [
            PopupMenuItem(value: 'chat', child: Text('Chat')),
            PopupMenuItem(value: 'navegar', child: Text('Navegar')),
            PopupMenuItem(value: 'copiar', child: Text('Copiar teléfono')),
          ],
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 8,
                ),
              ],
            ),
            child: const Icon(Icons.more_horiz, size: 20),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final puntoRuta = _puntoReferenciaRuta();

    return ChatBadgeLifecycle(
      servicioId: _safeServiceId(),
      child: PopScope(
      canPop: false,
      child: Scaffold(
        body: Stack(
          children: [
            Positioned.fill(
              child: _miUbicacion != null
                  ? StandardMap(
                      initialPosition: _miUbicacion!,
                      zoom: 15,
                      markers: _markers,
                      polylines: _polylines,
                      mapPadding: EdgeInsets.fromLTRB(
                        12,
                        72,
                        16,
                        MediaQuery.sizeOf(context).height * _sheetSize + 16,
                      ),
                      onMapCreated: (controller) {
                        _mapController = controller;
                        _ajustarCamaraARuta();
                      },
                    )
                  : const Center(child: AppLoadingIndicator()),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                  child: Column(
                    children: [
                      _barraMapa(),
                    ],
                  ),
                ),
              ),
            ),
            if (puntoRuta != null)
              Positioned(
                top: 72,
                left: 12,
                right: 12,
                child: OfertasEnRutaPanel(
                  haciaLat: puntoRuta.latitude,
                  haciaLng: puntoRuta.longitude,
                  excluirServicioId: _servicioActivoId,
                  onAceptar: _aceptarOfertaEnRuta,
                  onRechazar: _rechazarOfertaEnRuta,
                  onLlamar: _llamarOfertaEnRuta,
                ),
              ),
            DraggableScrollableSheet(
              controller: _sheetController,
              initialChildSize: _sheetFit,
              minChildSize: _sheetMin,
              maxChildSize: _sheetFit,
              snap: true,
              builder: (context, scrollController) {
                return DecoratedBox(
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(28),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 18,
                        offset: const Offset(0, -4),
                      ),
                    ],
                  ),
                  child: ConductorServicioBottomPanel(
                    servicio: widget.servicio,
                    servicioId: _safeServiceId(),
                    estadoUi: _estadoUiEfectivo,
                    nombrePasajero: _getNombrePasajero(),
                    telefonoPasajero: _getTelefonoPasajero(),
                    etiquetaOrigen: ConductorServicioPasajeroHelper
                        .etiquetaOrigenServicio(widget.servicio),
                    esGestionadoPorIa: ConductorServicioPasajeroHelper
                        .esGestionadoPorIa(widget.servicio),
                    fotoPasajeroUrl: _getFotoPasajero(),
                    onLlamar: _llamarPasajero,
                    onWhatsApp: _whatsappPasajero,
                    onCopiarTelefono: _copiarTelefonoPasajero,
                    onChat: _abrirChatPasajero,
                    onAccionPrincipal: _onPanelAccionPrincipal,
                    onRechazar: _rechazarViajeActivo,
                    onNavegarAlPin: _abrirNavegacion,
                    isLoading: _isLoading,
                    scrollController: scrollController,
                    topInset: _sheetSize > 0.92
                        ? MediaQuery.paddingOf(context).top
                        : 0,
                    onAltoContenido: _alMedirContenido,
                  ),
                );
              },
            ),
            if (_isLoading)
              const ColoredBox(
                color: Color(0x66000000),
                child: Center(child: AppLoadingIndicator()),
              ),
          ],
        ),
      ),
    ),
    );
  }

  void _onPanelAccionPrincipal() {
    final estado = _estadoUiEfectivo;
    String? proximoEstado;
    switch (estado) {
      case 'aceptado':
      case 'en_camino':
        proximoEstado = 'llegue';
        break;
      case 'llegue':
        proximoEstado = 'en_curso';
        break;
      case 'en_curso':
        proximoEstado = 'finalizado';
        break;
    }
    if (proximoEstado != null) {
      unawaited(_cambiarEstado(proximoEstado));
    }
  }

  /// Rechazo del conductor (no cancela el viaje del pasajero).
  Future<void> _rechazarViajeActivo() async {
    if (!_canUpdateUi || _isLoading) return;

    final servicioId = widget.servicio['id'];
    if (servicioId == null) {
      _mostrarError('ID de servicio no encontrado');
      return;
    }

    final id = servicioId is int
        ? servicioId
        : int.tryParse(servicioId.toString());
    if (id == null || id <= 0) {
      _mostrarError('ID de servicio no válido');
      return;
    }

    final provider = context.read<ConductorHomeProvider>();
    final okRemoto = await provider.rechazarServicioActivo(servicioId: id);

    if (!mounted) return;

    _trackingService.detenerSeguimiento();
    await _notificacionService.cancelarNotificacion(id, tipo: 'conductor');
    await _persistencia.limpiarServicioActivo();

    if (!mounted) return;

    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        content: Text(
          okRemoto
              ? 'No te volverá a salir este servicio. Sigue disponible para otros conductores.'
              : 'Ocultado en la app. Si vuelve a aparecer, revisa tu conexión.',
        ),
        backgroundColor: Colors.orange,
      ),
    );

    await _navegarAlHomeRaiz();
  }
}
