import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intellitaxi/features/rides/services/servicio_pusher_service.dart';
import 'package:intellitaxi/features/rides/services/routes_service.dart';
import 'package:intellitaxi/core/theme/app_colors.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:intellitaxi/core/dio_client.dart';

class PasajeroEsperandoConductorScreen extends StatefulWidget {
  final int servicioId;
  final Map<String, dynamic> datosServicio;

  const PasajeroEsperandoConductorScreen({
    super.key,
    required this.servicioId,
    required this.datosServicio,
  });

  @override
  State<PasajeroEsperandoConductorScreen> createState() =>
      _PasajeroEsperandoConductorScreenState();
}

class _PasajeroEsperandoConductorScreenState
    extends State<PasajeroEsperandoConductorScreen> {
  GoogleMapController? _mapController;
  final ServicioPusherService _pusherService = ServicioPusherService();
  final RoutesService _routesService = RoutesService();

  Map<String, dynamic>? _conductor;
  LatLng? _conductorUbicacion;
  String _estadoServicio = 'buscando';
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  BitmapDescriptor? _carIcon;

  @override
  void initState() {
    super.initState();
    print('\n' + '=' * 80);
    print('🚀 PASAJERO: Iniciando PasajeroEsperandoConductorScreen');
    print('=' * 80);
    print('   Servicio ID: ${widget.servicioId}');
    print('   Origen: ${widget.datosServicio['origen_address']}');
    print('   Destino: ${widget.datosServicio['destino_address']}');
    print('   Canal Pusher que escuchará: servicio.${widget.servicioId}');
    print('=' * 80 + '\n');

    print('🎨 PASAJERO: Creando marcadores...');
    _cargarIconoCarro();
    _crearMarcadores();
    print('✅ PASAJERO: Marcadores creados');

    print('⏰ PASAJERO: Programando suscripción a Pusher...');
    // Suscribir a eventos SIN bloquear la UI
    Future.microtask(() {
      print('🚀 PASAJERO: Ejecutando microtask de suscripción');
      _suscribirEventos();
    });

    // Verificar estado del servicio después de 3 segundos
    Future.delayed(const Duration(seconds: 3), () {
      _verificarEstadoServicio();
    });

    print('✅ PASAJERO: initState completado, continuando con build...\n');
  }

  Future<void> _verificarEstadoServicio() async {
    if (_conductor == null) {
      print(
        '⚠️ PASAJERO: No se recibió evento de aceptación, consultando API...',
      );
      await _obtenerInfoServicio();
    }
  }

  Future<void> _obtenerInfoServicio() async {
    try {
      final dio = DioClient.getInstance();
      print(
        '🔍 PASAJERO: Consultando servicio en /servicios/${widget.servicioId}',
      );

      final response = await dio.get('/servicios/taxi/${widget.servicioId}');
      print('📥 PASAJERO: Respuesta recibida: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = response.data;
        print('📦 PASAJERO: Data: $data');

        // El servicio puede estar directamente en data o en data['servicio']
        final servicio =
            data is Map<String, dynamic> && data.containsKey('servicio')
            ? data['servicio'] as Map<String, dynamic>
            : data as Map<String, dynamic>;

        if (servicio['conductor_id'] != null && servicio['conductor'] != null) {
          print('✅ PASAJERO: Info del servicio obtenida desde API');
          final conductor = servicio['conductor'] as Map<String, dynamic>;
          final vehiculo = conductor['vehiculo'] as Map<String, dynamic>?;

          // Parsear calificación (puede venir como String o double)
          final calificacion = conductor['calificacion_promedio'];
          final calificacionDouble = calificacion is String
              ? double.tryParse(calificacion) ?? 5.0
              : (calificacion as num?)?.toDouble() ?? 5.0;

          setState(() {
            _conductor = {
              'conductor_nombre': conductor['nombre'] ?? 'Conductor',
              'conductor_telefono': conductor['telefono'] ?? '',
              'conductor_foto': conductor['foto_perfil'],
              'vehiculo_placa': vehiculo?['placa'] ?? '',
              'vehiculo_marca': vehiculo?['marca'] ?? '',
              'vehiculo_modelo': vehiculo?['modelo'] ?? '',
              'vehiculo_color': vehiculo?['color'] ?? '',
              'conductor_calificacion': calificacionDouble,
            };
            _estadoServicio = 'aceptado';
          });

          // Si el servicio ya tiene ubicación del conductor, actualizarla
          if (servicio['conductor_lat'] != null &&
              servicio['conductor_lng'] != null) {
            setState(() {
              _conductorUbicacion = LatLng(
                _parseDouble(servicio['conductor_lat']),
                _parseDouble(servicio['conductor_lng']),
              );
            });
            _actualizarMarcadores();
            _centrarMapa();
          }
        } else {
          print('⚠️ PASAJERO: Servicio aún no tiene conductor asignado');
        }
      }
    } catch (e) {
      print('❌ Error obteniendo info del servicio: $e');
    }
  }

  Future<void> _cargarIconoCarro() async {
    try {
      _carIcon = await BitmapDescriptor.asset(
        const ImageConfiguration(size: Size(48, 48)),
        'assets/images/carMarker.png',
      );
      print('✅ PASAJERO: Ícono del carro cargado');
    } catch (e) {
      print('⚠️ Error cargando ícono del carro: $e');
    }
  }

  double _parseDouble(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  Future<void> _suscribirEventos() async {
    print(
      '🔌 PASAJERO: Iniciando suscripción a eventos del servicio ${widget.servicioId}',
    );
    // NO usar await para que no bloquee
    _pusherService.suscribirServicio(
      servicioId: widget.servicioId,
      onServicioAceptado: (data) {
        print('🎉 Servicio aceptado - Data completa:');
        print('   Conductor: ${data['conductor_nombre']}');
        print(
          '   Lat: ${data['conductor_lat']}, Lng: ${data['conductor_lng']}',
        );
        print('   Vehículo: ${data['vehiculo_placa']}');
        setState(() {
          _conductor = data;
          if (data['conductor_lat'] != null && data['conductor_lng'] != null) {
            _conductorUbicacion = LatLng(
              _parseDouble(data['conductor_lat']),
              _parseDouble(data['conductor_lng']),
            );
          }
          _estadoServicio = 'aceptado';
        });
        _actualizarMarcadores();
        _centrarMapa();
      },
      onUbicacionActualizada: (data) {
        print('📍 Ubicación del conductor actualizada: $data');
        // Backend envía conductor_lat y conductor_lng
        final lat = data['conductor_lat'] ?? data['lat'];
        final lng = data['conductor_lng'] ?? data['lng'];

        if (lat != null && lng != null) {
          setState(() {
            _conductorUbicacion = LatLng(_parseDouble(lat), _parseDouble(lng));

            // Si recibo ubicación del conductor y aún está "buscando",
            // significa que ya fue aceptado (cambiar estado automáticamente)
            if (_estadoServicio == 'buscando') {
              print(
                '✅ PASAJERO: Conductor ubicado, cambiando estado a aceptado',
              );
              _estadoServicio = 'aceptado';

              // Si no tengo info del conductor, solicitarla inmediatamente
              if (_conductor == null) {
                _obtenerInfoServicio();
              }
            }
          });
          print(
            '🚗 Nueva ubicación conductor: ${_conductorUbicacion?.latitude}, ${_conductorUbicacion?.longitude}',
          );
          _actualizarMarcadores();
          _centrarMapa();
        } else {
          print('⚠️ Datos de ubicación incompletos');
        }
      },
      onEstadoCambiado: (data) {
        print('🔄 Estado cambiado: ${data['estado']}');
        print('   Data completa del cambio: $data');

        final nuevoEstado = data['estado'] as String;

        setState(() {
          _estadoServicio = nuevoEstado;
        });

        // Redibujar ruta según el nuevo estado
        if (nuevoEstado == 'en_curso') {
          // En curso: cambiar destino a punto final
          print('🏁 Viaje iniciado, ruta ahora es conductor → destino');
          _dibujarRuta();
        } else {
          _dibujarRuta();
        }

        // Mostrar notificación visual
        _mostrarMensajeEstado(nuevoEstado);

        if (nuevoEstado == 'finalizado') {
          // Mostrar diálogo de viaje finalizado
          _mostrarDialogoFinalizado();
        }
      },
    );
  }

  void _mostrarMensajeEstado(String estado) {
    String mensaje;
    Color color = Colors.blue;
    IconData icono = Icons.info;

    switch (estado) {
      case 'aceptado':
        mensaje = '✅ Conductor aceptó tu solicitud';
        color = Colors.green;
        icono = Icons.check_circle;
        break;
      case 'en_camino':
        mensaje = '🚗 Conductor en camino a recogerte';
        color = Colors.blue;
        icono = Icons.directions_car;
        break;
      case 'llegue':
        mensaje = '📍 ¡El conductor ha llegado!';
        color = Colors.orange;
        icono = Icons.location_on;
        break;
      case 'en_curso':
        mensaje = '🏁 Viaje iniciado - En camino al destino';
        color = Colors.green;
        icono = Icons.navigation;
        break;
      case 'finalizado':
        mensaje = '✓ Viaje finalizado';
        color = Colors.grey;
        icono = Icons.flag;
        break;
      default:
        return;
    }

    // SnackBar más visible
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icono, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                mensaje,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: color,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _mostrarDialogoFinalizado() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 32),
            SizedBox(width: 12),
            Text('Viaje Finalizado'),
          ],
        ),
        content: const Text(
          '¡Gracias por usar nuestro servicio!\n\n¿Cómo calificas tu experiencia?',
          style: TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Cerrar diálogo
              Navigator.pop(context, true); // Regresar a home
            },
            child: const Text('Cerrar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // Cerrar diálogo
              // TODO: Abrir pantalla de calificación
              Navigator.pop(context, true); // Regresar a home
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Calificar'),
          ),
        ],
      ),
    );
  }

  void _crearMarcadores() {
    // Marcador origen (punto de recogida)
    _markers.add(
      Marker(
        markerId: const MarkerId('origen'),
        position: LatLng(
          _parseDouble(widget.datosServicio['origen_lat']),
          _parseDouble(widget.datosServicio['origen_lng']),
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        infoWindow: InfoWindow(
          title: 'Punto de Recogida',
          snippet: widget.datosServicio['origen_address'],
        ),
      ),
    );

    // Marcador destino
    _markers.add(
      Marker(
        markerId: const MarkerId('destino'),
        position: LatLng(
          _parseDouble(widget.datosServicio['destino_lat']),
          _parseDouble(widget.datosServicio['destino_lng']),
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        infoWindow: InfoWindow(
          title: 'Destino',
          snippet: widget.datosServicio['destino_address'],
        ),
      ),
    );
  }

  void _actualizarMarcadores() {
    if (_conductorUbicacion == null) {
      print(
        '⚠️ No se puede actualizar marcador: ubicación del conductor es null',
      );
      return;
    }

    print('🗺️ Actualizando marcadores:');
    print(
      '   Conductor en: ${_conductorUbicacion!.latitude}, ${_conductorUbicacion!.longitude}',
    );

    setState(() {
      _markers.removeWhere((m) => m.markerId.value == 'conductor');
      _markers.add(
        Marker(
          markerId: const MarkerId('conductor'),
          position: _conductorUbicacion!,
          icon:
              _carIcon ??
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          infoWindow: InfoWindow(
            title: _conductor?['conductor_nombre'] ?? 'Conductor',
            snippet: '${_conductor?['vehiculo_placa'] ?? ''}',
          ),
          rotation: 0.0,
          anchor: const Offset(0.5, 0.5),
        ),
      );

      // Dibujar línea entre conductor y punto de recogida
      _dibujarRuta();
    });

    print('✅ Marcador del conductor actualizado');
  }

  void _centrarMapa() {
    if (_mapController == null || _conductorUbicacion == null) return;

    // Calcular bounds para mostrar conductor y punto de recogida
    final bounds = _calcularBounds();
    _mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 100));
  }

  LatLngBounds _calcularBounds() {
    final origenLat = _parseDouble(widget.datosServicio['origen_lat']);
    final origenLng = _parseDouble(widget.datosServicio['origen_lng']);

    final lats = [_conductorUbicacion?.latitude ?? origenLat, origenLat];
    final lngs = [_conductorUbicacion?.longitude ?? origenLng, origenLng];

    return LatLngBounds(
      southwest: LatLng(
        lats.reduce((a, b) => a < b ? a : b),
        lngs.reduce((a, b) => a < b ? a : b),
      ),
      northeast: LatLng(
        lats.reduce((a, b) => a > b ? a : b),
        lngs.reduce((a, b) => a > b ? a : b),
      ),
    );
  }

  Future<void> _dibujarRuta() async {
    final origenLat = _parseDouble(widget.datosServicio['origen_lat']);
    final origenLng = _parseDouble(widget.datosServicio['origen_lng']);
    final destinoLat = _parseDouble(widget.datosServicio['destino_lat']);
    final destinoLng = _parseDouble(widget.datosServicio['destino_lng']);

    try {
      _polylines.clear();

      // Línea del conductor al punto de recogida (solo si está yendo a recoger)
      if (_conductorUbicacion != null &&
          (_estadoServicio == 'aceptado' || _estadoServicio == 'en_camino')) {
        final rutaConductorOrigen = await _routesService.getRoute(
          origin: _conductorUbicacion!,
          destination: LatLng(origenLat, origenLng),
        );

        if (rutaConductorOrigen != null) {
          _polylines.add(
            Polyline(
              polylineId: const PolylineId('conductor_origen'),
              points: rutaConductorOrigen.polylinePoints,
              color: Colors.blue,
              width: 4,
            ),
          );
        }
      }

      // Línea del origen al destino (ruta del viaje)
      final rutaOrigenDestino = await _routesService.getRoute(
        origin: LatLng(origenLat, origenLng),
        destination: LatLng(destinoLat, destinoLng),
      );

      if (rutaOrigenDestino != null) {
        _polylines.add(
          Polyline(
            polylineId: const PolylineId('origen_destino'),
            points: rutaOrigenDestino.polylinePoints,
            color: AppColors.primary,
            width: 3,
            patterns: [PatternItem.dash(15), PatternItem.gap(10)],
          ),
        );
      }

      setState(() {});
      print('✅ Polylines con rutas reales dibujadas');
    } catch (e) {
      print('❌ Error dibujando rutas: $e');
    }
  }

  Future<void> _llamarConductor() async {
    final telefono = _conductor?['conductor_telefono'];
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
        body: Stack(
          children: [
            GoogleMap(
              initialCameraPosition: CameraPosition(
                target: LatLng(
                  _parseDouble(widget.datosServicio['origen_lat']),
                  _parseDouble(widget.datosServicio['origen_lng']),
                ),
                zoom: 14,
              ),
              markers: _markers,
              polylines: _polylines,
              myLocationEnabled: true,
              myLocationButtonEnabled: true,
              onMapCreated: (controller) {
                _mapController = controller;
              },
            ),

            // Panel de información
            if (_estadoServicio != 'buscando')
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: _buildPanelInfo(),
              ),

            // Loading mientras busca conductor
            if (_estadoServicio == 'buscando')
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: _buildBuscandoConductor(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBuscandoConductor() {
    return Container(
      padding: const EdgeInsets.all(30),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 20),
          const Text(
            'Buscando conductor disponible...',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Text(
            'Por favor espera mientras encontramos un conductor cerca de ti',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildPanelInfo() {
    final estadosInfo = {
      'aceptado': {
        'texto': '🚗 Conductor en camino a recogerte',
        'color': Colors.blue,
        'icono': Icons.directions_car,
      },
      'en_camino': {
        'texto': '🚗 Conductor en camino a recogerte',
        'color': Colors.blue,
        'icono': Icons.directions_car,
      },
      'llegue': {
        'texto': '📍 Conductor ha llegado - ¡Sal a encontrarlo!',
        'color': Colors.orange,
        'icono': Icons.location_on,
      },
      'en_curso': {
        'texto': '🏁 Viaje en curso - Dirígete al destino',
        'color': Colors.green,
        'icono': Icons.navigation,
      },
    };

    final info =
        estadosInfo[_estadoServicio] ??
        {'texto': 'Servicio activo', 'color': Colors.grey, 'icono': Icons.info};

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Indicador de estado animado
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: info['color'] as Color,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: (info['color'] as Color).withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(info['icono'] as IconData, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    info['texto'] as String,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 15),

          // Info del conductor
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: AppColors.primary,
                  child: const Icon(
                    Icons.person,
                    color: Colors.white,
                    size: 35,
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _conductor?['conductor_nombre'] ?? 'Conductor',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.star, color: Colors.amber, size: 18),
                          const SizedBox(width: 5),
                          Text(
                            '${_conductor?['conductor_calificacion'] ?? 5.0}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Iconsax.call, color: Colors.green, size: 30),
                  onPressed: _llamarConductor,
                ),
              ],
            ),
          ),

          const SizedBox(height: 15),

          // Info del vehículo
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(
                  children: [
                    Text(
                      '${_conductor?['vehiculo_marca'] ?? ''} ${_conductor?['vehiculo_modelo'] ?? ''}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      _conductor?['vehiculo_color'] ?? '',
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 15,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(
                    _conductor?['vehiculo_placa'] ?? '---',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      letterSpacing: 2,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _pusherService.desconectar();
    _mapController?.dispose();
    super.dispose();
  }
}
