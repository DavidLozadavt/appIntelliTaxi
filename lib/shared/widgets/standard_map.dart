import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intellitaxi/core/constants/map_styles.dart';

class StandardMap extends StatelessWidget {
  final Function(GoogleMapController) onMapCreated;
  final LatLng initialPosition;
  final Set<Marker> markers;
  final Set<Polyline> polylines;
  final double zoom;
  final bool myLocationEnabled;
  final bool myLocationButtonEnabled;
  final bool zoomControlsEnabled;
  final bool compassEnabled;
  final Function(CameraPosition)? onCameraMove;
  final VoidCallback? onCameraIdle;
  final MapType mapType;

  const StandardMap({
    super.key,
    required this.onMapCreated,
    required this.initialPosition,
    this.markers = const {},
    this.polylines = const {},
    this.zoom = 14.0,
    this.myLocationEnabled = true,
    this.myLocationButtonEnabled = false,
    this.zoomControlsEnabled = false,
    this.compassEnabled = true,
    this.onCameraMove,
    this.onCameraIdle,
    this.mapType = MapType.normal,
  });

  @override
  Widget build(BuildContext context) {
    return GoogleMap(
      onMapCreated: (GoogleMapController controller) {
        _setMapStyle(controller);
        onMapCreated(controller);
      },
      initialCameraPosition: CameraPosition(
        target: initialPosition,
        zoom: zoom,
      ),
      markers: markers,
      polylines: polylines,
      myLocationEnabled: myLocationEnabled,
      myLocationButtonEnabled: myLocationButtonEnabled,
      zoomControlsEnabled: zoomControlsEnabled,
      compassEnabled: compassEnabled,
      mapType: mapType,
      onCameraMove: onCameraMove,
      onCameraIdle: onCameraIdle,
      padding: const EdgeInsets.only(top: 80, bottom: 100),
    );
  }

  Future<void> _setMapStyle(GoogleMapController controller) async {
    try {
      final isDark =
          WidgetsBinding.instance.platformDispatcher.platformBrightness ==
          Brightness.dark;
      await controller.setMapStyle(
        isDark ? MapStyles.darkMapStyle : MapStyles.lightMapStyle,
      );
    } catch (e) {
      debugPrint('Error aplicando estilo del mapa: $e');
    }
  }
}
