import 'package:flutter/material.dart';
import 'package:intellitaxi/core/map/bitmap_descriptor.dart';
import 'package:intellitaxi/core/map/lat_lng.dart';

class MarkerId {
  const MarkerId(this.value);
  final String value;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is MarkerId && value == other.value;

  @override
  int get hashCode => value.hashCode;
}

class InfoWindow {
  const InfoWindow({this.title, this.snippet});
  final String? title;
  final String? snippet;
}

class Marker {
  const Marker({
    required this.markerId,
    required this.position,
    this.icon = BitmapDescriptor.defaultMarker,
    this.rotation = 0,
    this.anchor = const Offset(0.5, 1.0),
    this.flat = false,
    this.infoWindow = const InfoWindow(),
    this.zIndexInt = 0,
    this.visible = true,
    this.alpha = 1.0,
    this.consumeTapEvents = false,
    this.onTap,
    this.draggable = false,
  });

  final MarkerId markerId;
  final LatLng position;
  final BitmapDescriptor icon;
  final double rotation;
  final Offset anchor;
  final bool flat;
  final InfoWindow infoWindow;
  final int zIndexInt;
  final bool visible;
  final double alpha;
  final bool consumeTapEvents;
  final VoidCallback? onTap;
  final bool draggable;
}
