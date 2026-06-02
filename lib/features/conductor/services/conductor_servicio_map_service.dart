import 'package:flutter/material.dart';
import 'package:intellitaxi/core/map/intellitaxi_maps.dart';
import 'package:intellitaxi/core/services/app_logger.dart';
import 'package:intellitaxi/core/widgets/map_dot_marker_factory.dart';
import 'package:intellitaxi/features/conductor/utils/conductor_servicio_estado_helper.dart';
import 'package:intellitaxi/features/pasajero/services/routes_service.dart';

/// Mapa del viaje activo del conductor: marcadores y ruta.
class ConductorServicioMapService {
  ConductorServicioMapService({RoutesService? routesService})
      : _routesService = routesService ?? RoutesService();

  final RoutesService _routesService;

  BitmapDescriptor? recogidaDot;
  BitmapDescriptor? destinoFinalDot;

  Future<void> ensureDotMarkers() async {
    recogidaDot ??= await MapDotMarkerFactory.create(
      color: Colors.blue,
      size: 28,
    );
    destinoFinalDot ??= await MapDotMarkerFactory.create(
      color: const Color(0xFFFF6B35),
      size: 28,
    );
  }

  Set<Marker> buildMarkers({
    required Map<String, dynamic> servicio,
    required LatLng? miUbicacion,
    required BitmapDescriptor? carIcon,
    double? miBearing,
  }) {
    final origenLat =
        ConductorServicioEstadoHelper.parseDouble(servicio['origen_lat']);
    final origenLng =
        ConductorServicioEstadoHelper.parseDouble(servicio['origen_lng']);
    final destinoLat =
        ConductorServicioEstadoHelper.parseDouble(servicio['destino_lat']);
    final destinoLng =
        ConductorServicioEstadoHelper.parseDouble(servicio['destino_lng']);
    final tieneDestino =
        ConductorServicioEstadoHelper.tieneDestinoDefinido(servicio);

    final markers = <Marker>{
      Marker(
        markerId: const MarkerId('recogida'),
        position: LatLng(origenLat, origenLng),
        icon: recogidaDot ?? BitmapDescriptor.defaultMarker,
        infoWindow: InfoWindow(
          title: 'Punto de Recogida',
          snippet: servicio['origen_address']?.toString(),
        ),
        anchor: const Offset(0.5, 0.5),
      ),
    };

    if (tieneDestino) {
      markers.add(
        Marker(
          markerId: const MarkerId('destino_final'),
          position: LatLng(destinoLat, destinoLng),
          icon: destinoFinalDot ?? BitmapDescriptor.defaultMarker,
          infoWindow: InfoWindow(
            title: 'Destino Final',
            snippet:
                servicio['destino_address']?.toString() ?? 'Destino no definido',
          ),
          anchor: const Offset(0.5, 0.5),
        ),
      );
    }

    if (miUbicacion != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('mi_ubicacion'),
          position: miUbicacion,
          rotation: miBearing ?? 0,
          flat: true,
          icon: carIcon ??
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          infoWindow: const InfoWindow(title: 'Mi ubicación'),
          anchor: const Offset(0.5, 0.5),
        ),
      );
    }

    return markers;
  }

  Future<Polyline?> buildRoutePolyline({
    required LatLng origin,
    required LatLng destination,
    required Color color,
  }) async {
    try {
      final routeInfo = await _routesService.getRoute(
        origin: origin,
        destination: destination,
      );

      if (routeInfo != null && routeInfo.polylinePoints.isNotEmpty) {
        AppLogger.d(
          '✅ Ruta dibujada: ${routeInfo.distance} - ${routeInfo.duration}',
        );
        return Polyline(
          polylineId: const PolylineId('ruta_actual'),
          points: routeInfo.polylinePoints,
          color: color,
          width: 5,
        );
      }
      AppLogger.d(
        '⚠️ No se recibió polilínea válida; se conserva la ruta anterior',
      );
    } catch (e) {
      AppLogger.d('❌ Error dibujando ruta: $e');
    }
    return null;
  }
}
