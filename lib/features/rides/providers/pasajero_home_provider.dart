import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intellitaxi/features/rides/services/routes_service.dart';

// TODO: Crear este modelo cuando esté disponible:
// - lib/features/rides/data/autocomplete_prediction.dart

/// Provider para gestionar la lógica del home del pasajero
/// Incluye: ubicación, búsqueda de direcciones, solicitud de servicio
/// 
/// NOTA: Usa Map<String, dynamic> temporalmente hasta que se creen los modelos
class PasajeroHomeProvider extends ChangeNotifier {
  final RoutesService _routesService = RoutesService();

  // Estado de ubicación
  Position? _currentPosition;
  bool _isLoadingLocation = true;

  // Búsqueda de direcciones - Usando Map temporalmente
  List<Map<String, dynamic>> _originSuggestions = [];
  List<Map<String, dynamic>> _destinationSuggestions = [];
  bool _isSearchingOrigin = false;
  bool _isSearchingDestination = false;

  // Direcciones seleccionadas
  String? _origenSeleccionado;
  String? _destinoSeleccionado;
  LatLng? _origenLatLng;
  LatLng? _destinoLatLng;

  // Mapa
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  double? _distanciaKm;
  double? _precioEstimado;

  // Getters
  Position? get currentPosition => _currentPosition;
  bool get isLoadingLocation => _isLoadingLocation;
  List<Map<String, dynamic>> get originSuggestions => _originSuggestions;
  List<Map<String, dynamic>> get destinationSuggestions => _destinationSuggestions;
  bool get isSearchingOrigin => _isSearchingOrigin;
  bool get isSearchingDestination => _isSearchingDestination;
  String? get origenSeleccionado => _origenSeleccionado;
  String? get destinoSeleccionado => _destinoSeleccionado;
  LatLng? get origenLatLng => _origenLatLng;
  LatLng? get destinoLatLng => _destinoLatLng;
  Set<Marker> get markers => _markers;
  Set<Polyline> get polylines => _polylines;
  double? get distanciaKm => _distanciaKm;
  double? get precioEstimado => _precioEstimado;

  bool get puedeCrearSolicitud =>
      _origenLatLng != null && _destinoLatLng != null;

  /// Inicializa el provider
  Future<void> initialize() async {
    await _getCurrentLocation();
  }

  /// Obtiene la ubicación actual del pasajero
  Future<void> _getCurrentLocation() async {
    try {
      _isLoadingLocation = true;
      notifyListeners();

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      _currentPosition = position;
      _isLoadingLocation = false;
      notifyListeners();
    } catch (e) {
      print('❌ Error obteniendo ubicación: $e');
      _isLoadingLocation = false;
      notifyListeners();
    }
  }

  /// Busca sugerencias de direcciones para el origen
  /// 
  /// TODO: Implementar cuando exista el método buscarDireccion en RoutesService
  Future<void> buscarOrigen(String query) async {
    if (query.isEmpty) {
      _originSuggestions = [];
      notifyListeners();
      return;
    }

    try {
      _isSearchingOrigin = true;
      notifyListeners();

      // TODO: Descomentar cuando exista el método
      // final sugerencias = await _routesService.buscarDireccion(query);
      // _originSuggestions = sugerencias;

      // Temporalmente retornar lista vacía
      _originSuggestions = [];
      _isSearchingOrigin = false;
      notifyListeners();
    } catch (e) {
      print('❌ Error buscando origen: $e');
      _isSearchingOrigin = false;
      notifyListeners();
    }
  }

  /// Busca sugerencias de direcciones para el destino
  /// 
  /// TODO: Implementar cuando exista el método buscarDireccion en RoutesService
  Future<void> buscarDestino(String query) async {
    if (query.isEmpty) {
      _destinationSuggestions = [];
      notifyListeners();
      return;
    }

    try {
      _isSearchingDestination = true;
      notifyListeners();

      // TODO: Descomentar cuando exista el método
      // final sugerencias = await _routesService.buscarDireccion(query);
      // _destinationSuggestions = sugerencias;

      // Temporalmente retornar lista vacía
      _destinationSuggestions = [];
      _isSearchingDestination = false;
      notifyListeners();
    } catch (e) {
      print('❌ Error buscando destino: $e');
      _isSearchingDestination = false;
      notifyListeners();
    }
  }

