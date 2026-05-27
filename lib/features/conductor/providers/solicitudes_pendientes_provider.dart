import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intellitaxi/core/services/app_logger.dart';
import 'package:intellitaxi/core/utils/json_payload_helper.dart';
import 'package:intellitaxi/features/conductor/providers/conductor_home_provider.dart';
import 'package:intellitaxi/features/conductor/services/conductor_service.dart';
import 'package:intellitaxi/features/conductor/utils/conductor_solicitud_payload_helper.dart';
import 'package:intellitaxi/features/conductor/utils/conductor_solicitud_ranking_helper.dart';
import 'package:intellitaxi/features/taxi/data/taxi_servicio_estado.dart';

/// Lista de servicios publicados sin conductor (pantalla dedicada).
class SolicitudesPendientesProvider extends ChangeNotifier {
  final ConductorService _conductorService = ConductorService();

  final List<Map<String, dynamic>> _pendientes = [];
  bool _cargando = false;
  String? _error;
  bool _enServicio = false;
  bool _enDescanso = false;
  String? _actualizadoEn;
  Timer? _refreshTimer;
  ConductorHomeProvider? _home;
  bool _isDisposed = false;

  List<Map<String, dynamic>> get pendientes {
    final copia = List<Map<String, dynamic>>.from(_pendientes);
    copia.sort(
      (a, b) => ConductorSolicitudRankingHelper.calcularScore(b)
          .compareTo(ConductorSolicitudRankingHelper.calcularScore(a)),
    );
    return copia;
  }

  bool get cargando => _cargando;
  String? get error => _error;
  bool get enServicio => _enServicio;
  bool get enDescanso => _enDescanso;
  String? get actualizadoEn => _actualizadoEn;
  int get total => _pendientes.length;

  void attachHome(ConductorHomeProvider home) {
    if (_home == home) return;
    detachHome();
    _home = home;
    home.addSolicitudTomadaListener(_onSolicitudTomada);
  }

  void detachHome() {
    final home = _home;
    if (home != null) {
      home.removeSolicitudTomadaListener(_onSolicitudTomada);
    }
    _home = null;
  }

  void iniciarRefrescoPeriodico() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(seconds: 25), (_) {
      if (!_isDisposed && !_cargando) {
        unawaited(refrescar(silencioso: true));
      }
    });
  }

  void detenerRefrescoPeriodico() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
  }

  Future<void> refrescar({bool silencioso = false}) async {
    if (_isDisposed) return;
    if (!silencioso) {
      _cargando = true;
      _error = null;
      notifyListeners();
    }

    try {
      final lat = _home?.currentPosition?.latitude;
      final lng = _home?.currentPosition?.longitude;

      final TaxiSolicitudesPendientesResult result =
          await _conductorService.getSolicitudesPendientes(
        lat: lat,
        lng: lng,
      );

      _enServicio = result.enServicio;
      _enDescanso = result.enDescanso;
      _actualizadoEn = result.actualizadoEn;

      if (_enServicio || _enDescanso) {
        _pendientes.clear();
      } else {
        _pendientes
          ..clear()
          ..addAll(
            result.pendientes.map(ConductorSolicitudPayloadHelper.normalizarSolicitud),
          );
      }
      _error = null;
    } catch (e) {
      if (!silencioso) {
        _error = e.toString().replaceAll('Exception: ', '');
      }
      AppLogger.d('⚠️ Error cargando pendientes: $e');
    } finally {
      _cargando = false;
      if (!_isDisposed) notifyListeners();
    }
  }

  void _onSolicitudTomada(String servicioId) {
    final antes = _pendientes.length;
    _pendientes.removeWhere(
      (s) => ConductorSolicitudPayloadHelper.obtenerSolicitudId(s) == servicioId,
    );
    if (antes != _pendientes.length && !_isDisposed) notifyListeners();
  }

  void quitarPorId(String servicioId) => _onSolicitudTomada(servicioId);

  Map<String, dynamic>? buscarPorId(String servicioId) {
    for (final s in _pendientes) {
      if (ConductorSolicitudPayloadHelper.obtenerSolicitudId(s) == servicioId) {
        return s;
      }
    }
    return null;
  }

  double? precioOfertadoDe(Map<String, dynamic> solicitud) {
    final raw = solicitud['precio_ofertado'];
    if (raw == null) return null;
    final v = JsonPayloadHelper.parseDouble(raw);
    return v > 0 ? v : null;
  }

  String distanciaDesdeMi(Map<String, dynamic> solicitud) {
    final km = solicitud['distancia_desde_mi_km'];
    if (km != null) {
      final v = JsonPayloadHelper.parseDouble(km);
      if (v > 0) return '${v.toStringAsFixed(1)} km';
    }
    return solicitud['distancia']?.toString() ?? '';
  }

  String tiempoPublicado(Map<String, dynamic> solicitud) {
    final seg = int.tryParse(
      (solicitud['publicado_hace_segundos'] ?? '').toString(),
    );
    if (seg == null) return '';
    if (seg < 60) return 'Hace ${seg}s';
    if (seg < 3600) return 'Hace ${seg ~/ 60} min';
    return 'Hace ${seg ~/ 3600} h';
  }

  @override
  void dispose() {
    _isDisposed = true;
    detenerRefrescoPeriodico();
    detachHome();
    super.dispose();
  }
}
