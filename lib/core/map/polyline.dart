import 'package:flutter/material.dart';
import 'package:intellitaxi/core/map/lat_lng.dart';

class PolylineId {
  const PolylineId(this.value);
  final String value;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PolylineId && value == other.value;

  @override
  int get hashCode => value.hashCode;
}

/// Caps de polilínea (compatibilidad; el render OSM usa trazo redondeado).
class Cap {
  Cap._();
  static final Cap roundCap = Cap._();
  static final Cap buttCap = Cap._();
  static final Cap squareCap = Cap._();
}

class JointType {
  JointType._();
  static final JointType round = JointType._();
  static final JointType bevel = JointType._();
  static final JointType miter = JointType._();
}

/// Patrón de trazo (ignorado en OSM; conservado por compatibilidad).
class PatternItem {
  PatternItem._(this._kind, this._length);

  final _PatternKind _kind;
  final int _length;

  static PatternItem dash(int length) =>
      PatternItem._(_PatternKind.dash, length);

  static PatternItem gap(int length) => PatternItem._(_PatternKind.gap, length);
}

enum _PatternKind { dash, gap }

class Polyline {
  Polyline({
    required this.polylineId,
    required this.points,
    this.color = Colors.black,
    this.width = 10,
    this.visible = true,
    this.zIndex = 0,
    Cap? startCap,
    Cap? endCap,
    JointType? jointType,
    this.patterns = const [],
  })  : startCap = startCap ?? Cap.buttCap,
        endCap = endCap ?? Cap.buttCap,
        jointType = jointType ?? JointType.miter;

  final PolylineId polylineId;
  final List<LatLng> points;
  final Color color;
  final int width;
  final bool visible;
  final int zIndex;
  final Cap startCap;
  final Cap endCap;
  final JointType jointType;
  final List<PatternItem> patterns;
}
