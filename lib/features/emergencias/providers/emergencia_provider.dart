import 'package:flutter/material.dart';

import '../data/emergencia_model.dart';
import '../services/emergencia_service.dart';

class EmergenciaProvider extends ChangeNotifier {
  final EmergenciaService _api = EmergenciaService();

  bool _isLoading = false;
  EmergenciaModel? _ultimaEmergencia;
  String? _lastError;
  List<EmergenciaModel> _emergenciasActivas = [];

  bool get isLoading => _isLoading;
  EmergenciaModel? get ultimaEmergencia => _ultimaEmergencia;
  bool get estaEnEmergencia => _ultimaEmergencia?.isActiva == true;
  String? get lastError => _lastError;
  List<EmergenciaModel> get emergenciasActivas =>
      List.unmodifiable(_emergenciasActivas);

  /// Pedir apoyo — el front solo manda lat/lng; dirección la resuelve el backend.
  Future<bool> enviarApoyoRapido({
    required int idVehiculo,
    required int idTurno,
    required double lat,
    required double lng,
    String? placa,
    String mensaje = 'Necesito apoyo',
  }) {
    final msg = placa != null && placa.isNotEmpty
        ? '$mensaje · $placa'
        : mensaje;
    return enviarEmergencia(
      idVehiculo: idVehiculo,
      idTurno: idTurno,
      lat: lat,
      lng: lng,
      mensaje: msg,
    );
  }

  Future<bool> enviarEmergencia({
    required int idVehiculo,
    required int idTurno,
    required double lat,
    required double lng,
    String? mensaje,
  }) async {
    final provisional = EmergenciaModel(
      id: -1,
      idVehiculo: idVehiculo,
      idTurno: idTurno,
      lat: lat,
      lng: lng,
      tipo: 'EMERGENCIA',
      mensaje: mensaje,
      estado: 'activa',
      createdAt: DateTime.now(),
    );

    try {
      _isLoading = true;
      _lastError = null;
      _ultimaEmergencia = provisional;
      _upsertActiva(provisional);
      notifyListeners();

      final emergencia = await _api.crearEmergencia(
        idVehiculo: idVehiculo,
        idTurno: idTurno,
        lat: lat,
        lng: lng,
        mensaje: mensaje,
      );

      _ultimaEmergencia = emergencia;
      _emergenciasActivas.removeWhere((e) => e.id <= 0);
      _upsertActiva(emergencia);
      return true;
    } catch (e) {
      _lastError = e.toString().replaceAll('Exception: ', '').trim();
      debugPrint(_lastError);
      _ultimaEmergencia = null;
      _emergenciasActivas.removeWhere((e) => e.id <= 0);
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> cargarEmergenciasActivas() async {
    try {
      final list = await _api.listarActivas();
      _emergenciasActivas = list;
      notifyListeners();
    } catch (e) {
      debugPrint('⚠️ cargarEmergenciasActivas: $e');
    }
  }

  /// Pusher `emergencia.activa` o FCM.
  void registrarEmergenciaRemota(Map<String, dynamic> payload) {
    try {
      final model = EmergenciaModel.fromJson(payload);
      if (model.id <= 0) return;
      _upsertActiva(model);
      notifyListeners();
    } catch (e) {
      debugPrint('⚠️ registrarEmergenciaRemota: $e');
    }
  }

  /// Pusher `emergencia.finalizada`.
  void finalizarEmergenciaRemota(int idEmergencia) {
    _emergenciasActivas.removeWhere((e) => e.id == idEmergencia);
    if (_ultimaEmergencia?.id == idEmergencia) {
      _ultimaEmergencia = null;
    }
    notifyListeners();
  }

  void _upsertActiva(EmergenciaModel model) {
    if (!model.isActiva) return;
    final idx = _emergenciasActivas.indexWhere((e) => e.id == model.id);
    if (idx >= 0) {
      _emergenciasActivas[idx] = model;
    } else {
      _emergenciasActivas.add(model);
    }
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
      _emergenciasActivas.removeWhere((e) => e.id == emergencia.id);
      return true;
    } catch (e) {
      _lastError = e.toString().replaceAll('Exception: ', '').trim();
      debugPrint(_lastError);
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
