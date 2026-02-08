import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intellitaxi/features/rides/services/servicio_tracking_service.dart';
import 'package:intellitaxi/features/rides/services/routes_service.dart';
import 'package:intellitaxi/core/theme/app_colors.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

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
    extends State<ConductorServicioActivoScreen> {
  GoogleMapController? _mapController;
  final ServicioTrackingService _trackingService = ServicioTrackingService();
  final RoutesService _routesService = RoutesService();

  String _estadoActual = 'aceptado';
  LatLng? _miUbicacion;
  LatLng? _destinoActual;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  bool _isLoading = false;
  BitmapDescriptor? _carIcon;

  @override
  void initState() {
    super.initState();
    _inicializar();
  }

  double _parseDouble(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  Future<void> _cargarIconoCarro() async {
    try {
      _carIcon = await BitmapDescriptor.asset(
        const ImageConfiguration(size: Size(48, 48)),
        'assets/images/carMarker.png',
      );
      print('✅ CONDUCTOR: Ícono del carro cargado');
    } catch (e) {
      print('⚠️ Error cargando ícono del carro: $e');
    }
  }

  Future<void> _inicializar() async {
    // Cargar icono del carro
    await _cargarIconoCarro();

    // Iniciar seguimiento
    await _trackingService.iniciarSeguimiento(
      servicioId: widget.servicio['id'],
      conductorId: widget.conductorId,
    );

    // El destino inicial es el punto de recogida
    // Convertir valores que pueden venir como string
    final origenLat = _parseDouble(widget.servicio['origen_lat']);
    final origenLng = _parseDouble(widget.servicio['origen_lng']);

    setState(() {
      _destinoActual = LatLng(origenLat, origenLng);
    });

    // Obtener ubicación actual
    await _obtenerUbicacionActual();

    // Actualizar marcadores
    _actualizarMarcadores();
  }

  Future<void> _obtenerUbicacionActual() async {
    try {
      final position = await Geolocator.getCurrentPosition();
      setState(() {
        _miUbicacion = LatLng(position.latitude, position.longitude);
      });

      // Actualizar marcadores y ruta
      _actualizarMarcadores();
      _dibujarRuta();

      // Centrar cámara
      _mapController?.animateCamera(CameraUpdate.newLatLng(_miUbicacion!));
    } catch (e) {
      print('Error obteniendo ubicación: $e');
    }
  }

  void _actualizarMarcadores() {
    setState(() {
      _markers = {};

      // Marcador de destino actual
      if (_destinoActual != null) {
        _markers.add(
          Marker(
            markerId: const MarkerId('destino'),
            position: _destinoActual!,
            icon: BitmapDescriptor.defaultMarkerWithHue(
              _estadoActual == 'en_curso'
                  ? BitmapDescriptor.hueGreen
                  : BitmapDescriptor.hueRed,
            ),
            infoWindow: InfoWindow(
              title: _estadoActual == 'en_curso'
                  ? 'Destino Final'
                  : 'Punto de Recogida',
              snippet: _estadoActual == 'en_curso'
                  ? widget.servicio['destino_address']
                  : widget.servicio['origen_address'],
            ),
          ),
        );
      }

      // Mi ubicación (conductor) con icono personalizado
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

    try {
      // Obtener ruta real de Google Maps
      final routeInfo = await _routesService.getRoute(
        origin: _miUbicacion!,
        destination: _destinoActual!,
      );

      if (routeInfo != null) {
        setState(() {
          _polylines.clear();

          // Línea con la ruta real desde mi ubicación hasta el destino actual
          _polylines.add(
            Polyline(
              polylineId: const PolylineId('ruta_actual'),
              points: routeInfo.polylinePoints,
              color: _estadoActual == 'en_curso' ? Colors.green : Colors.blue,
              width: 5,
            ),
          );
        });
        print('✅ Ruta dibujada: ${routeInfo.distance} - ${routeInfo.duration}');
      }
    } catch (e) {
      print('❌ Error dibujando ruta: $e');
      // Fallback: línea recta
      setState(() {
        _polylines.clear();
        _polylines.add(
          Polyline(
            polylineId: const PolylineId('ruta_actual'),
            points: [_miUbicacion!, _destinoActual!],
            color: _estadoActual == 'en_curso' ? Colors.green : Colors.blue,
            width: 5,
            patterns: [PatternItem.dash(20), PatternItem.gap(10)],
          ),
        );
      });
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

        // Si llegó al punto de recogida, cambiar destino al final
        if (nuevoEstado == 'llegue') {
          final destinoLat = _parseDouble(widget.servicio['destino_lat']);
          final destinoLng = _parseDouble(widget.servicio['destino_lng']);
          _destinoActual = LatLng(destinoLat, destinoLng);
          _actualizarMarcadores();
        }
      });

      // Mostrar mensaje
      _mostrarMensaje(_obtenerMensajeEstado(nuevoEstado));

      // Si finalizó, detener seguimiento y volver
      if (nuevoEstado == 'finalizado') {
        _trackingService.detenerSeguimiento();
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) {
          Navigator.pop(context, true);
        }
      }
    } else {
      _mostrarError('Error al cambiar estado');
    }
  }

  String _obtenerMensajeEstado(String estado) {
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
    final telefono = widget.servicio['pasajero_telefono'];
    if (telefono != null) {
      // TODO: Implementar llamada telefónica
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Llamar a: $telefono'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Servicio en Curso'),
          automaticallyImplyLeading: false,
          backgroundColor: AppColors.primary,
        ),
        body: Stack(
          children: [
            // Mapa
            if (_miUbicacion != null && _destinoActual != null)
              GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: _miUbicacion!,
                  zoom: 15,
                ),
                myLocationEnabled: true,
                myLocationButtonEnabled: true,
                markers: _markers,
                polylines: _polylines,
                onMapCreated: (controller) {
                  _mapController = controller;
                },
              )
            else
              const Center(child: CircularProgressIndicator()),

            // Panel de información y botones
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(20),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(20),
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
                  ],
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
      'aceptado': {'texto': 'YENDO AL PUNTO DE RECOGIDA', 'color': Colors.blue},
      'en_camino': {
        'texto': 'YENDO AL PUNTO DE RECOGIDA',
        'color': Colors.blue,
      },
      'llegue': {'texto': 'ESPERANDO PASAJERO', 'color': Colors.orange},
      'en_curso': {'texto': 'VIAJE EN CURSO', 'color': Colors.green},
    };

    final info =
        estados[_estadoActual] ??
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
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: AppColors.primary,
            child: const Icon(Icons.person, color: Colors.white, size: 32),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.servicio['pasajero_nombre'] ?? 'Pasajero',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '\$${widget.servicio['precio_final'] ?? widget.servicio['precio_estimado']}',
                  style: const TextStyle(
                    fontSize: 15,
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Iconsax.call, color: Colors.green, size: 28),
            onPressed: _llamarPasajero,
          ),
        ],
      ),
    );
  }

  Widget _buildDireccionActual() {
    final direccion = _estadoActual == 'en_curso'
        ? widget.servicio['destino_address']
        : widget.servicio['origen_address'];

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        children: [
          Icon(
            _estadoActual == 'en_curso'
                ? Iconsax.location
                : Iconsax.location_add,
            color: _estadoActual == 'en_curso' ? Colors.green : Colors.red,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              direccion ?? 'Sin dirección',
              style: const TextStyle(fontSize: 13),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBotonAccion() {
    String texto;
    String proximoEstado;
    IconData icono;

    switch (_estadoActual) {
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

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _isLoading ? null : () => _cambiarEstado(proximoEstado),
        icon: Icon(icono),
        label: Text(texto),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _trackingService.detenerSeguimiento();
    _mapController?.dispose();
    super.dispose();
  }
}
