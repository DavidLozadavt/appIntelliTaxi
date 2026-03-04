import 'package:flutter/foundation.dart';

/// Mantiene temporalmente un viaje a repetir entre pantallas.
class RepeatTripService {
  RepeatTripService._();

  static final RepeatTripService instance = RepeatTripService._();

  final ValueNotifier<int> _signal = ValueNotifier<int>(0);
  Map<String, dynamic>? _pendingTrip;

  void addListener(VoidCallback listener) {
    _signal.addListener(listener);
  }

  void removeListener(VoidCallback listener) {
    _signal.removeListener(listener);
  }

  Map<String, dynamic>? get pendingTrip => _pendingTrip;

  void clearPending() {
    _pendingTrip = null;
  }

  void setPendingTrip(Map<String, dynamic> trip) {
    _pendingTrip = trip;
    _signal.value++;
  }
}
