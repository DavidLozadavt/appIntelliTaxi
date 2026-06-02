import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart' as fm;
import 'package:intellitaxi/core/map/camera.dart';
import 'package:intellitaxi/core/map/lat_lng.dart';
import 'package:latlong2/latlong.dart' as ll;

/// Controlador de mapa OSM (nombre conservado para migración gradual).
class GoogleMapController {
  GoogleMapController(this._mapController);

  final fm.MapController _mapController;

  fm.MapController get mapController => _mapController;

  /// Compatibilidad: el [MapController] real lo posee [StandardMap].
  void dispose() {}

  Future<void> animateCamera(CameraUpdate update) =>
      _applyCameraUpdate(update);

  Future<void> moveCamera(CameraUpdate update) =>
      _applyCameraUpdate(update);

  Future<void> _applyCameraUpdate(CameraUpdate update) async {
    switch (update.kind) {
      case CameraUpdateKind.latLng:
        final p = update.position!;
        final zoom = _mapController.camera.zoom;
        _mapController.move(
          _toLatLong(p.target),
          zoom > 0 ? zoom : 15,
        );
        if (p.bearing != 0) {
          _mapController.rotate(p.bearing);
        }
      case CameraUpdateKind.latLngZoom:
        final p = update.position!;
        _mapController.move(
          _toLatLong(p.target),
          p.zoom > 0 ? p.zoom : 15,
        );
        if (p.bearing != 0) {
          _mapController.rotate(p.bearing);
        }
      case CameraUpdateKind.cameraPosition:
        final p = update.position!;
        _mapController.move(
          _toLatLong(p.target),
          p.zoom > 0 ? p.zoom : _mapController.camera.zoom,
        );
        if (p.bearing != 0) {
          _mapController.rotate(p.bearing);
        }
      case CameraUpdateKind.latLngBounds:
        final b = update.bounds!;
        final bounds = fm.LatLngBounds(
          ll.LatLng(b.southwest.latitude, b.southwest.longitude),
          ll.LatLng(b.northeast.latitude, b.northeast.longitude),
        );
        _mapController.fitCamera(
          fm.CameraFit.bounds(
            bounds: bounds,
            padding: EdgeInsets.all(update.padding),
          ),
        );
    }
  }

  ll.LatLng _toLatLong(LatLng p) => ll.LatLng(p.latitude, p.longitude);
}
