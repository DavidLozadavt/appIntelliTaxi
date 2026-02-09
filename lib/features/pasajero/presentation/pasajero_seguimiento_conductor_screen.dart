import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intellitaxi/features/rides/services/servicio_pusher_service.dart';
import 'package:intellitaxi/core/theme/app_colors.dart';
import 'package:intellitaxi/shared/widgets/standard_map.dart';

/// Pantalla del pasajero para seguir al conductor en tiempo real
class PasajeroSeguimientoConductorScreen extends StatefulWidget {
  final int servicioId;
  final Map<String, dynamic> datosServicio;

  const PasajeroSeguimientoConductorScreen({
    super.key,
    required this.servicioId,
    required this.datosServicio,
  });

  @override
  State<PasajeroSeguimientoConductorScreen> createState() =>
      _PasajeroSeguimientoConductorScreenState();
}

class _PasajeroSeguimientoConductorScreenState
    extends State<PasajeroSeguimientoConductorScreen> {
  GoogleMapController? _mapController;
  final ServicioPusherService _pusherService = ServicioPusherService();

  Map<String, dynamic>? _conductor;
  LatLng? _conductorUbicacion;
  String _estadoServicio = 'buscando';
  final Set<Marker> _markers = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _inicializar();
  }

  Future<void> _inicializar() async {
    await _suscribirEventos();
    _crearMarcadores();

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _suscribirEventos() async {
    await _pusherService.suscribirServicio(
      servicioId: widget.servicioId,
      onServicioAceptado: (data) {
        print('📥 [PASAJERO] Servicio aceptado - Data completa:');
        print('   Keys disponibles: ${data.keys}');
        print('   conductor_foto: ${data['conductor_foto']}');
        print('   foto: ${data['foto']}');
        print('   conductor_nombre: ${data['conductor_nombre']}');
        print('   conductor_calificacion: ${data['conductor_calificacion']}');

        if (!mounted) return;

        setState(() {
          _conductor = data;
          _conductorUbicacion = LatLng(
            data['conductor_lat'] ?? data['lat'] ?? 0.0,
            data['conductor_lng'] ?? data['lng'] ?? 0.0,
          );
          _estadoServicio = 'aceptado';
        });

        _actualizarMarcadores();
        _centrarMapa();
      },
      onUbicacionActualizada: (data) {
        if (!mounted) return;

        setState(() {
          _conductorUbicacion = LatLng(data['lat'] ?? 0.0, data['lng'] ?? 0.0);
        });

        _actualizarMarcadores();
      },
      onEstadoCambiado: (data) {
        print('📥 Estado cambiado: $data');

        if (!mounted) return;

        setState(() {
          _estadoServicio =
              data['estado'] ?? data['nuevo_estado'] ?? _estadoServicio;
        });

        // Mostrar notificación según el estado
        _mostrarNotificacionEstado(_estadoServicio);

        // Si finalizó, cerrar pantalla
        if (_estadoServicio == 'finalizado') {
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) {
              Navigator.pop(context, true);
            }
          });
        }
      },
    );
  }

  void _mostrarNotificacionEstado(String estado) {
    String mensaje;
    Color color;

    switch (estado) {
      case 'aceptado':
      case 'en_camino':
        mensaje = '🚗 El conductor va en camino';
        color = Colors.blue;
        break;
      case 'llegue':
        mensaje = '📍 El conductor ha llegado';
        color = Colors.orange;
        break;
      case 'en_curso':
        mensaje = '✅ Viaje iniciado';
        color = Colors.green;
        break;
      case 'finalizado':
        mensaje = '🎉 Viaje finalizado';
        color = Colors.purple;
        break;
      default:
        return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor: color,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _crearMarcadores() {
    setState(() {
      _markers.clear();

      // Marcador origen (punto de recogida)
      _markers.add(
        Marker(
          markerId: const MarkerId('origen'),
          position: LatLng(
            widget.datosServicio['origen_lat'] ?? 0.0,
            widget.datosServicio['origen_lng'] ?? 0.0,
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueGreen,
          ),
          infoWindow: InfoWindow(
            title: 'Punto de Recogida',
            snippet: widget.datosServicio['origen_address'] ?? '',
          ),
        ),
      );

      // Marcador destino
      _markers.add(
        Marker(
          markerId: const MarkerId('destino'),
          position: LatLng(
            widget.datosServicio['destino_lat'] ?? 0.0,
            widget.datosServicio['destino_lng'] ?? 0.0,
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: InfoWindow(
            title: 'Destino',
            snippet: widget.datosServicio['destino_address'] ?? '',
          ),
        ),
      );
    });
  }

  void _actualizarMarcadores() {
    if (_conductorUbicacion == null) return;

    setState(() {
      _markers.removeWhere((m) => m.markerId.value == 'conductor');
      _markers.add(
        Marker(
          markerId: const MarkerId('conductor'),
          position: _conductorUbicacion!,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          infoWindow: InfoWindow(
            title: _conductor?['conductor_nombre'] ?? 'Conductor',
            snippet:
                '${_conductor?['vehiculo_placa'] ?? ''} • ${_conductor?['vehiculo_marca'] ?? ''}',
          ),
        ),
      );
    });
  }

  void _centrarMapa() {
    if (_mapController == null || _conductorUbicacion == null) return;

    // Calcular bounds para mostrar conductor y punto de recogida
    final lats = [
      _conductorUbicacion!.latitude,
      widget.datosServicio['origen_lat'] ?? 0.0,
    ];
    final lngs = [
      _conductorUbicacion!.longitude,
      widget.datosServicio['origen_lng'] ?? 0.0,
    ];

    final bounds = LatLngBounds(
      southwest: LatLng(
        lats.reduce((a, b) => a < b ? a : b),
        lngs.reduce((a, b) => a < b ? a : b),
      ),
      northeast: LatLng(
        lats.reduce((a, b) => a > b ? a : b),
        lngs.reduce((a, b) => a > b ? a : b),
      ),
    );

    _mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 100));
  }

  // Helper para obtener la URL de la foto del conductor
  String? _getFotoConductor() {
    if (_conductor == null) return null;
    
    // Intentar diferentes campos posibles
    final foto = _conductor!['conductor_foto'] ?? 
                 _conductor!['foto'] ?? 
                 _conductor!['conductor']?['foto'];
    
    if (foto != null && foto.toString().isNotEmpty) {
      print('✅ [PASAJERO] Foto encontrada: $foto');
      return foto.toString();
    }
    
    print('⚠️ [PASAJERO] No se encontró foto del conductor');
    return null;
  }

  // Widget para el avatar del conductor
  Widget _buildConductorAvatar() {
    final fotoUrl = _getFotoConductor();
    
    if (fotoUrl != null && fotoUrl.isNotEmpty) {
      return CircleAvatar(
        radius: 30,
        backgroundColor: AppColors.accent.withOpacity(0.1),
        backgroundImage: NetworkImage(fotoUrl),
        onBackgroundImageError: (exception, stackTrace) {
          print('⚠️ Error cargando foto del conductor: $exception');
        },
      );
    }
    
    return CircleAvatar(
      radius: 30,
      backgroundColor: AppColors.accent,
      child: const Icon(
        Icons.person,
        size: 30,
        color: Colors.white,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // Confirmar antes de salir
        final confirmar = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('¿Salir?'),
            content: const Text(
              '¿Estás seguro de que quieres salir? '
              'Tienes un servicio activo.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Salir'),
              ),
            ],
          ),
        );
        return confirmar ?? false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Tu viaje'),
          automaticallyImplyLeading: _estadoServicio != 'buscando',
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Stack(
                children: [
                  // Mapa
                  StandardMap(
                    initialPosition: LatLng(
                      widget.datosServicio['origen_lat'] ?? 0.0,
                      widget.datosServicio['origen_lng'] ?? 0.0,
                    ),
                    zoom: 14,
                    markers: _markers,
                    onMapCreated: (controller) {
                      _mapController = controller;
                    },
                  ),

                  // Panel de información
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: _estadoServicio == 'buscando'
                        ? _buildBuscandoConductor()
                        : _buildPanelInfo(),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildBuscandoConductor() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey.shade900 : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 10,
            offset: Offset(0, -2),
          ),
        ],
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final estadosTexto = {
      'aceptado': 'Conductor en camino',
      'en_camino': 'Conductor en camino',
      'llegue': 'Conductor ha llegado',
      'en_curso': 'Viaje en curso',
    };

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey.shade900 : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 10,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Estado
          Text(
            estadosTexto[_estadoServicio] ?? 'Servicio activo',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.blue,
            ),
          ),
          const SizedBox(height: 15),

          // Info del conductor
          if (_conductor != null) ...[
            Row(
              children: [
                // Avatar con foto o icono por defecto
                _buildConductorAvatar(),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _conductor?['conductor_nombre'] ?? _conductor?['nombre'] ?? 'Conductor',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Row(
                        children: [
                          const Icon(Icons.star, color: Colors.amber, size: 18),
                          const SizedBox(width: 5),
                          Text(
                            '${_conductor?['conductor_calificacion'] ?? _conductor?['calificacion'] ?? 5.0}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.phone, color: Colors.green, size: 30),
                  onPressed: () {
                    // TODO: Llamar al conductor
                  },
                ),
              ],
            ),
            const SizedBox(height: 15),

            // Info del vehículo
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey.shade800 : Colors.grey[100],
                borderRadius: BorderRadius.circular(10),
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
                      Text(_conductor?['vehiculo_color'] ?? ''),
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
                      _conductor?['vehiculo_placa'] ?? '',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  void dispose() {
    _pusherService.dispose();
    super.dispose();
  }
}
