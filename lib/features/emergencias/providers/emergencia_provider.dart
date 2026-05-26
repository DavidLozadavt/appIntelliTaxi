import 'package:flutter/material.dart';

import '../data/emergencia_model.dart';
import '../services/emergencia_service.dart';

class EmergenciaProvider extends ChangeNotifier {
  final EmergenciaService _api = EmergenciaService();

  bool _isLoading = false;

  EmergenciaModel? _ultimaEmergencia;
  String? _tipoEmergenciaActiva;
  String? _lastError;

  bool get isLoading => _isLoading;

  EmergenciaModel? get ultimaEmergencia => _ultimaEmergencia;
  bool get estaEnEmergencia => _ultimaEmergencia != null;
  String? get tipoEmergenciaActiva => _tipoEmergenciaActiva;
  String? get lastError => _lastError;

  /// Un solo tipo de alerta: apoyo con ubicación para central y flota.
  Future<bool> enviarApoyoRapido({
    required int idConductor,
    required int idVehiculo,
    required int idTurno,
    required double lat,
    required double lng,
    String? placa,
  }) {
    final descripcion = placa != null && placa.isNotEmpty
        ? 'Conductor $placa necesita apoyo en $lat, $lng'
        : 'Conductor necesita apoyo en $lat, $lng';

    return enviarEmergencia(
      idConductor: idConductor,
      idVehiculo: idVehiculo,
      idTurno: idTurno,
      lat: lat,
      lng: lng,
      tipo: 'APOYO',
      descripcion: descripcion,
      silenciosa: false,
    );
  }

  Future<bool> enviarEmergencia({
    required int idConductor,
    required int idVehiculo,
    required int idTurno,
    required double lat,
    required double lng,
    required String tipo,
    String? descripcion,
    bool silenciosa = true,
  }) async {
    try {
      _isLoading = true;
      _lastError = null;

      notifyListeners();

      final emergencia = await _api.crearEmergencia(
        idConductor: idConductor,
        idVehiculo: idVehiculo,
        idTurno: idTurno,
        lat: lat,
        lng: lng,
        tipo: tipo,
        descripcion: descripcion,
        silenciosa: silenciosa,
      );

      _ultimaEmergencia = emergencia;
      _tipoEmergenciaActiva = tipo;

      return true;
    } catch (e) {
      _lastError = e.toString().replaceAll('Exception: ', '').trim();
      debugPrint(e.toString());

      return false;
    } finally {
      _isLoading = false;

      notifyListeners();
    }
  }

  void marcarEmergenciaAtendida() {
    _ultimaEmergencia = null;
    _tipoEmergenciaActiva = null;
    notifyListeners();
  }

  Future<bool> finalizarEmergenciaActiva() async {
    final emergencia = _ultimaEmergencia;
    if (emergencia == null) return false;

    try {
      _isLoading = true;
      _lastError = null;
      notifyListeners();

      final ok = await _api.finalizarEmergencia(emergencia.id);
      if (!ok) {
        _lastError = 'No se pudo finalizar la emergencia';
        return false;
      }

      _ultimaEmergencia = null;
      _tipoEmergenciaActiva = null;
      return true;
    } catch (e) {
      _lastError = e.toString().replaceAll('Exception: ', '').trim();
      debugPrint(e.toString());
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
