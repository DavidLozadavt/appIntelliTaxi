import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intellitaxi/core/constants/map_styles.dart';

class StandardMap extends StatelessWidget {
  final Function(GoogleMapController) onMapCreated;
  final LatLng initialPosition;
  final Set<Marker> markers;
  final Set<Polyline> polylines;
  final double zoom;
  final double tilt;
  final double bearing;
  final bool myLocationEnabled;
  final bool myLocationButtonEnabled;
  final bool zoomControlsEnabled;
  final bool compassEnabled;
  final Function(CameraPosition)? onCameraMove;
  final VoidCallback? onCameraMoveStarted;
  final VoidCallback? onCameraIdle;
  final Function(LatLng)? onTap;
  final Function(LatLng)? onLongPress;
  final MapType mapType;
  final EdgeInsets mapPadding;
  /// Edificios 3D de Google Maps (desactivado = vista plana).
  final bool buildingsEnabled;
  /// Permite inclinar el mapa con gestos (desactivado = siempre plano).
  final bool tiltGesturesEnabled;

  const StandardMap({
    super.key,
    required this.onMapCreated,
    required this.initialPosition,
    this.markers = const {},
    this.polylines = const {},
    this.zoom = 14.0,
    this.tilt = 0.0,
    this.bearing = 0.0,
    this.myLocationEnabled = true,
    this.myLocationButtonEnabled = false,
    this.zoomControlsEnabled = false,
    this.compassEnabled = true,
    this.buildingsEnabled = false,
    this.tiltGesturesEnabled = false,
    this.onCameraMove,
    this.onCameraMoveStarted,
    this.onCameraIdle,
    this.onTap,
    this.onLongPress,
    this.mapType = MapType.normal,
    this.mapPadding = const EdgeInsets.only(top: 80, bottom: 100),
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GoogleMap(
      onMapCreated: onMapCreated,
      initialCameraPosition: CameraPosition(
        target: initialPosition,
        zoom: zoom,
        tilt: tilt,
        bearing: bearing,
      ),
      style: isDark ? MapStyles.darkMapStyle : MapStyles.lightMapStyle,
      markers: markers,
      polylines: polylines,
      myLocationEnabled: myLocationEnabled,
      myLocationButtonEnabled: myLocationButtonEnabled,
      zoomControlsEnabled: zoomControlsEnabled,
      compassEnabled: compassEnabled,
      mapType: mapType,
      buildingsEnabled: buildingsEnabled,
      tiltGesturesEnabled: tiltGesturesEnabled,
      fortyFiveDegreeImageryEnabled: false,
      onCameraMove: onCameraMove,
      onCameraMoveStarted: onCameraMoveStarted,
      onCameraIdle: onCameraIdle,
      onTap: onTap,
      onLongPress: onLongPress,
      padding: mapPadding,
    );
  }
}
