import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intellitaxi/core/geo/map_marker_bearing_helper.dart';
import 'package:intellitaxi/core/services/app_logger.dart';
import 'package:intellitaxi/features/conductor/data/conductor_model.dart';
import 'package:intellitaxi/features/conductor/services/conductores_service.dart';
import 'package:intellitaxi/features/conductor/services/pusher_conductores_service.dart';

/// Conductores cercanos en el mapa del pasajero (API + Pusher + animación).
class PasajeroNearbyDriversController {
  PasajeroNearbyDriversController({
    ConductoresService? conductoresService,
  }) : _conductoresService = conductoresService ?? ConductoresService();

  final ConductoresService _conductoresService;
  PusherConductoresService? _pusher;

  DateTime? _lastApiLoadAt;
  static const Duration _minApiInterval = Duration(seconds: 10);

  final Map<int, Conductor> conductores = {};
  final Map<int, LatLng> displayedPositions = {};
  final Map<int, double> displayedBearings = {};
  final Map<int, bool> _bearingInitialized = {};
  Conductor? selectedDirectDriver;
  BitmapDescriptor? driverMarkerIcon;

  static const double lerpFactor = 0.2;
  static const double snapDistanceMeters = 2.0;
  static const double bearingSmoothFactor = 0.28;

  bool get hasConductores => conductores.isNotEmpty;

  Future<void> connectPusher({
    int idEmpresa = 1,
    required void Function(Conductor conductor) onDriverUpdate,
    required void Function(int conductorId) onDriverOffline,
  }) async {
    try {
      _pusher = PusherConductoresService(idEmpresa: idEmpresa);
      _pusher!.onDriverUpdate = onDriverUpdate;
      _pusher!.onDriverOffline = onDriverOffline;
      await _pusher!.connect();
      AppLogger.d('✅ Pusher conductores configurado');
    } catch (e) {
      AppLogger.d('❌ Error configurando Pusher conductores: $e');
    }
  }

  Future<void> loadFromApi({
    required double lat,
    required double lng,
    double radioKm = 15,
    int maxAgeMinutes = 20,
    bool silent = false,
    bool force = false,
  }) async {
    final now = DateTime.now();
    if (!force &&
        _lastApiLoadAt != null &&
        now.difference(_lastApiLoadAt!) < _minApiInterval) {
      return;
    }
    _lastApiLoadAt = now;

    try {
      final list = await _conductoresService.getConductoresDisponibles(
        lat: lat,
        lng: lng,
        radioKm: radioKm,
        maxAgeMinutes: maxAgeMinutes,
        quiet: silent,
      );

      final receivedIds = list.map((c) => c.conductorId).toSet();
      for (final conductor in list) {
        if (!conductor.debeMostrarseEnMapa) continue;
        conductores[conductor.conductorId] = conductor;
      }

      for (final id in conductores.keys.toList()) {
        if (!receivedIds.contains(id)) {
          conductores.remove(id);
          displayedPositions.remove(id);
          displayedBearings.remove(id);
          _bearingInitialized.remove(id);
          if (selectedDirectDriver?.conductorId == id) {
            selectedDirectDriver = null;
          }
        }
      }

      seedDisplayedPositions();
      if (!silent) {
        AppLogger.d('✅ ${list.length} conductores en mapa');
      }
    } catch (e) {
      if (!silent) {
        AppLogger.d('❌ Error cargando conductores: $e');
      }
    }
  }

  void seedDisplayedPositions() {
    for (final entry in conductores.entries) {
      final id = entry.key;
      final conductor = entry.value;
      final pos = LatLng(conductor.lat, conductor.lng);
      displayedPositions[id] = pos;
      _syncBearingForConductor(id, conductor, pos, previous: null);
    }
  }

  void _syncBearingForConductor(
    int id,
    Conductor conductor,
    LatLng position, {
    LatLng? previous,
  }) {
    final objetivo = MapMarkerBearingHelper.resolveBearing(
      to: position,
      from: previous,
      backendRumbo: conductor.rumbo,
      fallback: displayedBearings[id],
    );
    final suavizado = MapMarkerBearingHelper.smoothBearing(
      current: displayedBearings[id] ?? objetivo,
      target: objetivo,
      factor: bearingSmoothFactor,
      initialized: _bearingInitialized[id] ?? false,
    );
    displayedBearings[id] = suavizado;
    _bearingInitialized[id] = true;
  }

