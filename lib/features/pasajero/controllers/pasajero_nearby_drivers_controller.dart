import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
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

  final Map<int, Conductor> conductores = {};
  final Map<int, LatLng> displayedPositions = {};
  Conductor? selectedDirectDriver;
  BitmapDescriptor? driverMarkerIcon;

  static const double lerpFactor = 0.2;
  static const double snapDistanceMeters = 2.0;

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
  }) async {
    try {
      final list = await _conductoresService.getConductoresDisponibles(
        lat: lat,
        lng: lng,
        radioKm: radioKm,
        maxAgeMinutes: maxAgeMinutes,
      );

      final receivedIds = list.map((c) => c.conductorId).toSet();
      for (final conductor in list) {
        conductores[conductor.conductorId] = conductor;
      }

      for (final id in conductores.keys.toList()) {
        if (!receivedIds.contains(id)) {
          conductores.remove(id);
          displayedPositions.remove(id);
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
      displayedPositions[entry.key] = LatLng(entry.value.lat, entry.value.lng);
    }
  }

  void applyDriverUpdate(Conductor conductor, {required bool showDrivers}) {
    if (!showDrivers) return;
    if (conductor.estado?.toLowerCase() == 'desconectado') {
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
  }

  /// Interpola posiciones de marcadores; devuelve true si hubo cambio visual.
  bool tickMarkerAnimation({required bool showDrivers}) {
    if (!showDrivers) return false;
    if (conductores.isEmpty) {
      if (displayedPositions.isNotEmpty) {
        displayedPositions.clear();
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
          changed = true;
        }
        continue;
      }

      final lat =
          current.latitude +
          (target.latitude - current.latitude) * lerpFactor;
      final lng =
          current.longitude +
          (target.longitude - current.longitude) * lerpFactor;
      displayedPositions[id] = LatLng(lat, lng);
      changed = true;
    }

    for (final id in displayedPositions.keys.toList()) {
      if (!conductores.containsKey(id)) {
        displayedPositions.remove(id);
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
      markers.add(
        Marker(
          markerId: MarkerId('driver_${conductor.conductorId}'),
          position: position,
          icon: ocupado
              ? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure)
              : (driverMarkerIcon ??
                    BitmapDescriptor.defaultMarkerWithHue(
                      BitmapDescriptor.hueGreen,
                    )),
          infoWindow: InfoWindow(
            title: '🚗 ${conductor.nombre}',
            snippet:
                '${ocupado ? 'Ocupado • ' : ''}'
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
        const ImageConfiguration(size: Size(48, 48)),
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
    selectedDirectDriver = null;
  }
}
