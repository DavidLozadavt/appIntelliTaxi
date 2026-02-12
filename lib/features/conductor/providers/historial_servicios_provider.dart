import 'package:flutter/material.dart';
import 'package:intellitaxi/features/conductor/services/conductor_service.dart';

// TODO: Crear estos modelos cuando estén disponibles:
// - lib/features/conductor/data/servicio_historial_model.dart
// - lib/features/conductor/data/estadisticas_conductor_model.dart

/// Provider para gestionar el historial de servicios del conductor
/// Incluye: carga de historial, filtros, estadísticas
/// 
/// NOTA: Usa Map<String, dynamic> temporalmente hasta que se creen los modelos
class HistorialServiciosProvider extends ChangeNotifier {
  final ConductorService _conductorService = ConductorService();

  // Estado - Usando Map temporalmente
  List<Map<String, dynamic>> _servicios = [];
  Map<String, dynamic>? _estadisticas;
  bool _isLoading = false;
  String? _error;
  String _filtroSeleccionado = 'todos';

  // Getters
  List<Map<String, dynamic>> get servicios => _servicios;
  Map<String, dynamic>? get estadisticas => _estadisticas;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String get filtroSeleccionado => _filtroSeleccionado;

  /// Carga el historial de servicios del conductor
  /// 
  /// TODO: Implementar cuando exista el método en ConductorService
  Future<void> cargarHistorial({
    required int conductorId,
    String? filtro,
  }) async {
    try {
      _isLoading = true;
      _error = null;
      if (filtro != null) {
        _filtroSeleccionado = filtro;
      }
      notifyListeners();

      // TODO: Descomentar cuando exista el método
      // final servicios = await _conductorService.getHistorialServicios(
      //   conductorId,
      //   filtro: _filtroSeleccionado,
      // );
      // _servicios = servicios;

      // Temporalmente retornar lista vacía
      _servicios = [];
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      print('❌ Error cargando historial: $e');
      _error = e.toString().replaceAll('Exception: ', '');
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Carga las estadísticas del conductor
  /// 
  /// TODO: Implementar cuando exista el método en ConductorService
  Future<void> cargarEstadisticas(int conductorId) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      // TODO: Descomentar cuando exista el método
      // final estadisticas = await _conductorService.getEstadisticas(conductorId);
      // _estadisticas = estadisticas;

      // Temporalmente retornar null
      _estadisticas = null;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      print('❌ Error cargando estadísticas: $e');
      _error = e.toString().replaceAll('Exception: ', '');
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Cambia el filtro aplicado
  void cambiarFiltro(String nuevoFiltro) {
    if (_filtroSeleccionado != nuevoFiltro) {
      _filtroSeleccionado = nuevoFiltro;
      notifyListeners();
    }
  }

  /// Limpia el error
  void clearError() {
    _error = null;
    notifyListeners();
  }
}