  /// Selecciona una dirección de origen
  /// 
  /// TODO: Implementar cuando exista obtenerCoordenadasDeDireccion en RoutesService
  Future<void> seleccionarOrigen(Map<String, dynamic> prediction) async {
    try {
      _origenSeleccionado = prediction['description'];

      // TODO: Descomentar cuando exista el método
      // final latLng = await _routesService.obtenerCoordenadasDeDireccion(
      //   prediction['place_id'],
      // );
      // _origenLatLng = latLng;

      _originSuggestions = [];

      // Actualizar mapa
      await _actualizarMapa();

      notifyListeners();
    } catch (e) {
      print('❌ Error seleccionando origen: $e');
    }
  }

  /// Selecciona una dirección de destino
  /// 
  /// TODO: Implementar cuando exista obtenerCoordenadasDeDireccion en RoutesService
  Future<void> seleccionarDestino(Map<String, dynamic> prediction) async {
    try {
      _destinoSeleccionado = prediction['description'];

      // TODO: Descomentar cuando exista el método
      // final latLng = await _routesService.obtenerCoordenadasDeDireccion(
      //   prediction['place_id'],
      // );
      // _destinoLatLng = latLng;

      _destinationSuggestions = [];

      // Actualizar mapa
      await _actualizarMapa();

      notifyListeners();
    } catch (e) {
      print('❌ Error seleccionando destino: $e');
    }
  }

  /// Actualiza los marcadores y la ruta en el mapa
  Future<void> _actualizarMapa() async {
    _markers.clear();
    _polylines.clear();

    // Agregar marcador de origen
    if (_origenLatLng != null) {
      _markers.add(
        Marker(
          markerId: const MarkerId('origen'),
          position: _origenLatLng!,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          infoWindow: const InfoWindow(title: 'Origen'),
        ),
      );
    }

    // Agregar marcador de destino
    if (_destinoLatLng != null) {
      _markers.add(
        Marker(
          markerId: const MarkerId('destino'),
          position: _destinoLatLng!,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: const InfoWindow(title: 'Destino'),
        ),
      );
    }

    // Dibujar ruta si tenemos origen y destino
    if (_origenLatLng != null && _destinoLatLng != null) {
      await _dibujarRuta();
      await _calcularPrecio();
    }

    notifyListeners();
  }

  /// Dibuja la ruta entre origen y destino
  Future<void> _dibujarRuta() async {
    if (_origenLatLng == null || _destinoLatLng == null) return;

    try {
      final routeInfo = await _routesService.getRoute(
        origin: _origenLatLng!,
        destination: _destinoLatLng!,
      );

      if (routeInfo != null && routeInfo.polylinePoints.isNotEmpty) {
        _polylines.add(
          Polyline(
            polylineId: const PolylineId('ruta'),
            points: routeInfo.polylinePoints,
            color: Colors.blue,
            width: 5,
          ),
        );

        // Calcular distancia
        _distanciaKm = _calcularDistancia(routeInfo.polylinePoints);
      }
    } catch (e) {
      print('❌ Error dibujando ruta: $e');
    }
  }

  /// Calcula la distancia total de la ruta
  double _calcularDistancia(List<LatLng> points) {
    double totalDistance = 0.0;
    for (int i = 0; i < points.length - 1; i++) {
      totalDistance += Geolocator.distanceBetween(
        points[i].latitude,
        points[i].longitude,
        points[i + 1].latitude,
        points[i + 1].longitude,
      );
    }
    return totalDistance / 1000; // Convertir a kilómetros
  }

  /// Calcula el precio estimado del viaje
  Future<void> _calcularPrecio() async {
    if (_distanciaKm == null) return;

    // Lógica de cálculo de precio
    // Tarifa base + costo por kilómetro
    const tarifaBase = 3.0;
    const costoPorKm = 1.5;

    _precioEstimado = tarifaBase + (_distanciaKm! * costoPorKm);
    notifyListeners();
  }

  /// Limpia las selecciones
  void limpiarSelecciones() {
    _origenSeleccionado = null;
    _destinoSeleccionado = null;
    _origenLatLng = null;
    _destinoLatLng = null;
    _markers.clear();
    _polylines.clear();
    _distanciaKm = null;
    _precioEstimado = null;
    _originSuggestions = [];
    _destinationSuggestions = [];
    notifyListeners();
  }
}
