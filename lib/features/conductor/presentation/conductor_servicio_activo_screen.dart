import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intellitaxi/features/rides/services/servicio_tracking_service.dart';
import 'package:intellitaxi/features/rides/services/routes_service.dart';
import 'package:intellitaxi/features/rides/services/servicio_persistencia_service.dart';
import 'package:intellitaxi/features/rides/services/servicio_notificacion_foreground.dart';
import 'package:intellitaxi/core/theme/app_colors.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:intellitaxi/shared/widgets/standard_map.dart';
import 'package:intellitaxi/shared/widgets/standard_button.dart';

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
  final ServicioPersistenciaService _persistencia =
      ServicioPersistenciaService();
  final ServicioNotificacionForeground _notificacionService =
      ServicioNotificacionForeground();

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

  @override
  void dispose() {
    _trackingService.detenerSeguimiento();
    super.dispose();
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
          
          final nombreCompleto = '$nombre1 ${nombre2.isEmpty ? '' : nombre2} $apellido1 ${apellido2.isEmpty ? '' : apellido2}'.trim();
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

  // Método helper para obtener el precio
  String _getPrecio() {
    final precioFinal = widget.servicio['precio_final'];
    final precioEstimado = widget.servicio['precio_estimado'];
    
    if (precioFinal != null) {
      return precioFinal.toString().replaceAll('.00', '');
    }
    if (precioEstimado != null) {
      return precioEstimado.toString().replaceAll('.00', '');
    }
    
    return '0';
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
      print('✅ CONDUCTOR: Ícono del carro cargado');
    } catch (e) {
      print('⚠️ Error cargando ícono del carro: $e');
    }
  }

  Future<void> _inicializar() async {
    // Debug: Ver estructura completa del servicio
    print('🔍 DATOS DEL SERVICIO RECIBIDOS:');
    print('   ID: ${widget.servicio['id']}');
    print('   Pasajero nombre directo: ${widget.servicio['pasajero_nombre']}');
    print('   Pasajero objeto: ${widget.servicio['pasajero']}');
    print('   Precio final: ${widget.servicio['precio_final']}');
    print('   Precio estimado: ${widget.servicio['precio_estimado']}');
    print('   Origen: ${widget.servicio['origen_address']}');
    print('   Destino: ${widget.servicio['destino_address']}');
    print('');
    
    // Cargar icono del carro
    await _cargarIconoCarro();

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

  Future<void> _guardarServicioActivo() async {
    try {
      print('📋 Intentando guardar servicio activo...');
      print('📦 Datos del servicio: ${widget.servicio}');
      
      final servicioId = widget.servicio['id'];
      if (servicioId == null) {
        print('❌ Error: servicioId es null');
        print('📦 Keys disponibles: ${widget.servicio.keys}');
        return;
      }
      
      await _persistencia.guardarServicioActivo(
        servicioId: servicioId,
        tipo: 'conductor',
        datosServicio: widget.servicio,
      );
      print('✅ Servicio activo guardado: $servicioId');
    } catch (e, stackTrace) {
      print('❌ Error guardando servicio activo: $e');
      print('Stack trace: $stackTrace');
    }
  }

  Future<void> _mostrarNotificacionPersistente() async {
    await _notificacionService.mostrarNotificacionConductor(
      servicioId: widget.servicio['id'],
      estado: _estadoActual,
      origen: widget.servicio['origen_address'] ?? 'Origen',
      destino: widget.servicio['destino_address'] ?? 'Destino',
    );
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

    if (mounted) {
      Navigator.of(context).pop();
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
    if (telefono != null) {
      // TODO: Implementar llamada telefónica
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Llamar a: $telefono'),
          duration: const Duration(seconds: 2),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No hay teléfono disponible'),
          duration: Duration(seconds: 2),
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

            // Panel de información y botones
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(20),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 15,
                      offset: const Offset(0, -3),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Handle decorativo
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),

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
    final fotoUrl = _getFotoPasajero();
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withOpacity(0.3), width: 1),
      ),
      child: Row(
        children: [
          // Avatar con foto o icono por defecto
          fotoUrl != null && fotoUrl.isNotEmpty
              ? CircleAvatar(
                  radius: 28,
                  backgroundColor: AppColors.primary.withOpacity(0.1),
                  backgroundImage: NetworkImage(fotoUrl),
                  onBackgroundImageError: (exception, stackTrace) {
                    print('⚠️ Error cargando foto del pasajero: $exception');
                  },
                  child: null,
                )
              : CircleAvatar(
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
                  _getNombrePasajero(),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                // Text(
                //   '\$${_getPrecio()}',
                //   style: const TextStyle(
                //     fontSize: 15,
                //     color: AppColors.green,
                //     fontWeight: FontWeight.bold,
                //   ),
                // ),
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
    final direccion = _estadoActual == 'en_curso'
        ? widget.servicio['destino_address']
        : widget.servicio['origen_address'];

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.accent.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.accent.withOpacity(0.3), width: 1),
      ),
      child: Row(
        children: [
          Icon(
            _estadoActual == 'en_curso'
                ? Iconsax.location
                : Iconsax.location_add,
            color: _estadoActual == 'en_curso'
                ? AppColors.green
                : AppColors.accent,
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

    return StandardButton(
      text: texto,
      icon: icono,
      onPressed: () => _cambiarEstado(proximoEstado),
      isLoading: _isLoading,
      width: double.infinity,
      height: 56,
    );
  }
}
