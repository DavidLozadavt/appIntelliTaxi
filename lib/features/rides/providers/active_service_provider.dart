import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intellitaxi/features/rides/data/servicio_activo_model.dart';
import 'package:intellitaxi/features/rides/services/servicio_persistencia_service.dart';
import 'package:intellitaxi/features/rides/services/servicio_notificacion_foreground.dart';
import 'package:intellitaxi/features/rides/services/ride_request_service.dart';

class ActiveServiceProvider extends ChangeNotifier {
  final ServicioActivo servicio;
  final VoidCallback? onServiceCompleted;

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

  ActiveServiceProvider({required this.servicio, this.onServiceCompleted}) {
    _initialize();
  }

  // Getters
  GoogleMapController? get mapController => _mapController;
  Set<Marker> get markers => _markers;
  Set<Polyline> get polylines => _polylines;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isServiceActive => !servicio.isFinalizado && !servicio.isCancelado;

  // Inicialización
  Future<void> _initialize() async {
    _initializeMap();
    await _inicializarPersistencia();
  }

  void _initializeMap() {
    _markers = {
      // Marcador de origen
      Marker(
        markerId: const MarkerId('origen'),
        position: LatLng(servicio.origenLat, servicio.origenLng),
        infoWindow: InfoWindow(
          title: 'Origen',
          snippet: servicio.origenAddress,
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
      ),
      // Marcador de destino
      Marker(
        markerId: const MarkerId('destino'),
        position: LatLng(servicio.destinoLat, servicio.destinoLng),
        infoWindow: InfoWindow(
          title: 'Destino',
          snippet: servicio.destinoAddress,
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      ),
    };

    // Si hay conductor, agregar su marcador
    if (servicio.conductor != null &&
        servicio.conductor!.lat != null &&
        servicio.conductor!.lng != null) {
      _markers.add(
        Marker(
          markerId: const MarkerId('conductor'),
          position: LatLng(servicio.conductor!.lat!, servicio.conductor!.lng!),
          infoWindow: InfoWindow(
            title: servicio.conductor!.nombre,
            snippet: 'Conductor',
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
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
      servicioId: servicio.id,
      tipo: 'pasajero',
      datosServicio: servicio.toJson(),
    );
  }

  Future<void> _mostrarNotificacionPersistente() async {
    await _notificacionService.mostrarNotificacionPasajero(
      servicioId: servicio.id,
      estado: servicio.estado.estado,
      conductorNombre: servicio.conductor?.nombre,
      vehiculoInfo: servicio.vehiculo != null
          ? '${servicio.vehiculo!.marca} ${servicio.vehiculo!.modelo}'
          : null,
      destino: servicio.destinoAddress,
    );
  }

  Future<void> limpiarServicio() async {
    try {
      // Cancelar notificación
      await _notificacionService.cancelarNotificacion(
        servicio.id,
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
        servicioId: servicio.id,
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
    switch (servicio.idEstado) {
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
    switch (servicio.idEstado) {
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

  String getStateMessage() {
    switch (servicio.idEstado) {
      case 1:
        return 'Buscando conductor disponible...';
      case 2:
        return 'Conductor asignado';
      case 3:
        return 'El conductor va hacia ti';
      case 4:
        return 'El conductor ha llegado';
      case 5:
        return 'Viaje en progreso';
      case 6:
        return 'Viaje completado';
      case 7:
        return 'Viaje cancelado';
      default:
        return '';
    }
  }

  @override
  void dispose() {
    // Si el servicio está finalizado, limpiar
    if (servicio.isFinalizado || servicio.isCancelado) {
      limpiarServicio();
    }
    _mapController?.dispose();
    super.dispose();
  }
}
