import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intellitaxi/features/rides/data/servicio_activo_model.dart';
import 'package:intellitaxi/features/rides/services/servicio_persistencia_service.dart';
import 'package:intellitaxi/features/rides/services/servicio_notificacion_foreground.dart';
import 'package:intellitaxi/features/pasajero/services/ride_request_service.dart';
import 'package:intellitaxi/features/rides/services/active_service_manager.dart';

class ActiveServiceProvider extends ChangeNotifier {
  ActiveServiceProvider({
    required ServicioActivo servicio,
    this.onServiceCompleted,
    ActiveServiceManager? activeServiceManager,
  })  : _servicio = servicio,
        _activeServiceManager = activeServiceManager ?? ActiveServiceManager() {
    _initialize();
  }

  ServicioActivo _servicio;
  final VoidCallback? onServiceCompleted;
  final ActiveServiceManager _activeServiceManager;

  ServicioActivo get servicio => _servicio;

  final ServicioPersistenciaService _persistencia =
      ServicioPersistenciaService();
  final ServicioNotificacionForeground _notificacionService =
      ServicioNotificacionForeground();
  final RideRequestService _rideService = RideRequestService();

  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};

  bool _isLoading = false;
  String? _error;

  // Dot markers cacheados
  BitmapDescriptor? _origenDot;
  BitmapDescriptor? _destinoDot;
  BitmapDescriptor? _conductorDot;

  // Getters
  GoogleMapController? get mapController => _mapController;
  Set<Marker> get markers => _markers;
  Set<Polyline> get polylines => _polylines;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isServiceActive =>
      !_servicio.isFinalizado && !_servicio.isCancelado;

  // Inicialización
  Future<void> _initialize() async {
    // Crear dot markers primero
    _origenDot = await _createDotMarker(const Color(0xFF4CAF50));
    _destinoDot = await _createDotMarker(const Color(0xFFFF6B35));
    _conductorDot = await _createDotMarker(Colors.blue);

    // Inicializar mapa con dots ya listos
    _actualizarMarkers();
    await _inicializarPersistencia();
    _iniciarSeguimientoRemoto();
  }

  void _iniciarSeguimientoRemoto() {
    _activeServiceManager.onServiceUpdated = (actualizado) {
      if (actualizado.id != _servicio.id) return;
      _servicio = actualizado;
      _actualizarMarkers();
      _mostrarNotificacionPersistente();
      notifyListeners();
    };
    _activeServiceManager.onServiceCompleted = () {
      onServiceCompleted?.call();
    };
    _activeServiceManager.startPolling();
    _activeServiceManager.subscribeToServiceEvents(_servicio.id);
  }

  static Future<BitmapDescriptor> _createDotMarker(
    Color color, {
    double size = 28,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final s = size;

    // Sombra
    canvas.drawCircle(
      Offset(s / 2, s / 2 + 1),
      s / 3,
      Paint()
        ..color = color.withValues(alpha: 0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
    // Círculo exterior (borde blanco)
    canvas.drawCircle(
      Offset(s / 2, s / 2),
      s / 3,
      Paint()..color = Colors.white,
    );
    // Círculo interior (color)
    canvas.drawCircle(Offset(s / 2, s / 2), s / 4, Paint()..color = color);

    final picture = recorder.endRecording();
    final image = await picture.toImage(s.toInt(), s.toInt());
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);

    return BitmapDescriptor.bytes(bytes!.buffer.asUint8List());
  }

  void _actualizarMarkers() {
    _markers = {
      Marker(
        markerId: const MarkerId('origen'),
        position: LatLng(_servicio.origenLat, _servicio.origenLng),
        infoWindow: InfoWindow(
          title: 'Origen',
          snippet: _servicio.origenAddress,
        ),
        icon: _origenDot ?? BitmapDescriptor.defaultMarker,
        anchor: const Offset(0.5, 0.5),
      ),
      Marker(
        markerId: const MarkerId('destino'),
        position: LatLng(_servicio.destinoLat, _servicio.destinoLng),
        infoWindow: InfoWindow(
          title: 'Destino',
          snippet: _servicio.destinoAddress,
        ),
        icon: _destinoDot ?? BitmapDescriptor.defaultMarker,
        anchor: const Offset(0.5, 0.5),
      ),
    };

    if (_servicio.conductor != null &&
        _servicio.conductor!.lat != null &&
        _servicio.conductor!.lng != null) {
      _markers.add(
        Marker(
          markerId: const MarkerId('conductor'),
          position: LatLng(
            _servicio.conductor!.lat!,
            _servicio.conductor!.lng!,
          ),
          infoWindow: InfoWindow(
            title: _servicio.conductor!.nombre,
            snippet: 'Conductor',
          ),
          icon: _conductorDot ?? BitmapDescriptor.defaultMarker,
          anchor: const Offset(0.5, 0.5),
        ),
      );
    }
    notifyListeners();
  }

  Future<void> _inicializarPersistencia() async {
    try {
      // Inicializar notificaciones
      await _notificacionService.inicializar();

      // Guardar servicio activo localmente
      await _guardarServicioActivo();

      // Mostrar notificación persistente
      await _mostrarNotificacionPersistente();
    } catch (e) {
      _error = 'Error al inicializar persistencia: $e';
      notifyListeners();
    }
  }

  Future<void> _guardarServicioActivo() async {
    await _persistencia.guardarServicioActivo(
      servicioId: _servicio.id,
      tipo: 'pasajero',
      datosServicio: _servicio.toJson(),
    );
  }

  Future<void> _mostrarNotificacionPersistente() async {
    await _notificacionService.mostrarNotificacionPasajero(
      servicioId: _servicio.id,
      estado: _servicio.estado.estado,
      conductorNombre: _servicio.conductor?.nombre,
      vehiculoInfo: _servicio.vehiculo != null
          ? '${_servicio.vehiculo!.marca} ${_servicio.vehiculo!.modelo}'
          : null,
      destino: _servicio.destinoAddress,
    );
  }

  Future<void> limpiarServicio() async {
    try {
      // Cancelar notificación
      await _notificacionService.cancelarNotificacion(
        _servicio.id,
        tipo: 'pasajero',
      );

      // Limpiar persistencia
      await _persistencia.limpiarServicioActivo();
    } catch (e) {
      _error = 'Error al limpiar servicio: $e';
      notifyListeners();
    }
  }

  void setMapController(GoogleMapController controller) {
    _mapController = controller;
    notifyListeners();
  }

  Future<bool> cancelarServicio(String motivo) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      // Llamar al servicio de cancelación
      await _rideService.cancelarServicio(
        servicioId: _servicio.id,
        motivo: motivo,
      );

      // Limpiar servicio
      await limpiarServicio();

      _isLoading = false;
      notifyListeners();

      // Notificar que el servicio se completó/canceló
      onServiceCompleted?.call();

      return true;
    } catch (e) {
      _isLoading = false;
      _error = 'Error al cancelar: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }

  Color getStateColor() {
    if (_servicio.tieneConductorAsignado && _servicio.idEstado == 1) {
      return Colors.blue;
    }
    switch (_servicio.idEstado) {
      case 1:
        return const Color(0xFFFF6B35); // AppColors.accent - Pendiente
      case 2:
        return Colors.blue; // Aceptado
      case 3:
        return const Color(0xFF4CAF50); // AppColors.green - En camino
      case 4:
        return const Color(0xFF2E7D32); // AppColors.primary - Llegué
      case 5:
        return const Color(0xFF4CAF50); // AppColors.green - En curso
      case 6:
        return Colors.grey; // Finalizado
      case 7:
        return Colors.red; // Cancelado
      default:
        return Colors.grey;
    }
  }

  IconData getStateIcon() {
    // Nota: Los valores de Iconsax se mantienen en el widget
    if (_servicio.tieneConductorAsignado && _servicio.idEstado == 1) {
      return Icons.check_circle;
    }
    switch (_servicio.idEstado) {
      case 1:
        return Icons.access_time;
      case 2:
        return Icons.check_circle;
      case 3:
        return Icons.directions_car;
      case 4:
        return Icons.location_on;
      case 5:
        return Icons.route;
      case 6:
        return Icons.flag;
      case 7:
        return Icons.cancel;
      default:
        return Icons.info;
    }
  }

  String getStateMessage() => _servicio.mensajeEstadoPasajero;

  @override
  void dispose() {
    _activeServiceManager.onServiceUpdated = null;
    _activeServiceManager.onServiceCompleted = null;
    _activeServiceManager.cleanup();
    // Si el servicio está finalizado, limpiar
    if (_servicio.isFinalizado || _servicio.isCancelado) {
      limpiarServicio();
    }
    _mapController?.dispose();
    super.dispose();
  }
}