  void applyDriverUpdate(Conductor conductor, {required bool showDrivers}) {
    if (!showDrivers) return;
    final estado = conductor.estado?.toLowerCase();
    if (!conductor.debeMostrarseEnMapa ||
        estado == 'desconectado' ||
        estado == 'descanso' ||
        estado == 'ocupado') {
      removeDriver(conductor.conductorId);
      return;
    }
    if (selectedDirectDriver?.conductorId == conductor.conductorId &&
        conductor.estado?.toLowerCase() != 'disponible') {
      selectedDirectDriver = null;
    }
    conductores[conductor.conductorId] = conductor;
    if (!displayedPositions.containsKey(conductor.conductorId)) {
      displayedPositions[conductor.conductorId] = LatLng(
        conductor.lat,
        conductor.lng,
      );
    }
  }

  void removeDriver(int conductorId) {
    if (selectedDirectDriver?.conductorId == conductorId) {
      selectedDirectDriver = null;
    }
    conductores.remove(conductorId);
    displayedPositions.remove(conductorId);
    displayedBearings.remove(conductorId);
    _bearingInitialized.remove(conductorId);
  }

  /// Interpola posiciones de marcadores; devuelve true si hubo cambio visual.
  bool tickMarkerAnimation({required bool showDrivers}) {
    if (!showDrivers) return false;
    if (conductores.isEmpty) {
      if (displayedPositions.isNotEmpty) {
        displayedPositions.clear();
        displayedBearings.clear();
        _bearingInitialized.clear();
        return true;
      }
      return false;
    }

    var changed = false;

    for (final entry in conductores.entries) {
      final id = entry.key;
      final target = LatLng(entry.value.lat, entry.value.lng);
      final current = displayedPositions[id];

      if (current == null) {
        displayedPositions[id] = target;
        _syncBearingForConductor(id, entry.value, target, previous: null);
        changed = true;
        continue;
      }

      final movedMeters = Geolocator.distanceBetween(
        current.latitude,
        current.longitude,
        target.latitude,
        target.longitude,
      );

      if (movedMeters < snapDistanceMeters) {
        if (current.latitude != target.latitude ||
            current.longitude != target.longitude) {
          displayedPositions[id] = target;
          _syncBearingForConductor(id, entry.value, target, previous: current);
          changed = true;
        }
        continue;
      }

      final next = MapMarkerBearingHelper.advanceToward(
        current,
        target,
        lerpFactor,
      );
      displayedPositions[id] = next;
      _syncBearingForConductor(id, entry.value, next, previous: current);
      changed = true;
    }

    for (final id in displayedPositions.keys.toList()) {
      if (!conductores.containsKey(id)) {
        displayedPositions.remove(id);
        displayedBearings.remove(id);
        _bearingInitialized.remove(id);
        changed = true;
      }
    }

    return changed;
  }

  Set<Marker> buildDriverMarkers({
    required bool showDrivers,
    void Function(Conductor conductor)? onTap,
  }) {
    if (!showDrivers) return {};

    final markers = <Marker>{};
    for (final conductor in conductores.values) {
      final position = displayedPositions[conductor.conductorId] ??
          LatLng(conductor.lat, conductor.lng);
      final ocupado = conductor.estado?.toLowerCase() == 'ocupado';
      if (ocupado) continue;
      final rotation = displayedBearings[conductor.conductorId] ?? 0;
      markers.add(
        Marker(
          markerId: MarkerId('driver_${conductor.conductorId}'),
          position: position,
          rotation: rotation,
          flat: true,
          anchor: const Offset(0.5, 0.5),
          icon: driverMarkerIcon ??
              BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueGreen,
              ),
          infoWindow: InfoWindow(
            title: '🚗 ${conductor.nombre}',
            snippet:
                '⭐ ${conductor.calificacion.toStringAsFixed(1)} • '
                '${conductor.vehiculo?.descripcion ?? 'Sin vehículo'}',
          ),
          onTap: onTap != null ? () => onTap(conductor) : null,
          zIndexInt: 1,
        ),
      );
    }
    return markers;
  }

  Future<void> loadDriverMarkerIcon() async {
    try {
      driverMarkerIcon = await BitmapDescriptor.asset(
        const ImageConfiguration(size: Size(30, 30)),
        'assets/images/marker.png',
      );
    } catch (e) {
      AppLogger.d('Error creando icono de conductor: $e');
      driverMarkerIcon = BitmapDescriptor.defaultMarkerWithHue(
        BitmapDescriptor.hueGreen,
      );
    }
  }

  void dispose() {
    _pusher?.disconnect();
    _pusher = null;
    conductores.clear();
    displayedPositions.clear();
    displayedBearings.clear();
    _bearingInitialized.clear();
    selectedDirectDriver = null;
  }
}
