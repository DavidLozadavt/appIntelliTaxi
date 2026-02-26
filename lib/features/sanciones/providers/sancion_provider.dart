import 'package:flutter/material.dart';
import 'package:intellitaxi/features/sanciones/data/sancion_model.dart';
import 'package:intellitaxi/features/sanciones/services/sancion_service.dart';

class SancionProvider extends ChangeNotifier {
  final SancionService _sancionService = SancionService();

  List<Sancion> _sanciones = [];
  bool _isLoading = false;
  String? _error;

  List<Sancion> get sanciones => _sanciones;
  bool get isLoading => _isLoading;
  String? get error => _error;

  List<Sancion> get sancionesActivas =>
      _sanciones.where((s) => s.estaActiva).toList();

  /// Calcula el porcentaje de riesgo de 0.0 a 1.0
  double get porcentajeRiesgo {
    final activas = sancionesActivas;
    if (activas.isEmpty) return 0.0;

    double puntos = 0;
    for (final s in activas) {
      switch (s.gravedad.toUpperCase()) {
        case 'GRAVE':
          puntos += 4;
          break;
        case 'ALTO':
          puntos += 2;
          break;
        case 'BAJO':
        default:
          puntos += 1;
          break;
      }
    }
    // Tope en 10 puntos = 100%
    return (puntos / 10).clamp(0.0, 1.0);
  }

  /// Nivel de riesgo textual
  String get nivelRiesgo {
    final p = porcentajeRiesgo;
    if (p == 0) return 'Sin sanciones activas';
    if (p <= 0.2) return 'Precaución';
    if (p <= 0.5) return 'Advertencia';
    return 'Peligro de bloqueo';
  }

  Future<void> cargarSanciones() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _sanciones = await _sancionService.getMisSanciones();
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
    }

    _isLoading = false;
    notifyListeners();
  }
}
