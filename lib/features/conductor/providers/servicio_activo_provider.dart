import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intellitaxi/features/rides/services/servicio_tracking_service.dart';
import 'package:intellitaxi/features/rides/services/routes_service.dart';

/// Provider para gestionar la lógica del servicio activo del conductor
/// Incluye: tracking GPS, cambio de estados, manejo de marcadores y rutas
class ServicioActivoProvider extends ChangeNotifier {
  final ServicioTrackingService _trackingService = ServicioTrackingService();
  final RoutesService _routesService = RoutesService();

  // Datos del servicio
  Map<String, dynamic>? _servicioData;
  int? _conductorId;

  // Estado del servicio
  String _estadoActual = 'aceptado';
  bool _isLoading = false;

  // Ubicación y mapa
  LatLng? _miUbicacion;
  LatLng? _destinoActual;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  BitmapDescriptor? _carIcon;

  // Getters
  Map<String, dynamic>? get servicioData => _servicioData;
  String get estadoActual => _estadoActual;
  bool get isLoading => _isLoading;
  LatLng? get miUbicacion => _miUbicacion;
  LatLng? get destinoActual => _destinoActual;
  Set<Marker> get markers => _markers;
  Set<Polyline> get polylines => _polylines;

  /// Inicializa el provider con los datos del servicio
  Future<void> inicializar({
    required Map<String, dynamic> servicio,
    required int conductorId,
  }) async {
    _servicioData = servicio;
    _conductorId = conductorId;
    _estadoActual = 'aceptado';

    await _cargarIconoCarro();
    await _inicializarUbicacion();
    await _iniciarTracking();
  }

  @override
  void dispose() {
    _trackingService.detenerSeguimiento();
    super.dispose();
  }

  // ==================== PARSEO DE DATOS ====================

  double _parseDouble(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  /// Obtiene el nombre del pasajero desde los datos del servicio
  String getNombrePasajero() {
    if (_servicioData == null) return 'Pasajero';

    if (_servicioData!['pasajero_nombre'] != null) {
      return _servicioData!['pasajero_nombre'];
    }

    if (_servicioData!['usuario_pasajero'] != null) {
      final usuarioPasajero = _servicioData!['usuario_pasajero'];
      if (usuarioPasajero is Map && usuarioPasajero['persona'] != null) {
        final persona = usuarioPasajero['persona'];
        if (persona is Map) {
          final nombre1 = persona['nombre1'] ?? '';
          final nombre2 = persona['nombre2'] ?? '';
          final apellido1 = persona['apellido1'] ?? '';
          final apellido2 = persona['apellido2'] ?? '';

          final nombreCompleto = '$nombre1 ${nombre2.isEmpty ? '' : nombre2} $apellido1 ${apellido2.isEmpty ? '' : apellido2}'.trim();
          if (nombreCompleto.isNotEmpty) {
            return nombreCompleto;
          }
        }
      }
    }

    if (_servicioData!['pasajero'] != null) {
      final pasajero = _servicioData!['pasajero'];
      if (pasajero is Map) {
        return pasajero['nombre'] ?? pasajero['name'] ?? 'Pasajero';
      }
    }

    return 'Pasajero';
  }

  /// Obtiene el teléfono del pasajero
  String? getTelefonoPasajero() {
    if (_servicioData == null) return null;

    if (_servicioData!['usuario_pasajero'] != null) {
      final usuarioPasajero = _servicioData!['usuario_pasajero'];
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

    if (_servicioData!['pasajero_telefono'] != null) {
      return _servicioData!['pasajero_telefono'];
    }

    if (_servicioData!['pasajero'] != null) {
      final pasajero = _servicioData!['pasajero'];
      if (pasajero is Map) {
        return pasajero['telefono'] ?? pasajero['phone'] ?? pasajero['celular'];
      }
    }

    return null;
  }

  /// Obtiene la foto del pasajero
  String? getFotoPasajero() {
    if (_servicioData == null) return null;

    if (_servicioData!['usuario_pasajero'] != null) {
      final usuarioPasajero = _servicioData!['usuario_pasajero'];
      if (usuarioPasajero is Map && usuarioPasajero['persona'] != null) {
        final persona = usuarioPasajero['persona'];
        if (persona is Map) {
          return persona['foto'];
        }
      }
    }

    if (_servicioData!['pasajero'] != null) {
      final pasajero = _servicioData!['pasajero'];
      if (pasajero is Map) {
        return pasajero['foto'] ?? pasajero['photo'];
      }
    }

    return null;
  }

  // ==================== UBICACIÓN Y MAPA ====================

  /// Carga el ícono personalizado del carro
  Future<void> _cargarIconoCarro() async {
    try {
      _carIcon = await BitmapDescriptor.asset(
        const ImageConfiguration(size: Size(48, 48)),
        'assets/icons/car_marker.png',
      );
    } catch (e) {
      print('⚠️ Error cargando ícono del carro: $e');
    }
  }

  /// Inicializa la ubicación y configura los marcadores
  Future<void> _inicializarUbicacion() async {
    if (_servicioData == null) return;

    try {
      // Obtener ubicación actual del conductor
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      _miUbicacion = LatLng(position.latitude, position.longitude);

      // Configurar destino inicial (punto de recogida)
      final origenLat = _parseDouble(_servicioData!['origen_lat']);
      final origenLng = _parseDouble(_servicioData!['origen_lng']);
      _destinoActual = LatLng(origenLat, origenLng);

      // Configurar marcadores
      await _actualizarMarcadores();

      // Dibujar ruta
      await _dibujarRuta();

      notifyListeners();
    } catch (e) {
      print('❌ Error inicializando ubicación: $e');
    }
  }

  /// Actualiza los marcadores en el mapa
  Future<void> _actualizarMarcadores() async {
    if (_servicioData == null) return;

    final markers = <Marker>{};

    // Marcador del conductor
    if (_miUbicacion != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('conductor'),
          position: _miUbicacion!,
          icon: _carIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          infoWindow: const InfoWindow(title: 'Mi ubicación'),
        ),
      );
    }

    // Marcador del destino actual
    if (_destinoActual != null) {
      final esRecogida = _estadoActual == 'aceptado' || _estadoActual == 'en_camino';
      markers.add(
        Marker(
          markerId: MarkerId(esRecogida ? 'origen' : 'destino'),
          position: _destinoActual!,
          icon: BitmapDescriptor.defaultMarkerWithHue(
            esRecogida ? BitmapDescriptor.hueGreen : BitmapDescriptor.hueRed,
          ),
          infoWindow: InfoWindow(
            title: esRecogida ? 'Punto de recogida' : 'Destino final',
          ),
        ),
      );
    }

    _markers = markers;
    notifyListeners();
  }

