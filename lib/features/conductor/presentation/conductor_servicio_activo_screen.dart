import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:intellitaxi/features/rides/services/servicio_tracking_service.dart';
import 'package:intellitaxi/features/rides/services/routes_service.dart';
import 'package:intellitaxi/features/rides/services/servicio_persistencia_service.dart';
import 'package:intellitaxi/features/rides/services/servicio_notificacion_foreground.dart';
import 'package:intellitaxi/features/conductor/providers/conductor_home_provider.dart';
import 'package:intellitaxi/core/theme/app_colors.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:intellitaxi/shared/widgets/standard_map.dart';
import 'package:intellitaxi/shared/widgets/standard_button.dart';
import 'package:intellitaxi/shared/widgets/cancelacion_servicio_dialog.dart';
import 'package:intellitaxi/features/rides/widgets/calificacion_dialog.dart';
import 'package:intellitaxi/features/chat/utils/chat_helper.dart';
import 'package:intellitaxi/features/auth/logic/auth_provider.dart';
import 'package:intellitaxi/core/services/active_service_screen_registry.dart';
import 'package:intellitaxi/core/services/driver_overlay_service.dart';
import 'package:url_launcher/url_launcher.dart';
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

  String _estadoActual = 'aceptado';
  LatLng? _miUbicacion;
  LatLng? _destinoActual;
  Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  bool _isLoading = false;
  BitmapDescriptor? _carIcon;
  StreamSubscription<Position>? _locationSubscription;

  // 📏 Control de altura del BottomSheet
  double _sheetHeight = 0.40;
  final double _minHeight = 0.30;
  final double _maxHeight = 0.75;

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
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _driverOverlayService.hide();
    ActiveServiceScreenRegistry.markHidden(
      type: 'conductor',
      serviceId: _safeServiceId(),
    );
    _locationSubscription?.cancel();
    _trackingService.detenerSeguimiento();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _driverOverlayService.hide();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      if (!_driverOverlayService.isRequestingPermission) {
        _driverOverlayService.show(servicioId: _safeServiceId());
      }
    }
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
      case 3:
      case 20:
        return 'llegue';
      case 4:
      case 21:
        return 'en_curso';
      case 5:
      case 6:
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
    if (e.contains('final') || e.contains('complet')) return 'finalizado';
    if (e.contains('cancel')) return 'finalizado';

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
      case 20:
        return 'aceptado';
      case 3:
        return 'llegue';
      case 4:
      case 21:
        return 'en_curso';
      case 5:
      case 6:
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
    // Buscar en usuario_pasajero.persona.rutaFotoUrl
    if (widget.servicio['usuario_pasajero'] != null) {
      final usuarioPasajero = widget.servicio['usuario_pasajero'];
      if (usuarioPasajero is Map && usuarioPasajero['persona'] != null) {
        final persona = usuarioPasajero['persona'];
        if (persona is Map) {
          final fotoUrl = persona['rutaFotoUrl'];
          if (fotoUrl != null && fotoUrl.toString().isNotEmpty) {
            return fotoUrl.toString();
          }
        }
      }
    }

    return null;
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
    await _crearDotMarkers();

    // Inicializar servicio de notificaciones
    await _notificacionService.inicializar();

    // Guardar servicio activo localmente
    await _guardarServicioActivo();

    // Mostrar notificación persistente
    await _mostrarNotificacionPersistente();

    // Iniciar seguimiento
    await _trackingService.iniciarSeguimiento(
      servicioId: widget.servicio['id'],
      conductorId: widget.conductorId,
    );

    // Destino inicial según estado restaurado.
    final origenLat = _parseDouble(widget.servicio['origen_lat']);
    final origenLng = _parseDouble(widget.servicio['origen_lng']);
    final destinoLat = _parseDouble(widget.servicio['destino_lat']);
    final destinoLng = _parseDouble(widget.servicio['destino_lng']);

    setState(() {
      _destinoActual = _estadoUiEfectivo == 'en_curso'
          ? LatLng(destinoLat, destinoLng)
          : LatLng(origenLat, origenLng);
    });

    // Obtener ubicación actual
    await _obtenerUbicacionActual();

    // Actualizar marcadores
    _actualizarMarcadores();
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

      setState(() {
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
          if (!mounted) return;

          setState(() {
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
    final origenLat = _parseDouble(widget.servicio['origen_lat']);
    final origenLng = _parseDouble(widget.servicio['origen_lng']);
    final destinoLat = _parseDouble(widget.servicio['destino_lat']);
    final destinoLng = _parseDouble(widget.servicio['destino_lng']);

    setState(() {
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

      // Destino final (siempre visible)
      _markers.add(
        Marker(
          markerId: const MarkerId('destino_final'),
          position: LatLng(destinoLat, destinoLng),
          icon: _destinoFinalDot ?? BitmapDescriptor.defaultMarker,
          infoWindow: InfoWindow(
            title: 'Destino Final',
            snippet: widget.servicio['destino_address'],
          ),
          anchor: const Offset(0.5, 0.5),
        ),
      );

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
        setState(() {
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
    setState(() => _isLoading = true);

    final success = await ServicioTrackingService.cambiarEstadoStatic(
      servicioId: widget.servicio['id'],
      conductorId: widget.conductorId,
      estado: nuevoEstado,
    );

    setState(() => _isLoading = false);

    if (success) {
      setState(() {
        _estadoActual = nuevoEstado;
        if (nuevoEstado == 'llegue') {
          widget.servicio['idEstado'] = 3;
        } else if (nuevoEstado == 'en_curso') {
          widget.servicio['idEstado'] = 21;
        } else if (nuevoEstado == 'finalizado') {
          widget.servicio['idEstado'] = 22;
        }

        // Si llegó al punto de recogida, cambiar destino al final
        if (nuevoEstado == 'llegue') {
          final destinoLat = _parseDouble(widget.servicio['destino_lat']);
          final destinoLng = _parseDouble(widget.servicio['destino_lng']);
          _destinoActual = LatLng(destinoLat, destinoLng);
        } else if (nuevoEstado == 'en_curso') {
          final destinoLat = _parseDouble(widget.servicio['destino_lat']);
          final destinoLng = _parseDouble(widget.servicio['destino_lng']);
          _destinoActual = LatLng(destinoLat, destinoLng);
        }
      });

      // Actualizar notificación persistente
      await _notificacionService.actualizarNotificacion(
        servicioId: widget.servicio['id'],
        tipo: 'conductor',
        estado: nuevoEstado,
        origen: widget.servicio['origen_address'] ?? 'Origen',
        destino: widget.servicio['destino_address'] ?? 'Destino',
      );

      _mostrarMensaje(_getMensajeEstado(nuevoEstado));
      _actualizarMarcadores();
      _dibujarRuta();

      // Si finalizó el viaje, limpiar y salir
      if (nuevoEstado == 'finalizado') {
        await Future.delayed(const Duration(seconds: 2));
        await _finalizarServicio();
      }
    } else {
      _mostrarError('No se pudo actualizar el estado');
    }
  }

  Future<void> _finalizarServicio() async {
    // Detener seguimiento
    _trackingService.detenerSeguimiento();

    // Cancelar notificación
    await _notificacionService.cancelarNotificacion(
      widget.servicio['id'],
      tipo: 'conductor',
    );

    // Limpiar persistencia
    await _persistencia.limpiarServicioActivo();

    // Mostrar diálogo de calificación del pasajero
    if (mounted) {
      await _mostrarDialogoCalificacionPasajero();
    }

    // Navegar al home (reemplazar todas las rutas)
    if (mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
    }
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
      String? fotoPasajero;

      // Intentar obtener el ID del pasajero de diferentes fuentes
      if (widget.servicio['usuario_pasajero'] != null) {
        final usuarioPasajero = widget.servicio['usuario_pasajero'];
        if (usuarioPasajero is Map) {
          pasajeroId = usuarioPasajero['id'] ?? usuarioPasajero['usuario_id'];

          // Obtener foto del pasajero
          if (usuarioPasajero['persona'] != null) {
            final persona = usuarioPasajero['persona'];
            if (persona is Map) {
              fotoPasajero = persona['foto'];
            }
          }
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
            // Botón de chat
            Builder(
              builder: (context) {
                final authProvider = Provider.of<AuthProvider>(
                  context,
                  listen: false,
                );
                final servicioId = widget.servicio['id'] is int
                    ? widget.servicio['id'] as int
                    : int.tryParse(widget.servicio['id'].toString()) ?? 0;

                return ChatHelper.botonAppBarChat(
                  context: context,
                  servicioId: servicioId,
                  miUserId: authProvider.userId ?? 0,
                );
              },
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

            // Panel de información y botones (draggable)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: GestureDetector(
                onVerticalDragUpdate: (details) {
                  setState(() {
                    final screenHeight = MediaQuery.of(context).size.height;
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
                          setState(() {
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

                      // Contenido scrolleable
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Indicador de estado
                              _buildEstadoIndicator(),

                              const SizedBox(height: 15),

                              // Información del pasajero
                              _buildInfoPasajero(),

                              const SizedBox(height: 15),

                              // Dirección actual
                              _buildDireccionActual(),

                              const SizedBox(height: 20),

                              // Botón de acción según estado
                              _buildBotonAccion(),

                              // Botón de cancelar (solo si el servicio no ha iniciado)
                              if (_estadoUiEfectivo != 'en_curso' &&
                                  _estadoUiEfectivo != 'finalizado') ...[
                                const SizedBox(height: 12),
                                _buildBotonCancelar(),
                              ],
                            ],
                          ),
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

  Widget _buildEstadoIndicator() {
    final estados = {
      'aceptado': {
        'texto': 'YENDO AL PUNTO DE RECOGIDA',
        'color': AppColors.green,
      },
      'en_camino': {
        'texto': 'YENDO AL PUNTO DE RECOGIDA',
        'color': AppColors.green,
      },
      'llegue': {'texto': 'ESPERANDO PASAJERO', 'color': AppColors.accent},
      'en_curso': {'texto': 'VIAJE EN CURSO', 'color': AppColors.green},
    };

    final info =
        estados[_estadoUiEfectivo] ??
        {'texto': 'SERVICIO ACTIVO', 'color': Colors.grey};

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: info['color'] as Color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.location_on, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Text(
            info['texto'] as String,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoPasajero() {
    final fotoUrl = _getFotoPasajero();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Avatar con foto o icono por defecto
          fotoUrl != null && fotoUrl.isNotEmpty
              ? CircleAvatar(
                  radius: 28,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                  backgroundImage: NetworkImage(fotoUrl),
                  onBackgroundImageError: (exception, stackTrace) {
                    AppLogger.d(
                      '⚠️ Error cargando foto del pasajero: $exception',
                    );
                  },
                  child: null,
                )
              : CircleAvatar(
                  radius: 28,
                  backgroundColor: AppColors.primary,
                  child: const Icon(
                    Icons.person,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _getNombrePasajero(),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Iconsax.call, color: AppColors.green, size: 28),
            onPressed: _llamarPasajero,
          ),
        ],
      ),
    );
  }

  Widget _buildDireccionActual() {
    final enCurso = _estadoUiEfectivo == 'en_curso';
    final origenName =
        widget.servicio['origen_name'] ?? widget.servicio['origenName'];
    final destinoName =
        widget.servicio['destino_name'] ?? widget.servicio['destinoName'];
    final origenAddress =
        widget.servicio['origen_address'] ?? widget.servicio['origenAddress'];
    final destinoAddress =
        widget.servicio['destino_address'] ?? widget.servicio['destinoAddress'];
    final origenPrincipal = (origenName?.toString().trim().isNotEmpty ?? false)
        ? origenName.toString()
        : (origenAddress ?? 'Sin lugar');
    final destinoPrincipal =
        (destinoName?.toString().trim().isNotEmpty ?? false)
        ? destinoName.toString()
        : (destinoAddress ?? 'Sin lugar');

    return Column(
      children: [
        // Dirección de origen (recogida)
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: enCurso
                ? Colors.grey.withValues(alpha: 0.05)
                : AppColors.accent.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: enCurso
                  ? Colors.grey.withValues(alpha: 0.2)
                  : AppColors.accent.withValues(alpha: 0.3),
              width: enCurso ? 1 : 1.5,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: enCurso
                      ? Colors.grey.withValues(alpha: 0.2)
                      : AppColors.accent.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Iconsax.location_add,
                  color: enCurso ? Colors.grey : AppColors.accent,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Punto de recogida',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: enCurso ? Colors.grey : AppColors.accent,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      origenPrincipal,
                      style: TextStyle(
                        fontSize: 13,
                        color: enCurso
                            ? Colors.grey.shade600
                            : Colors.grey.shade600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (origenAddress != null &&
                        origenAddress.toString().trim().isNotEmpty &&
                        origenAddress.toString() != origenPrincipal)
                      Text(
                        origenAddress.toString(),
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              if (enCurso)
                const Icon(
                  Iconsax.tick_circle,
                  color: AppColors.green,
                  size: 20,
                ),
            ],
          ),
        ),

        // Conector visual
        Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              const SizedBox(width: 18),
              Container(
                width: 2,
                height: 16,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      enCurso ? AppColors.green : Colors.grey.shade400,
                      enCurso ? AppColors.green : Colors.grey.shade400,
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        // Dirección de destino
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: enCurso
                ? AppColors.green.withValues(alpha: 0.1)
                : Colors.grey.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: enCurso
                  ? AppColors.green.withValues(alpha: 0.3)
                  : Colors.grey.withValues(alpha: 0.2),
              width: enCurso ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: enCurso
                      ? AppColors.green.withValues(alpha: 0.2)
                      : Colors.grey.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Iconsax.location,
                  color: enCurso ? AppColors.green : Colors.grey,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Destino final',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: enCurso ? AppColors.green : Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      destinoPrincipal,
                      style: TextStyle(
                        fontSize: 13,
                        color: enCurso
                            ? Colors.grey.shade600
                            : Colors.grey.shade600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (destinoAddress != null &&
                        destinoAddress.toString().trim().isNotEmpty &&
                        destinoAddress.toString() != destinoPrincipal)
                      Text(
                        destinoAddress.toString(),
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
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
      height: 56,
    );
  }

  Widget _buildBotonCancelar() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.red.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _mostrarDialogoCancelacion,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.red.shade50, Colors.red.shade100],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.red.shade300, width: 1.5),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Iconsax.close_circle,
                  color: Colors.red.shade700,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  'Cancelar servicio',
                  style: TextStyle(
                    color: Colors.red.shade700,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
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
    setState(() => _isLoading = true);

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

        // Mostrar mensaje de éxito
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Servicio cancelado exitosamente'),
            backgroundColor: AppColors.green,
          ),
        );

        // Volver de forma robusta al home para evitar pantalla negra
        Navigator.of(
          context,
        ).pushNamedAndRemoveUntil('/home', (route) => false);
      } else {
        throw Exception('No se pudo cancelar el servicio');
      }
    } catch (e) {
      if (!mounted) return;
      _mostrarError('Error al cancelar: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}
