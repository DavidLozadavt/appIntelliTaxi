import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intellitaxi/core/constants/map_styles.dart';
import 'package:intellitaxi/features/rides/data/trip_location.dart';
import 'package:intellitaxi/features/rides/services/routes_service.dart';

class RideMapScreen extends StatefulWidget {
  final TripLocation origin;
  final TripLocation destination;

  const RideMapScreen({
    super.key,
    required this.origin,
    required this.destination,
  });

  @override
  State<RideMapScreen> createState() => _RideMapScreenState();
}

class _RideMapScreenState extends State<RideMapScreen> {
  GoogleMapController? _mapController;
  final RoutesService _routesService = RoutesService();

  RouteInfo? _routeInfo;
  Set<Polyline> _polylines = {};
  Set<Marker> _markers = {};
  bool _isLoadingRoute = true;

  @override
  void initState() {
    super.initState();
    _loadRoute();
  }

  Future<void> _loadRoute() async {
    setState(() => _isLoadingRoute = true);

    final originLatLng = LatLng(widget.origin.lat, widget.origin.lng);
    final destinationLatLng = LatLng(
      widget.destination.lat,
      widget.destination.lng,
    );

    final routeInfo = await _routesService.getRoute(
      origin: originLatLng,
      destination: destinationLatLng,
    );

    if (routeInfo != null && mounted) {
      setState(() {
        _routeInfo = routeInfo;
        _createPolylines(routeInfo);
        _createMarkers();
        _isLoadingRoute = false;
      });

      // Ajustar cámara para mostrar toda la ruta
      _fitCameraToBounds(routeInfo.polylinePoints);
    } else {
      setState(() => _isLoadingRoute = false);
    }
  }

  void _createPolylines(RouteInfo routeInfo) {
    _polylines = {
      Polyline(
        polylineId: const PolylineId('route'),
        points: routeInfo.polylinePoints,
        color: Colors.deepOrange,
        width: 5,
        startCap: Cap.roundCap,
        endCap: Cap.roundCap,
        jointType: JointType.round,
      ),
    };
  }

  void _createMarkers() {
    _markers = {
      Marker(
        markerId: const MarkerId('origin'),
        position: LatLng(widget.origin.lat, widget.origin.lng),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        infoWindow: InfoWindow(title: 'Origen', snippet: widget.origin.name),
      ),
      Marker(
        markerId: const MarkerId('destination'),
        position: LatLng(widget.destination.lat, widget.destination.lng),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        infoWindow: InfoWindow(
          title: 'Destino',
          snippet: widget.destination.name,
        ),
      ),
    };
  }

  void _fitCameraToBounds(List<LatLng> points) {
    if (_mapController == null || points.isEmpty) return;

    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;

    for (final point in points) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude < minLng) minLng = point.longitude;
      if (point.longitude > maxLng) maxLng = point.longitude;
    }

    final bounds = LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );

    _mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 100));
  }

  Future<void> _setMapStyle(GoogleMapController controller) async {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    try {
      await controller.setMapStyle(
        isDarkMode ? MapStyles.darkMapStyle : MapStyles.lightMapStyle,
      );
    } catch (e) {
      // Ignorar errores de estilo
    }
  }

  void _confirmRide() {
    // Aquí podrías enviar la solicitud al backend
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar viaje'),
        content: Text(
          'Origen: ${widget.origin.name}\n'
          'Destino: ${widget.destination.name}\n'
          'Distancia: ${_routeInfo?.distance ?? 'N/A'}\n'
          'Duración: ${_routeInfo?.duration ?? 'N/A'}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // Cerrar diálogo
              Navigator.pop(context); // Volver atrás
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Buscando conductor cercano...'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Detalles del viaje'), elevation: 0),
      body: Stack(
        children: [
          // Mapa
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: LatLng(widget.origin.lat, widget.origin.lng),
              zoom: 14,
            ),
            polylines: _polylines,
            markers: _markers,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            onMapCreated: (controller) {
              _mapController = controller;
              _setMapStyle(controller);
            },
          ),

          // Loading overlay
          if (_isLoadingRoute)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: const Center(
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text(
                          'Calculando ruta...',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // Panel inferior con información
          if (!_isLoadingRoute && _routeInfo != null)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, -5),
                    ),
                  ],
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Handle
                        Center(
                          child: Container(
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade300,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Información del viaje
                        Row(
                          children: [
                            Expanded(
                              child: _buildInfoCard(
                                icon: Icons.straighten,
                                label: 'Distancia',
                                value: _routeInfo!.distance,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildInfoCard(
                                icon: Icons.access_time,
                                label: 'Duración',
                                value: _routeInfo!.duration,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        // Precio
                        // Nota: No se muestra precio porque funciona con taxímetro
                        const SizedBox(height: 16),

                        // Botón de confirmar
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            onPressed: _confirmRide,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green.shade600,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 0,
                            ),
                            child: const Text(
                              'Solicitar viaje',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // Botón de centrar mapa
          if (!_isLoadingRoute)
            Positioned(
              top: 16,
              right: 16,
              child: FloatingActionButton.small(
                onPressed: () {
                  if (_routeInfo != null) {
                    _fitCameraToBounds(_routeInfo!.polylinePoints);
                  }
                },
                backgroundColor: Colors.white,
                child: const Icon(
                  Icons.center_focus_strong,
                  color: Colors.deepOrange,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300, width: 1),
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.deepOrange, size: 24),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }
}
