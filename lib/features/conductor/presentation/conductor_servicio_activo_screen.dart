import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:intellitaxi/features/rides/services/servicio_tracking_service.dart';
import 'package:intellitaxi/features/pasajero/services/routes_service.dart';
import 'package:intellitaxi/features/rides/services/servicio_persistencia_service.dart';
import 'package:intellitaxi/features/rides/services/servicio_notificacion_foreground.dart';
import 'package:intellitaxi/features/conductor/providers/conductor_home_provider.dart';
import 'package:intellitaxi/features/conductor/utils/solicitud_display_helper.dart';
import 'package:intellitaxi/features/conductor/widgets/ofertas_en_ruta_panel.dart';
import 'package:intellitaxi/core/theme/app_colors.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:intellitaxi/shared/widgets/standard_map.dart';
import 'package:intellitaxi/shared/widgets/standard_button.dart';
import 'package:intellitaxi/shared/widgets/cancelacion_servicio_dialog.dart';
import 'package:intellitaxi/features/rides/widgets/calificacion_dialog.dart';
import 'package:intellitaxi/features/chat/utils/chat_helper.dart';
import 'package:intellitaxi/features/auth/providers/auth_provider.dart';
import 'package:intellitaxi/core/services/active_service_screen_registry.dart';
import 'package:intellitaxi/core/services/driver_overlay_service.dart';
import 'package:intellitaxi/config/app_config.dart';
import 'package:intellitaxi/config/pusher_config.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:dio/dio.dart';
import 'package:intellitaxi/core/services/active_service_restoration_service.dart';
import 'package:intellitaxi/core/navigation/app_root_navigation.dart';
import 'package:intellitaxi/core/services/app_logger.dart';

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
  final RoutesService _routesService = RoutesService();
  final ServicioPersistenciaService _persistencia =
      ServicioPersistenciaService();
  final ServicioNotificacionForeground _notificacionService =
      ServicioNotificacionForeground();
  final DriverOverlayService _driverOverlayService =
      DriverOverlayService.instance;
  final ActiveServiceRestorationService _restoration =
      ActiveServiceRestorationService();

  String _estadoActual = 'aceptado';
  LatLng? _miUbicacion;
  LatLng? _destinoActual;
  Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  bool _isLoading = false;
  BitmapDescriptor? _carIcon;
  StreamSubscription<Position>? _locationSubscription;
  bool _terminalNavigationInProgress = false;
  /// Evita doble flujo calificación + home (botón y Pusher).
  bool _finalizacionEnCurso = false;
  /// Evita doble `pushNamedAndRemoveUntil` (p. ej. cancel manual + evento Pusher).
  bool _homeNavigationScheduled = false;
  String? _pusherEstadoEventKey;

  void _safeSetState(VoidCallback fn) {
    if (!mounted) return;
    setState(fn);
  }

  bool get _canUpdateUi => mounted && !_terminalNavigationInProgress;

  // 📏 Control de altura del BottomSheet
  double _sheetHeight = 0.48;
  final double _minHeight = 0.36;
  final double _maxHeight = 0.72;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _requestOverlayPermissionSafely();
    _estadoActual = _resolverEstadoInicial(widget.servicio);
    ActiveServiceScreenRegistry.markVisible(
      type: 'conductor',
      serviceId: _safeServiceId(),
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

      await _guardarServicioActivo();
      _actualizarMarcadores();
      unawaited(_dibujarRuta());
    } on DioException {
      // Fallo de red: no cerrar pantalla
    } catch (e) {
      AppLogger.d('⚠️ Resume sync servicio conductor: $e');
    }
  }

  void _actualizarDestinoSegunEstado(String? ui) {
    if (ui == null) return;
    if ((ui == 'llegue' || ui == 'en_curso') && _tieneDestinoDefinido()) {
      final destinoLat = _parseDouble(widget.servicio['destino_lat']);
      final destinoLng = _parseDouble(widget.servicio['destino_lng']);
      _destinoActual = LatLng(destinoLat, destinoLng);
    } else if (ui == 'en_camino' || ui == 'aceptado') {
      final oLa = _parseDouble(widget.servicio['origen_lat']);
      final oLng = _parseDouble(widget.servicio['origen_lng']);
      if (oLa != 0 && oLng != 0) {
        _destinoActual = LatLng(oLa, oLng);
      }
    }
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

  bool _tieneDestinoDefinido() {
    final lat = _parseDouble(widget.servicio['destino_lat']);
    final lng = _parseDouble(widget.servicio['destino_lng']);
    return lat != 0.0 && lng != 0.0;
  }

  Future<String?> _resolverDireccionDesdeCoordenadas(LatLng punto) async {
    try {
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/geocode/json?'
        'latlng=${punto.latitude},${punto.longitude}'
        '&key=${AppConfig.googleMapsApiKey}'
        '&language=es',
      );
      final response = await http.get(url);
      if (response.statusCode != 200) return null;
      final data = jsonDecode(response.body);
      if (data is Map<String, dynamic> &&
          data['status'] == 'OK' &&
          data['results'] is List &&
          (data['results'] as List).isNotEmpty) {
        final first = (data['results'] as List).first;
        if (first is Map<String, dynamic>) {
          return first['formatted_address']?.toString();
        }
      }
    } catch (_) {
      // Silencioso: si falla geocoding se usa fallback.
    }
    return null;
  }

  String _resolverEstadoInicial(Map<String, dynamic> servicio) {
    final estadoRaw = servicio['estado'];
    final estadoDesdeCampo = _normalizarEstadoBackend(estadoRaw);
    if (estadoDesdeCampo != null) return estadoDesdeCampo;

    final idEstadoRaw = servicio['idEstado'] ?? servicio['id_estado'];
    final idEstado = idEstadoRaw is int
        ? idEstadoRaw
        : int.tryParse(idEstadoRaw?.toString() ?? '');

    switch (idEstado) {
      case 1:
      case 2:
        return 'aceptado';
      case 19:
        return 'en_camino';
      case 3:
      case 20:
        return 'llegue';
      case 21:
        return 'en_curso';
      case 6:
        return 'cancelado';
      case 5:
      case 7:
      case 22:
      case 23:
        return 'finalizado';
      default:
        return 'aceptado';
    }
  }

  String? _normalizarEstadoBackend(dynamic estadoRaw) {
    String? estado;
    if (estadoRaw is String) {
      estado = estadoRaw;
    } else if (estadoRaw is Map && estadoRaw['estado'] is String) {
      estado = estadoRaw['estado'] as String;
    }

    if (estado == null || estado.trim().isEmpty) return null;

    final e = estado
        .trim()
        .toLowerCase()
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('-', '_')
        .replaceAll(' ', '_');

    if (e.contains('en_curso') || e.contains('curso')) return 'en_curso';
    if (e.contains('llegue') || e.contains('llego')) return 'llegue';
    if (e.contains('en_camino') || e.contains('camino')) return 'en_camino';
    if (e.contains('acept')) return 'aceptado';
    if (e.contains('cancel')) return 'cancelado';
    if (e.contains('final') || e.contains('complet')) return 'finalizado';

    return null;
  }

  int? get _idEstadoServicio {
    final estadoObj = widget.servicio['estado'];
    final raw =
        widget.servicio['idEstado'] ??
        widget.servicio['id_estado'] ??
        (estadoObj is Map ? estadoObj['id'] : null);
    if (raw is int) return raw;
    return int.tryParse(raw?.toString() ?? '');
  }

  String? _estadoDesdeId(int? idEstado) {
    switch (idEstado) {
      case 1:
      case 2:
        return 'aceptado';
      case 19:
        return 'en_camino';
      case 3:
      case 20:
        return 'llegue';
      case 21:
        return 'en_curso';
      case 6:
        return 'cancelado';
      case 5:
      case 7:
      case 22:
      case 23:
        return 'finalizado';
      default:
        return null;
    }
  }

  String get _estadoUi {
    return _estadoDesdeId(_idEstadoServicio) ??
        _normalizarEstadoBackend(_estadoActual) ??
        _resolverEstadoInicial(widget.servicio);
  }

  String get _estadoUiEfectivo {
    return _estadoDesdeId(_idEstadoServicio) ??
        _normalizarEstadoBackend(widget.servicio['estado']) ??
        _estadoUi;
  }

  double _parseDouble(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  // Método helper para obtener el nombre del pasajero
  String _getNombrePasajero() {
    // Intentar obtener de diferentes campos posibles
    if (widget.servicio['pasajero_nombre'] != null) {
      return widget.servicio['pasajero_nombre'];
    }

    // Buscar en usuario_pasajero.persona
    if (widget.servicio['usuario_pasajero'] != null) {
      final usuarioPasajero = widget.servicio['usuario_pasajero'];
      if (usuarioPasajero is Map && usuarioPasajero['persona'] != null) {
        final persona = usuarioPasajero['persona'];
        if (persona is Map) {
          final nombre1 = persona['nombre1'] ?? '';
          final nombre2 = persona['nombre2'] ?? '';
          final apellido1 = persona['apellido1'] ?? '';
          final apellido2 = persona['apellido2'] ?? '';

          final nombreCompleto =
              '$nombre1 ${nombre2.isEmpty ? '' : nombre2} $apellido1 ${apellido2.isEmpty ? '' : apellido2}'
                  .trim();
          if (nombreCompleto.isNotEmpty) {
            return nombreCompleto;
          }
        }
      }
    }

    // Si hay un objeto pasajero anidado
    if (widget.servicio['pasajero'] != null) {
      final pasajero = widget.servicio['pasajero'];
      if (pasajero is Map) {
        return pasajero['nombre'] ?? pasajero['name'] ?? 'Pasajero';
      }
    }

    return 'Pasajero';
  }

  // Método helper para obtener el teléfono del pasajero
  String? _getTelefonoPasajero() {
    // Buscar en usuario_pasajero.persona
    if (widget.servicio['usuario_pasajero'] != null) {
      final usuarioPasajero = widget.servicio['usuario_pasajero'];
      if (usuarioPasajero is Map && usuarioPasajero['persona'] != null) {
        final persona = usuarioPasajero['persona'];
        if (persona is Map) {
          final celular = persona['celular'];
          if (celular != null && celular.toString().isNotEmpty) {
            return celular.toString();
          }
        }
      }
    }

    // Intentar obtener de diferentes campos posibles
    if (widget.servicio['pasajero_telefono'] != null) {
      return widget.servicio['pasajero_telefono'];
    }

    // Si hay un objeto pasajero anidado
    if (widget.servicio['pasajero'] != null) {
      final pasajero = widget.servicio['pasajero'];
      if (pasajero is Map) {
        return pasajero['telefono'] ?? pasajero['phone'] ?? pasajero['celular'];
      }
    }

    return null;
  }

  // Método helper para obtener la foto del pasajero
  String? _getFotoPasajero() {
    // Buscar en usuario_pasajero.persona
    if (widget.servicio['usuario_pasajero'] != null) {
      final usuarioPasajero = widget.servicio['usuario_pasajero'];
      if (usuarioPasajero is Map && usuarioPasajero['persona'] != null) {
        final persona = usuarioPasajero['persona'];
        if (persona is Map) {
          final fotoRaw =
              persona['rutaFotoUrl'] ?? persona['rutaFoto'] ?? persona['foto'];
          final foto = _resolverFotoUrl(fotoRaw?.toString());
          if (foto != null) {
            return foto;
          }
        }
      }
    }

    // Fallbacks en el servicio
    final fotoServicio = _resolverFotoUrl(
      widget.servicio['pasajero_foto']?.toString(),
    );
    if (fotoServicio != null) return fotoServicio;

    final pasajero = widget.servicio['pasajero'];
    if (pasajero is Map) {
      final fotoPasajero = _resolverFotoUrl(
        pasajero['rutaFotoUrl']?.toString() ??
            pasajero['rutaFoto']?.toString() ??
            pasajero['foto']?.toString(),
      );
      if (fotoPasajero != null) return fotoPasajero;
    }

    return null;
  }

  String? _resolverFotoUrl(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final foto = value.trim();
    if (foto.startsWith('http://') || foto.startsWith('https://')) return foto;

    final base = Uri.parse(AppConfig.baseUrl);
    final origin =
        '${base.scheme}://${base.host}${base.hasPort ? ':${base.port}' : ''}';
    if (foto.startsWith('/')) return '$origin$foto';
    return '$origin/$foto';
  }

  Future<void> _cargarIconoCarro() async {
    try {
      _carIcon = await BitmapDescriptor.asset(
        const ImageConfiguration(size: Size(48, 48)),
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

    // Destino inicial según estado restaurado.
    final origenLat = _parseDouble(widget.servicio['origen_lat']);
    final origenLng = _parseDouble(widget.servicio['origen_lng']);
    final destinoLat = _parseDouble(widget.servicio['destino_lat']);
    final destinoLng = _parseDouble(widget.servicio['destino_lng']);

    final tieneDestino = _tieneDestinoDefinido();
    _safeSetState(() {
      if (_estadoUiEfectivo == 'en_curso' && tieneDestino) {
        _destinoActual = LatLng(destinoLat, destinoLng);
      } else {
        _destinoActual = LatLng(origenLat, origenLng);
      }
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
    final channelName = 'servicio.${_safeServiceId()}';
    final eventKey = '$channelName:servicio.estado.cambiado';
    _pusherEstadoEventKey = eventKey;

    PusherService.registerEventHandlerSecondary(eventKey, (event) {
      if (!_canUpdateUi) return;
      _manejarEventoEstadoServicio(event);
    });

    await PusherService.subscribeSecondary(channelName);
  }

  void _desuscribirEventosServicio() {
    final eventKey = _pusherEstadoEventKey;
    if (eventKey != null) {
      PusherService.unregisterEventHandlerSecondary(eventKey);
      _pusherEstadoEventKey = null;
    }
    final channelName = 'servicio.${_safeServiceId()}';
    PusherService.unsubscribeSecondary(channelName);
  }

  void _manejarEventoEstadoServicio(dynamic event) {
    try {
      Map<String, dynamic> data = event is String
          ? Map<String, dynamic>.from(jsonDecode(event))
          : Map<String, dynamic>.from(event as Map);
      if (data['data'] is Map) {
        data = Map<String, dynamic>.from(data['data'] as Map);
      }

      final estadoNombre = data['estado']?.toString();
      final estadoIdRaw = data['estado_id'];
      final estadoId = estadoIdRaw is int
          ? estadoIdRaw
          : int.tryParse(estadoIdRaw?.toString() ?? '');

      if (!mounted || _terminalNavigationInProgress) return;

      if (estadoId != null) {
        widget.servicio['idEstado'] = estadoId;
      }
      if (estadoNombre != null && estadoNombre.isNotEmpty) {
        widget.servicio['estado'] = estadoNombre;
      }

      final estadoUi =
          _normalizarEstadoBackend(estadoNombre) ?? _estadoDesdeId(estadoId);

      if (estadoUi == 'cancelado' || estadoId == 6) {
        _terminalNavigationInProgress = true;
        unawaited(_salirPorServicioCancelado());
        return;
      }

      if (estadoUi == 'finalizado' || estadoId == 22) {
        unawaited(_programarFinalizacionViaje());
        return;
      }

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
    } catch (e) {
      AppLogger.d('⚠️ Error procesando servicio.estado.cambiado: $e');
    }
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
      final position = await Geolocator.getCurrentPosition();

      // Verificar que el widget siga montado antes de llamar setState
      if (!mounted) return;

      _safeSetState(() {
        _miUbicacion = LatLng(position.latitude, position.longitude);
      });

      // Actualizar marcadores y ruta
      _actualizarMarcadores();
      _dibujarRuta();

      // Centrar cámara
      _mapController?.animateCamera(CameraUpdate.newLatLng(_miUbicacion!));

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
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 10,
          ),
        ).listen((position) {
          if (!_canUpdateUi) return;

          _safeSetState(() {
            _miUbicacion = LatLng(position.latitude, position.longitude);
          });

          _actualizarMarcadores();

          // Redibujar ruta máximo cada 30 segundos para no abusar de la API
          final ahora = DateTime.now();
          if (ahora.difference(_ultimoRedibujoRuta).inSeconds >= 30) {
            _ultimoRedibujoRuta = ahora;
            _dibujarRuta();
          }

          // Seguir al conductor en el mapa
          _mapController?.animateCamera(CameraUpdate.newLatLng(_miUbicacion!));
        });
  }

  BitmapDescriptor? _recogidaDot;
  BitmapDescriptor? _destinoFinalDot;

  Future<void> _crearDotMarkers() async {
    const double s = 28;

    Future<BitmapDescriptor> crearDot(Color color) async {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.drawCircle(
        Offset(s / 2, s / 2 + 1),
        s / 3,
        Paint()
          ..color = color.withValues(alpha: 0.3)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );
      canvas.drawCircle(
        Offset(s / 2, s / 2),
        s / 3,
        Paint()..color = Colors.white,
      );
      canvas.drawCircle(Offset(s / 2, s / 2), s / 4, Paint()..color = color);
      final picture = recorder.endRecording();
      final image = await picture.toImage(s.toInt(), s.toInt());
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      return BitmapDescriptor.bytes(bytes!.buffer.asUint8List());
    }

    _recogidaDot = await crearDot(Colors.blue);
    _destinoFinalDot = await crearDot(const Color(0xFFFF6B35));
  }

  void _actualizarMarcadores() {
    if (!_canUpdateUi) return;
    final origenLat = _parseDouble(widget.servicio['origen_lat']);
    final origenLng = _parseDouble(widget.servicio['origen_lng']);
    final destinoLat = _parseDouble(widget.servicio['destino_lat']);
    final destinoLng = _parseDouble(widget.servicio['destino_lng']);

    _safeSetState(() {
      _markers = {};

      // Punto de recogida (siempre visible)
      _markers.add(
        Marker(
          markerId: const MarkerId('recogida'),
          position: LatLng(origenLat, origenLng),
          icon: _recogidaDot ?? BitmapDescriptor.defaultMarker,
          infoWindow: InfoWindow(
            title: 'Punto de Recogida',
            snippet: widget.servicio['origen_address'],
          ),
          anchor: const Offset(0.5, 0.5),
        ),
      );

      // Destino final (solo si existe destino definido)
      if (_tieneDestinoDefinido()) {
        _markers.add(
          Marker(
            markerId: const MarkerId('destino_final'),
            position: LatLng(destinoLat, destinoLng),
            icon: _destinoFinalDot ?? BitmapDescriptor.defaultMarker,
            infoWindow: InfoWindow(
              title: 'Destino Final',
              snippet:
                  widget.servicio['destino_address'] ?? 'Destino no definido',
            ),
            anchor: const Offset(0.5, 0.5),
          ),
        );
      }

      // Mi ubicación (conductor) con icono del carro
      if (_miUbicacion != null) {
        _markers.add(
          Marker(
            markerId: const MarkerId('mi_ubicacion'),
            position: _miUbicacion!,
            icon:
                _carIcon ??
                BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
            infoWindow: const InfoWindow(title: 'Mi ubicación'),
            anchor: const Offset(0.5, 0.5),
          ),
        );
      }
    });
  }

  Future<void> _dibujarRuta() async {
    if (_miUbicacion == null || _destinoActual == null) return;

    final color = _estadoUiEfectivo == 'en_curso' ? Colors.green : Colors.blue;

    try {
      final routeInfo = await _routesService.getRoute(
        origin: _miUbicacion!,
        destination: _destinoActual!,
      );

      if (!mounted) return;

      if (routeInfo != null && routeInfo.polylinePoints.isNotEmpty) {
        _safeSetState(() {
          _polylines.clear();
          _polylines.add(
            Polyline(
              polylineId: const PolylineId('ruta_actual'),
              points: routeInfo.polylinePoints,
              color: color,
              width: 5,
            ),
          );
        });
        AppLogger.d(
          '✅ Ruta dibujada: ${routeInfo.distance} - ${routeInfo.duration}',
        );
      } else {
        // Si la API no devuelve ruta, conservar la última polilínea válida.
        AppLogger.d(
          '⚠️ No se recibió polilínea válida; se conserva la ruta anterior',
        );
      }
    } catch (e) {
      AppLogger.d('❌ Error dibujando ruta: $e');
      // En caso de error temporal, conservar la última polilínea válida.
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
          widget.servicio['destino_lat'] = destinoFinalLat;
          widget.servicio['destino_lng'] = destinoFinalLng;
          widget.servicio['destino_address'] =
              destinoFinalAddress ?? widget.servicio['destino_address'];
        }
        await _programarFinalizacionViaje();
        return;
      }

      if (!_canUpdateUi) return;
      _safeSetState(() {
        _estadoActual = nuevoEstado;
        if (nuevoEstado == 'llegue') {
          widget.servicio['idEstado'] = 20;
        } else if (nuevoEstado == 'en_camino') {
          widget.servicio['idEstado'] = 19;
        } else if (nuevoEstado == 'en_curso') {
          widget.servicio['idEstado'] = 21;
        }

        // Si llegó al punto de recogida, cambiar destino al final
        if (nuevoEstado == 'llegue' && _tieneDestinoDefinido()) {
          final destinoLat = _parseDouble(widget.servicio['destino_lat']);
          final destinoLng = _parseDouble(widget.servicio['destino_lng']);
          _destinoActual = LatLng(destinoLat, destinoLng);
        } else if (nuevoEstado == 'en_curso' && _tieneDestinoDefinido()) {
          final destinoLat = _parseDouble(widget.servicio['destino_lat']);
          final destinoLng = _parseDouble(widget.servicio['destino_lng']);
          _destinoActual = LatLng(destinoLat, destinoLng);
        } else if (nuevoEstado == 'en_camino') {
          final oLa = _parseDouble(widget.servicio['origen_lat']);
          final oLng = _parseDouble(widget.servicio['origen_lng']);
          if (oLa != 0 && oLng != 0) {
            _destinoActual = LatLng(oLa, oLng);
          }
        }
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

  String _getMensajeEstado(String estado) {
    switch (estado) {
      case 'en_camino':
        return 'En camino al punto de recogida';
      case 'llegue':
        return '¡Has llegado! Esperando al pasajero';
      case 'en_curso':
        return 'Viaje iniciado';
      case 'finalizado':
        return '¡Viaje finalizado exitosamente!';
      default:
        return 'Estado actualizado';
    }
  }

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
    final telefono = _getTelefonoPasajero();
    if (telefono == null || telefono.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No hay teléfono disponible'),
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
    context.read<ConductorHomeProvider>().rechazarSolicitud(solicitudId);
  }

  Future<void> _llamarOfertaEnRuta(Map<String, dynamic> solicitud) async {
    String? telefono;
    for (final key in const [
      'pasajero_telefono',
      'telefono_pasajero',
      'telefono',
    ]) {
      final v = solicitud[key]?.toString().trim();
      if (v != null && v.isNotEmpty) {
        telefono = v;
        break;
      }
    }
    final pasajero = solicitud['pasajero'];
    if (telefono == null && pasajero is Map) {
      for (final key in const ['telefono', 'phone', 'celular']) {
        final v = pasajero[key]?.toString().trim();
        if (v != null && v.isNotEmpty) {
          telefono = v;
          break;
        }
      }
    }

    if (telefono == null || telefono.isEmpty) {
      _mostrarError('Este pasajero no tiene teléfono en la oferta');
      return;
    }

    final limpio = telefono.replaceAll(RegExp(r'[^0-9+]'), '');
    final telUri = Uri.parse('tel:$limpio');
    if (await canLaunchUrl(telUri)) {
      await launchUrl(telUri, mode: LaunchMode.externalApplication);
    } else if (mounted) {
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

  @override
  Widget build(BuildContext context) {
    final puntoRuta = _puntoReferenciaRuta();

    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Servicio en Curso'),
          automaticallyImplyLeading: false,
          actions: [
            // Botón de navegación (Waze / Google Maps)
            IconButton(
              onPressed: _abrirNavegacion,
              icon: const Icon(Iconsax.routing_2_copy),
              tooltip: 'Navegar',
            ),
          ],
        ),
        body: Stack(
          children: [
            // Mapa
            if (_miUbicacion != null && _destinoActual != null)
              StandardMap(
                initialPosition: _miUbicacion!,
                zoom: 15,
                markers: _markers,
                polylines: _polylines,
                onMapCreated: (controller) {
                  _mapController = controller;
                },
              )
            else
              const Center(child: CircularProgressIndicator()),

            if (puntoRuta != null)
              Positioned(
                top: 8,
                left: 12,
                right: 12,
                child: SafeArea(
                  bottom: false,
                  child: OfertasEnRutaPanel(
                    haciaLat: puntoRuta.latitude,
                    haciaLng: puntoRuta.longitude,
                    excluirServicioId: _servicioActivoId,
                    onAceptar: _aceptarOfertaEnRuta,
                    onRechazar: _rechazarOfertaEnRuta,
                    onLlamar: _llamarOfertaEnRuta,
                  ),
                ),
              ),

            // Panel de información y botones (draggable)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: GestureDetector(
                onVerticalDragUpdate: (details) {
                  if (!_canUpdateUi) return;
                  _safeSetState(() {
                    final screenHeight = MediaQuery.of(context).size.height;
                    final delta = -details.primaryDelta! / screenHeight;
                    _sheetHeight = (_sheetHeight + delta).clamp(
                      _minHeight,
                      _maxHeight,
                    );
                  });
                },
                onVerticalDragEnd: (details) {
                  if (!_canUpdateUi) return;
                  final velocity = details.primaryVelocity ?? 0;
                  if (velocity.abs() > 500) {
                    _safeSetState(() {
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
                  height: MediaQuery.of(context).size.height * _sheetHeight,
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
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
                          if (!_canUpdateUi) return;
                          _safeSetState(() {
                            _sheetHeight = _sheetHeight < 0.5
                                ? 0.55
                                : _minHeight;
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

                      // Contenido + acciones fijas abajo (rápido al volante)
                      Expanded(
                        child: Column(
                          children: [
                            Expanded(
                              child: SingleChildScrollView(
                                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    _buildBarraPasajeroCompacta(),
                                    const SizedBox(height: 12),
                                    _buildRutaUnificada(),
                                  ],
                                ),
                              ),
                            ),
                            Padding(
                              padding: EdgeInsets.fromLTRB(
                                16,
                                4,
                                16,
                                12 + MediaQuery.paddingOf(context).bottom,
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _buildBotonAccion(),
                                  if (_estadoUiEfectivo != 'en_curso' &&
                                      _estadoUiEfectivo != 'finalizado' &&
                                      _estadoUiEfectivo != 'cancelado') ...[
                                    const SizedBox(height: 8),
                                    _buildBotonCancelarCompacto(),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Loading overlay
            if (_isLoading)
              Container(
                color: Colors.black54,
                child: const Center(child: CircularProgressIndicator()),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBarraPasajeroCompacta() {
    final fotoUrl = _getFotoPasajero();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      children: [
        if (fotoUrl != null && fotoUrl.isNotEmpty)
          CircleAvatar(
            radius: 22,
            backgroundImage: NetworkImage(fotoUrl),
            onBackgroundImageError: (_, _) {},
          )
        else
          CircleAvatar(
            radius: 22,
            backgroundColor: AppColors.primary,
            child: const Icon(Icons.person, color: Colors.white, size: 24),
          ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            _getNombrePasajero(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
        ),
        _buildAccionRapida(
          icon: Iconsax.call,
          color: AppColors.green,
          onTap: _llamarPasajero,
          tooltip: 'Llamar',
        ),
        const SizedBox(width: 6),
        _buildAccionRapida(
          icon: Iconsax.messages_copy,
          color: AppColors.accent,
          onTap: _abrirChatPasajero,
          tooltip: 'Mensaje',
        ),
      ],
    );
  }

  Widget _buildAccionRapida({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    required String tooltip,
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
            padding: const EdgeInsets.all(10),
            child: Icon(icon, color: color, size: 24),
          ),
        ),
      ),
    );
  }

  Widget _buildRutaUnificada() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final enCurso = _estadoUiEfectivo == 'en_curso';
    final llegue = _estadoUiEfectivo == 'llegue';
    final soloDestino = enCurso || llegue;
    final recogidaActiva = !soloDestino;

    final etiqueta = enCurso
        ? 'VIAJE EN CURSO'
        : (llegue ? 'ESPERANDO PASAJERO' : 'IR A RECOGIDA');

    final nombreRecogida = SolicitudDisplayHelper.pickupName(widget.servicio);
    final nombreDestino =
        SolicitudDisplayHelper.destinationName(widget.servicio);
    final subtituloRecogida =
        SolicitudDisplayHelper.pickupSubtitle(widget.servicio);
    final subtituloDestino =
        SolicitudDisplayHelper.destinationSubtitle(widget.servicio);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.06)
            : Colors.black.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: (soloDestino ? AppColors.green : AppColors.accent)
              .withValues(alpha: 0.35),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: soloDestino ? AppColors.green : AppColors.accent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              etiqueta,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.6,
              ),
            ),
          ),
          const SizedBox(height: 14),
          if (!soloDestino) ...[
            _buildParadaRuta(
              icon: Iconsax.location_add,
              label: 'RECOGIDA',
              nombre: nombreRecogida,
              subtitulo: subtituloRecogida,
              color: AppColors.accent,
              activa: recogidaActiva,
              isDark: isDark,
            ),
            Padding(
              padding: const EdgeInsets.only(left: 11, top: 6, bottom: 6),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  width: 2,
                  height: 18,
                  color: Colors.grey.withValues(alpha: 0.35),
                ),
              ),
            ),
            _buildParadaRuta(
              icon: Iconsax.location,
              label: 'DESTINO',
              nombre: nombreDestino,
              subtitulo: subtituloDestino,
              color: AppColors.green,
              activa: false,
              resaltada: true,
              isDark: isDark,
            ),
          ] else
            _buildParadaRuta(
              icon: Iconsax.location,
              label: 'DESTINO',
              nombre: nombreDestino,
              subtitulo: subtituloDestino,
              color: AppColors.green,
              activa: true,
              isDark: isDark,
            ),
        ],
      ),
    );
  }

  Widget _buildParadaRuta({
    required IconData icon,
    required String label,
    required String nombre,
    required String subtitulo,
    required Color color,
    required bool activa,
    required bool isDark,
    bool resaltada = false,
  }) {
    final mostrarGrande = activa;
    final bordeVisible = activa || resaltada;

    return Container(
      padding: EdgeInsets.all(bordeVisible ? 12 : 0),
      decoration: bordeVisible
          ? BoxDecoration(
              color: color.withValues(alpha: isDark ? 0.14 : 0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: color.withValues(alpha: activa ? 0.55 : 0.35),
                width: activa ? 2 : 1.2,
              ),
            )
          : null,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: mostrarGrande ? 22 : 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: color,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  nombre,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: mostrarGrande ? 28 : 16,
                    fontWeight: mostrarGrande ? FontWeight.w900 : FontWeight.w700,
                    height: 1.12,
                    color: activa
                        ? (isDark ? Colors.white : Colors.black87)
                        : (isDark ? Colors.grey.shade400 : Colors.grey.shade700),
                  ),
                ),
                if (subtitulo.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitulo,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: mostrarGrande ? 14 : 12,
                      fontWeight: FontWeight.w500,
                      height: 1.25,
                      color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBotonCancelarCompacto() {
    return TextButton.icon(
      onPressed: _mostrarDialogoCancelacion,
      icon: Icon(Iconsax.close_circle, color: Colors.red.shade600, size: 20),
      label: Text(
        'Cancelar servicio',
        style: TextStyle(
          color: Colors.red.shade600,
          fontWeight: FontWeight.w700,
          fontSize: 14,
        ),
      ),
    );
  }

  Widget _buildBotonAccion() {
    final estado = _estadoUiEfectivo;
    String texto;
    String proximoEstado;
    IconData icono;

    switch (estado) {
      case 'aceptado':
      case 'en_camino':
        texto = 'LLEGUÉ AL PUNTO DE RECOGIDA';
        proximoEstado = 'llegue';
        icono = Iconsax.tick_circle;
        break;
      case 'llegue':
        texto = 'INICIAR VIAJE';
        proximoEstado = 'en_curso';
        icono = Iconsax.play_circle;
        break;
      case 'en_curso':
        texto = 'FINALIZAR VIAJE';
        proximoEstado = 'finalizado';
        icono = Iconsax.flag;
        break;
      default:
        return const SizedBox();
    }

    return StandardButton(
      text: texto,
      icon: icono,
      onPressed: () => _cambiarEstado(proximoEstado),
      isLoading: _isLoading,
      width: double.infinity,
      height: 60,
    );
  }

  Future<void> _mostrarDialogoCancelacion() async {
    final resultado = await CancelacionServicioDialog.mostrar(
      context,
      tipoUsuario: 'conductor',
    );

    if (resultado != null && resultado.isNotEmpty) {
      await _cancelarServicio(resultado);
    }
  }

  Future<void> _cancelarServicio(String motivo) async {
    if (!_canUpdateUi) return;
    _safeSetState(() => _isLoading = true);

    try {
      // Obtener el servicio ID
      final servicioId = widget.servicio['id'];
      if (servicioId == null) {
        throw Exception('ID de servicio no encontrado');
      }

      // Verificar que el context siga montado
      if (!mounted) return;

      // Llamar al servicio de cancelación a través del provider
      final provider = context.read<ConductorHomeProvider>();

      final exitoso = await provider.cancelarServicio(
        servicioId: servicioId is int
            ? servicioId
            : int.parse(servicioId.toString()),
        motivo: motivo,
      );

      if (exitoso) {
        // Quitar overlay de “cancelando” antes de awaits largos para no dejar UI negra.
        if (_canUpdateUi) {
          _safeSetState(() => _isLoading = false);
        }

        // Detener tracking
        _trackingService.detenerSeguimiento();

        // Cancelar notificación
        await _notificacionService.cancelarNotificacion(
          servicioId,
          tipo: 'conductor',
        );

        // Limpiar persistencia
        await _persistencia.limpiarServicioActivo();

        if (!mounted) return;

        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          const SnackBar(
            content: Text('Servicio cancelado exitosamente'),
            backgroundColor: AppColors.green,
          ),
        );

        await _navegarAlHomeRaiz();
      } else {
        throw Exception('No se pudo cancelar el servicio');
      }
    } catch (e) {
      if (!mounted) return;
      _mostrarError('Error al cancelar: ${e.toString()}');
    } finally {
      // Siempre bajar loading si sigue activo (evita overlay negro si la navegación falla o queda a medias).
      if (_canUpdateUi && _isLoading) {
        _safeSetState(() => _isLoading = false);
      }
    }
  }
}