  /// Dibuja la ruta entre el conductor y el destino
  Future<void> _dibujarRuta() async {
    if (_miUbicacion == null || _destinoActual == null) return;

    try {
      final routeInfo = await _routesService.getRoute(
        origin: _miUbicacion!,
        destination: _destinoActual!,
      );

      if (routeInfo != null && routeInfo.polylinePoints.isNotEmpty) {
        _polylines.clear();
        _polylines.add(
          Polyline(
            polylineId: const PolylineId('ruta'),
            points: routeInfo.polylinePoints,
            color: _estadoActual == 'en_curso' ? Colors.green : Colors.blue,
            width: 5,
            patterns: [PatternItem.dash(20), PatternItem.gap(10)],
          ),
        );
        notifyListeners();
      }
    } catch (e) {
      print('❌ Error dibujando ruta: $e');
    }
  }

  /// Inicia el tracking GPS del conductor
  Future<void> _iniciarTracking() async {
    if (_servicioData == null || _conductorId == null) return;

    await _trackingService.iniciarSeguimiento(
      servicioId: _servicioData!['id'],
      conductorId: _conductorId!,
    );

    // Actualizar ubicación periódicamente en el provider
    Timer.periodic(const Duration(seconds: 5), (timer) async {
      if (_servicioData == null) {
        timer.cancel();
        return;
      }
      
      try {
        final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );
        
        _miUbicacion = LatLng(position.latitude, position.longitude);
        await _actualizarMarcadores();
        await _dibujarRuta();
      } catch (e) {
        print('❌ Error actualizando ubicación: $e');
      }
    });
  }

  // ==================== CAMBIO DE ESTADOS ====================

  /// Cambia el estado del servicio
  Future<bool> cambiarEstado(String nuevoEstado) async {
    if (_servicioData == null || _conductorId == null) return false;

    _isLoading = true;
    notifyListeners();

    final success = await ServicioTrackingService.cambiarEstadoStatic(
      servicioId: _servicioData!['id'],
      conductorId: _conductorId!,
      estado: nuevoEstado,
    );

    _isLoading = false;

    if (success) {
      _estadoActual = nuevoEstado;

      // Si llegó al punto de recogida, cambiar destino al final
      if (nuevoEstado == 'llegue') {
        final destinoLat = _parseDouble(_servicioData!['destino_lat']);
        final destinoLng = _parseDouble(_servicioData!['destino_lng']);

        if (destinoLat != 0.0 && destinoLng != 0.0) {
          _destinoActual = LatLng(destinoLat, destinoLng);
          await _actualizarMarcadores();
          await _dibujarRuta();
        }
      }

      notifyListeners();
    }

    return success;
  }

  /// Obtiene el texto y estado del próximo botón de acción
  Map<String, dynamic> getProximaAccion() {
    switch (_estadoActual) {
      case 'aceptado':
        return {
          'texto': 'ESTOY EN CAMINO',
          'proximoEstado': 'en_camino',
        };
      case 'en_camino':
        return {
          'texto': 'HE LLEGADO',
          'proximoEstado': 'llegue',
        };
      case 'llegue':
        return {
          'texto': 'INICIAR VIAJE',
          'proximoEstado': 'en_curso',
        };
      case 'en_curso':
        return {
          'texto': 'FINALIZAR VIAJE',
          'proximoEstado': 'finalizado',
        };
      default:
        return {};
    }
  }
}
