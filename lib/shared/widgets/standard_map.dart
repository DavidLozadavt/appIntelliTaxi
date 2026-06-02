import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart' as fm;
import 'package:intellitaxi/config/maps_config.dart';
import 'package:intellitaxi/core/map/intellitaxi_maps.dart';
import 'package:intellitaxi/core/map/marker_icon_widget.dart';
import 'package:latlong2/latlong.dart' as ll;

class StandardMap extends StatefulWidget {
  final void Function(GoogleMapController) onMapCreated;
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
  final void Function(CameraPosition)? onCameraMove;
  final VoidCallback? onCameraMoveStarted;
  final VoidCallback? onCameraIdle;
  final void Function(LatLng)? onTap;
  final void Function(LatLng)? onLongPress;
  final MapType mapType;
  final EdgeInsets mapPadding;
  final bool buildingsEnabled;
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
  State<StandardMap> createState() => _StandardMapState();
}

class _StandardMapState extends State<StandardMap> {
  final fm.MapController _mapController = fm.MapController();
  GoogleMapController? _googleCompatController;
  bool _createdCallbackSent = false;
  /// Rumbo del mapa; no leer [_mapController.camera] antes de [onMapReady].
  double _mapBearing = 0;

  @override
  void initState() {
    super.initState();
    _mapBearing = widget.bearing;
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tileUrl = MapsConfig.tileUrlTemplate(isDark: isDark);

    final sortedMarkers = widget.markers.where((m) => m.visible).toList()
      ..sort((a, b) => a.zIndexInt.compareTo(b.zIndexInt));

    return Stack(
      children: [
        fm.FlutterMap(
          mapController: _mapController,
          options: fm.MapOptions(
            initialCenter: ll.LatLng(
              widget.initialPosition.latitude,
              widget.initialPosition.longitude,
            ),
            initialZoom: widget.zoom,
            initialRotation: widget.bearing,
            interactionOptions: fm.InteractionOptions(
              flags: fm.InteractiveFlag.all &
                  (widget.tiltGesturesEnabled
                      ? fm.InteractiveFlag.all
                      : ~fm.InteractiveFlag.rotate),
            ),
            onMapReady: () {
              if (!_createdCallbackSent) {
                _createdCallbackSent = true;
                _googleCompatController ??=
                    GoogleMapController(_mapController);
                widget.onMapCreated(_googleCompatController!);
              }
              final rotation = _mapController.camera.rotation;
              if (rotation != _mapBearing) {
                setState(() => _mapBearing = rotation);
              }
            },
            onPositionChanged: (position, hasGesture) {
              final rotation = position.rotation;
              if (rotation != _mapBearing) {
                setState(() => _mapBearing = rotation);
              }
              if (hasGesture) {
                widget.onCameraMoveStarted?.call();
              }
              widget.onCameraMove?.call(
                CameraPosition(
                  target: LatLng(
                    position.center.latitude,
                    position.center.longitude,
                  ),
                  zoom: position.zoom,
                  bearing: rotation,
                ),
              );
              if (!hasGesture) {
                widget.onCameraIdle?.call();
              }
            },
            onTap: (point, latLng) {
              widget.onTap?.call(
                LatLng(latLng.latitude, latLng.longitude),
              );
            },
            onLongPress: (point, latLng) {
              widget.onLongPress?.call(
                LatLng(latLng.latitude, latLng.longitude),
              );
            },
          ),
          children: [
            fm.TileLayer(
              urlTemplate: tileUrl,
              userAgentPackageName: 'com.example.intellitaxi',
              maxZoom: 19,
            ),
            if (widget.polylines.isNotEmpty)
              fm.PolylineLayer(
                polylines: widget.polylines
                    .where((p) => p.visible && p.points.length >= 2)
                    .map(
                      (p) => fm.Polyline(
                        points: p.points
                            .map(
                              (pt) => ll.LatLng(pt.latitude, pt.longitude),
                            )
                            .toList(),
                        color: p.color.withValues(alpha: 1),
                        strokeWidth: p.width.toDouble(),
                        strokeCap: StrokeCap.round,
                        strokeJoin: StrokeJoin.round,
                      ),
                    )
                    .toList(),
              ),
            fm.MarkerLayer(
              markers: sortedMarkers
                  .map(
                    (m) => fm.Marker(
                      point: ll.LatLng(
                        m.position.latitude,
                        m.position.longitude,
                      ),
                      width: m.icon.width > 0 ? m.icon.width : 48,
                      height: (m.icon.width > 0 ? m.icon.width : 48) * 1.15,
                      alignment: Alignment(
                        (m.anchor.dx * 2) - 1,
                        (m.anchor.dy * 2) - 1,
                      ),
                      child: Opacity(
                        opacity: m.alpha.clamp(0, 1),
                        child: GestureDetector(
                          onTap: m.onTap,
                          behavior: HitTestBehavior.translucent,
                          child: rotatedMarkerChild(
                            rotationDegrees: m.rotation,
                            flat: m.flat,
                            mapBearingDegrees: _mapBearing,
                            child: MarkerIconWidget(descriptor: m.icon),
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
        Positioned(
          left: 8,
          bottom: widget.mapPadding.bottom + 8,
          child: Material(
            color: Colors.black.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(6),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Text(
                '© OpenStreetMap',
                style: TextStyle(color: Colors.white, fontSize: 10),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
