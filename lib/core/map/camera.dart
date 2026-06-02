import 'package:intellitaxi/core/map/lat_lng.dart';
import 'package:intellitaxi/core/map/lat_lng_bounds.dart';

class CameraPosition {
  const CameraPosition({
    required this.target,
    this.zoom = 0,
    this.tilt = 0,
    this.bearing = 0,
  });

  final LatLng target;
  final double zoom;
  final double tilt;
  final double bearing;
}

enum CameraUpdateKind {
  latLng,
  latLngZoom,
  latLngBounds,
  cameraPosition,
}

/// Actualización de cámara (API compatible con Google Maps).
class CameraUpdate {
  const CameraUpdate._(this.kind, {this.position, this.bounds, this.padding = 0});

  final CameraUpdateKind kind;
  final CameraPosition? position;
  final LatLngBounds? bounds;
  final double padding;

  factory CameraUpdate.newLatLng(LatLng latLng) {
    return CameraUpdate._(
      CameraUpdateKind.latLng,
      position: CameraPosition(target: latLng),
    );
  }

  factory CameraUpdate.newLatLngZoom(LatLng latLng, double zoom) {
    return CameraUpdate._(
      CameraUpdateKind.latLngZoom,
      position: CameraPosition(target: latLng, zoom: zoom),
    );
  }

  factory CameraUpdate.newLatLngBounds(LatLngBounds bounds, double padding) {
    return CameraUpdate._(
      CameraUpdateKind.latLngBounds,
      bounds: bounds,
      padding: padding,
    );
  }

  factory CameraUpdate.newCameraPosition(CameraPosition position) {
    return CameraUpdate._(
      CameraUpdateKind.cameraPosition,
      position: position,
    );
  }
}
