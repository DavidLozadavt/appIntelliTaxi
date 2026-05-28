import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intellitaxi/core/services/app_logger.dart';
import 'package:intellitaxi/core/utils/json_payload_helper.dart';
import 'package:intellitaxi/features/conductor/providers/conductor_home_provider.dart';

/// Lista «En espera» delegada al mapa canónico de [ConductorHomeProvider].
class SolicitudesPendientesProvider extends ChangeNotifier {
  ConductorHomeProvider? _home;
  bool _cargando = false;
  String? _error;
  Timer? _refreshTimer;
  bool _isDisposed = false;

  List<Map<String, dynamic>> get pendientes =>
      _home?.solicitudesEnEsperaOrdenadas ?? const [];

  bool get cargando => _cargando;
  String? get error => _error;
  bool get enServicio => _home?.enServicio ?? false;
  bool get enDescanso => _home?.enDescanso ?? false;
  String? get actualizadoEn => _home?.ultimaSyncSolicitudesEn;
  int get total => _home?.totalSolicitudesEnEspera ?? 0;

  void attachHome(ConductorHomeProvider home) {
    if (_home == home) return;
    detachHome();
    _home = home;
    home.addSolicitudTomadaListener(_onSolicitudTomada);
    home.addListener(_onHomeChanged);
  }

  void detachHome() {
    final home = _home;
    if (home != null) {
      home.removeSolicitudTomadaListener(_onSolicitudTomada);
      home.removeListener(_onHomeChanged);
    }
    _home = null;
  }

  void _onHomeChanged() {
    if (!_isDisposed) notifyListeners();
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
    if (_isDisposed || _home == null) return;
    if (!silencioso) {
      _cargando = true;
      _error = null;
      notifyListeners();
    }

    try {
      await _home!.sincronizarSolicitudesPublicadasConductor();
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
    if (!_isDisposed) notifyListeners();
  }

  void quitarPorId(String servicioId) => _onSolicitudTomada(servicioId);

  Map<String, dynamic>? buscarPorId(String servicioId) =>
      _home?.buscarSolicitudPorId(servicioId);

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
