import 'package:flutter/material.dart';

import '../data/emergencia_model.dart';
import '../services/emergencia_service.dart';

class EmergenciaProvider extends ChangeNotifier {

  final EmergenciaService _api =
      EmergenciaService();

  bool _isLoading = false;

  EmergenciaModel? _ultimaEmergencia;

  bool get isLoading => _isLoading;

  EmergenciaModel? get ultimaEmergencia =>
      _ultimaEmergencia;

  Future<bool> enviarEmergencia({
    required int idConductor,
    required int idVehiculo,
    required int idTurno,
    required double lat,
    required double lng,
    required String tipo,
    String? descripcion,
  }) async {

    try {

      _isLoading = true;

      notifyListeners();

      final emergencia =
          await _api.crearEmergencia(
        idConductor: idConductor,
        idVehiculo: idVehiculo,
        idTurno: idTurno,
        lat: lat,
        lng: lng,
        tipo: tipo,
        descripcion: descripcion,
      );

      _ultimaEmergencia = emergencia;

      return true;

    } catch (e) {

      debugPrint(e.toString());

      return false;

    } finally {

      _isLoading = false;

      notifyListeners();
    }
  }
}