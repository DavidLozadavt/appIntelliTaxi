import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intellitaxi/features/rides/data/servicio_activo_model.dart';
import 'package:intellitaxi/core/theme/app_colors.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

class ActiveServiceScreen extends StatefulWidget {
  final ServicioActivo servicio;
  final VoidCallback? onServiceCompleted;

  const ActiveServiceScreen({
    super.key,
    required this.servicio,
    this.onServiceCompleted,
  });

  @override
  State<ActiveServiceScreen> createState() => _ActiveServiceScreenState();
}

class _ActiveServiceScreenState extends State<ActiveServiceScreen> {
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};

  @override
  void initState() {
    super.initState();
    _initializeMap();
  }

  void _initializeMap() {
    _markers = {
      // Marcador de origen
      Marker(
        markerId: const MarkerId('origen'),
        position: LatLng(widget.servicio.origenLat, widget.servicio.origenLng),
        infoWindow: InfoWindow(
          title: 'Origen',
          snippet: widget.servicio.origenAddress,
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
      ),
      // Marcador de destino
      Marker(
        markerId: const MarkerId('destino'),
        position: LatLng(
          widget.servicio.destinoLat,
          widget.servicio.destinoLng,
        ),
        infoWindow: InfoWindow(
          title: 'Destino',
          snippet: widget.servicio.destinoAddress,
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      ),
    };

    // Si hay conductor, agregar su marcador
    if (widget.servicio.conductor != null &&
        widget.servicio.conductor!.lat != null &&
        widget.servicio.conductor!.lng != null) {
      _markers.add(
        Marker(
          markerId: const MarkerId('conductor'),
          position: LatLng(
            widget.servicio.conductor!.lat!,
            widget.servicio.conductor!.lng!,
          ),
          infoWindow: InfoWindow(
            title: widget.servicio.conductor!.nombre,
            snippet: 'Conductor',
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        ),
      );
    }
  }

  Color _getStateColor() {
    switch (widget.servicio.idEstado) {
      case 1:
        return Colors.orange; // Pendiente
      case 2:
        return Colors.blue; // Aceptado
      case 3:
        return Colors.green; // En camino
      case 4:
        return Colors.purple; // Llegué
      case 5:
        return Colors.green; // En curso
      case 6:
        return Colors.grey; // Finalizado
      case 7:
        return Colors.red; // Cancelado
      default:
        return Colors.grey;
    }
  }

  IconData _getStateIcon() {
    switch (widget.servicio.idEstado) {
      case 1:
        return Iconsax.clock_copy;
      case 2:
        return Iconsax.tick_circle_copy;
      case 3:
        return Iconsax.car_copy;
      case 4:
        return Iconsax.location_copy;
      case 5:
        return Iconsax.routing_2_copy;
      case 6:
        return Iconsax.flag_copy;
      case 7:
        return Iconsax.close_circle_copy;
      default:
        return Iconsax.info_circle_copy;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text('Servicio #${widget.servicio.id}'),
        backgroundColor: _getStateColor(),
      ),
      body: Stack(
        children: [
          // Mapa
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: LatLng(
                widget.servicio.origenLat,
                widget.servicio.origenLng,
              ),
              zoom: 14,
            ),
            markers: _markers,
            polylines: _polylines,
            onMapCreated: (controller) {
              _mapController = controller;
            },
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            zoomControlsEnabled: false,
          ),

          // Panel inferior con información
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? Colors.grey.shade900 : Colors.white,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Handle
                  Container(
                    margin: const EdgeInsets.only(top: 12),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Estado del servicio
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _getStateColor().withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _getStateColor().withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _getStateIcon(),
                          color: _getStateColor(),
                          size: 32,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.servicio.estado.estado,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: _getStateColor(),
                                ),
                              ),
                              Text(
                                _getStateMessage(),
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  if (widget.servicio.conductor != null) ...[
                    const SizedBox(height: 16),
                    _buildConductorInfo(),
                  ],

                  const SizedBox(height: 16),
                  _buildTripInfo(),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getStateMessage() {
    switch (widget.servicio.idEstado) {
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

  Widget _buildConductorInfo() {
    final conductor = widget.servicio.conductor!;
    final vehiculo = widget.servicio.vehiculo;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: AppColors.accent,
                child: conductor.foto != null
                    ? ClipOval(
                        child: Image.network(
                          conductor.foto!,
                          width: 60,
                          height: 60,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(
                            Iconsax.user_copy,
                            color: Colors.white,
                            size: 30,
                          ),
                        ),
                      )
                    : const Icon(
                        Iconsax.user_copy,
                        color: Colors.white,
                        size: 30,
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      conductor.nombre,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (conductor.calificacion != null)
                      Row(
                        children: [
                          const Icon(Icons.star, color: Colors.amber, size: 16),
                          const SizedBox(width: 4),
                          Text(
                            conductor.calificacion!.toStringAsFixed(1),
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              if (conductor.telefono != null)
                IconButton(
                  onPressed: () {
                    // TODO: Llamar al conductor
                  },
                  icon: const Icon(Iconsax.call_copy, color: AppColors.accent),
                ),
            ],
          ),
          if (vehiculo != null) ...[
            const Divider(height: 24),
            Row(
              children: [
                const Icon(Iconsax.car_copy, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${vehiculo.marca ?? ''} ${vehiculo.modelo ?? ''} ${vehiculo.color ?? ''}'
                        .trim(),
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
                if (vehiculo.placa != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      vehiculo.placa!,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTripInfo() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.green.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          // Origen
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 2),
                width: 12,
                height: 12,
                decoration: const BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Origen',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    Text(
                      widget.servicio.origenAddress,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          Container(
            margin: const EdgeInsets.only(left: 5),
            width: 2,
            height: 20,
            color: Colors.grey.shade300,
          ),

          // Destino
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 2),
                width: 12,
                height: 12,
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Destino',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    Text(
                      widget.servicio.destinoAddress,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const Divider(height: 24),

          // Info adicional
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              if (widget.servicio.distanciaTexto != null)
                _buildInfoChip(
                  Iconsax.routing_copy,
                  widget.servicio.distanciaTexto!,
                ),
              if (widget.servicio.duracionTexto != null)
                _buildInfoChip(
                  Iconsax.clock_copy,
                  widget.servicio.duracionTexto!,
                ),
              _buildInfoChip(
                Iconsax.dollar_circle_copy,
                '\$${widget.servicio.precioEstimado.toStringAsFixed(0)}',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: Colors.grey.shade600),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey.shade700,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }
}
