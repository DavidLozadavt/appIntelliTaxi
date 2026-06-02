import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intellitaxi/features/conductor/services/turno_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intellitaxi/core/services/app_logger.dart';
import 'package:intellitaxi/features/conductor/services/conductor_notification_sound_service.dart';
import 'package:intellitaxi/core/services/fleet_emergency_alert_service.dart';
import 'package:intellitaxi/core/services/incoming_service_notification_service.dart';
import 'package:intellitaxi/config/maps_config.dart';
import 'package:intellitaxi/core/perf/runtime_perf_flags.dart';
import 'package:intellitaxi/core/services/reverse_geocoding_service.dart';
import 'package:intellitaxi/core/services/voice_alert_service.dart';
import 'package:intellitaxi/features/conductor/utils/solicitud_display_helper.dart';
import 'package:intellitaxi/features/conductor/services/conductor_service.dart';
import 'package:intellitaxi/features/conductor/data/documento_vehiculo_model.dart';
import 'package:intellitaxi/features/conductor/data/vehiculo_conductor_model.dart';
import 'package:intellitaxi/features/conductor/data/turno_model.dart';
import 'package:intellitaxi/features/taxi/data/taxi_servicio_estado.dart';
import 'package:intellitaxi/features/taxi/exceptions/taxi_en_servicio_exception.dart';
import 'package:intellitaxi/features/taxi/utils/taxi_pusher_channels.dart';
import 'package:intellitaxi/config/pusher_config.dart';

import 'package:dio/dio.dart';
import 'package:intellitaxi/features/conductor/conductor_constants.dart';
import 'package:intellitaxi/features/conductor/services/conductor_solicitud_enrichment_service.dart';
import 'package:intellitaxi/features/conductor/utils/conductor_session_helper.dart';
import 'package:intellitaxi/features/conductor/utils/conductor_solicitud_payload_helper.dart';
import 'package:intellitaxi/features/conductor/utils/conductor_solicitud_distance_helper.dart';
import 'package:intellitaxi/features/conductor/utils/conductor_solicitud_ranking_helper.dart';
import 'package:intellitaxi/features/conductor/data/conductor_oferta_exclusiva.dart';
import 'package:intellitaxi/features/conductor/utils/conductor_oferta_indriver_helper.dart';
import 'package:intellitaxi/features/conductor/services/conductor_oferta_navigation.dart';
import 'package:intellitaxi/main.dart';
import 'package:intellitaxi/core/diagnostics/app_diagnostics.dart';
import 'package:intellitaxi/core/utils/app_lifecycle_helper.dart';
import 'package:intellitaxi/core/utils/json_payload_helper.dart';

export 'package:intellitaxi/features/conductor/conductor_constants.dart';

/// Provider para gestionar toda la lógica de la pantalla home del conductor
/// Incluye: ubicación, turnos, vehículos, solicitudes de servicio y conexión a Pusher.

class ConductorHomeProvider extends ChangeNotifier {
  // Servicios
  final ConductorService _conductorService = ConductorService();
  final TurnoService _turnoService = TurnoService();
  // Estado de ubicación
  Position? _currentPosition;
  bool _isLoadingLocation = true;
  String _locationMessage =
      'Estableciendo conexión satelital para rastreo en tiempo real...';
  String? _zonaActual;
  StreamSubscription<Position>? _locationSubscription;
  Position? _lastAreaResolvedPosition;
  DateTime? _lastAreaResolvedAt;
  DateTime? _lastLocationUiNotifyAt;
  Position? _lastLocationUiNotifyPosition;
  DateTime? _lastMapHeartbeatAt;
  bool _isSendingMapHeartbeat = false;
  final ReverseGeocodingService _reverseGeocodingService =
      ReverseGeocodingService();
  final ConductorSolicitudEnrichmentService _solicitudEnrichment =
      ConductorSolicitudEnrichmentService(
        reverseGeocoding: ReverseGeocodingService.shared,
      );

  // Estado online/offline
  bool _isOnline = false;
  bool _notificationPermissionRequestedInSession = false;

  // Vehículos y turnos
  VehiculoConductor? _vehiculoSeleccionado;
  List<VehiculoConductor> _vehiculosDisponibles = [];
  String? _lastVehiculosLoadError;
  TurnoActivo? _turnoActivo;

  // Solicitudes: un mapa por servicio_id. API = verdad de lista; Pusher/FCM = merge;
  // TTL solo oculta overlay «Llegando»; el ítem sigue en mapa / «En espera».
  final Map<String, Map<String, dynamic>> _solicitudesPorId = {};
  final Set<String> _overlayOcultoPorTtl = {};
  final Map<String, DateTime> _recibidaPorRealtimeEn = {};
  final Map<String, DateTime> _sonidoEmitidoPorSolicitudId = {};
  final Map<String, Timer> _timersExpiracion = {};
  final Map<String, DateTime> _expiracionPorSolicitud = {};
  String? _ultimaSyncSolicitudesEn;
  Timer? _tickerExpiracionUI;
  Timer? _syncSolicitudesTimer;
  bool _suscritoAPusher = false;
  bool _suscritoEmergenciasFlota = false;
  bool _enServicio = false;
  int? _servicioActivoId;
  Map<String, dynamic>? _servicioActivoPendienteNavegacion;
  final Set<String> _offerChannels = {};
  final Set<String> _offerHandlerKeys = {};
  String? _lastAcceptError;
  String? _lastTurnoError;
  bool _enDescanso = false;
  bool _recibeServicios = true;
  bool _visibleEnMapa = true;
  bool _cambiandoDescanso = false;
  String? _lastDescansoError;
  final List<void Function(String servicioId)> _solicitudTomadaListeners = [];
  final List<void Function(Map<String, dynamic> solicitud)>
      _nuevaSolicitudListeners = [];
  final Set<int> _serviciosRechazados = {};

  /// Oferta inDrive exclusiva (solo este conductor).
  ConductorOfertaExclusiva? _ofertaExclusiva;
  int _ofertaExclusivaSegundos = 0;
  int _ofertaExclusivaTtlInicial = 45;
  DateTime? _ofertaExclusivaExpiraEn;
  Timer? _ofertaExclusivaPollTimer;
  Timer? _ofertaExclusivaTickTimer;

  /// Evita snackbar «otro conductor» cuando Pusher llega tras nuestra propia aceptación.
  String? _servicioIdAceptacionPropia;
  DateTime? _aceptacionPropiaEn;

  // Control de dispose
  bool _isDisposed = false;

  // Getters
  Position? get currentPosition => _currentPosition;
  bool get isLoadingLocation => _isLoadingLocation;
  String get locationMessage => _locationMessage;
  bool get locationServiceDisabled =>
      _locationMessage.toLowerCase().contains('deshabilitado');
  bool get locationPermissionPermanentlyDenied =>
      _locationMessage.toLowerCase().contains('permanentemente');
  String get locationActionLabel {
    if (locationServiceDisabled) return 'Activar ubicación';
    if (locationPermissionPermanentlyDenied) return 'Abrir ajustes';
    return 'Reintentar conexión';
  }

  IconData get locationActionIcon {
    if (locationServiceDisabled || locationPermissionPermanentlyDenied) {
      return Icons.settings_rounded;
    }
    return Icons.refresh_rounded;
  }

  String? get zonaActual => _zonaActual;
  bool get isOnline => _isOnline;
  VehiculoConductor? get vehiculoSeleccionado => _vehiculoSeleccionado;
  List<VehiculoConductor> get vehiculosDisponibles => _vehiculosDisponibles;
  String? get lastVehiculosLoadError => _lastVehiculosLoadError;
  TurnoActivo? get turnoActivo => _turnoActivo;
  bool get enServicio => _enServicio;
  int? get servicioActivoId => _servicioActivoId;
  Map<String, dynamic>? get servicioActivoPendienteNavegacion =>
      _servicioActivoPendienteNavegacion;

  ConductorOfertaExclusiva? get ofertaExclusiva => _ofertaExclusiva;
  bool get tieneOfertaExclusivaActiva => _ofertaExclusiva != null;
  int get ofertaExclusivaSegundosRestantes => _ofertaExclusivaSegundos;
  int get ofertaExclusivaTtlInicial => _ofertaExclusivaTtlInicial;

  /// Datos listos para navegar a pantalla de viaje tras bootstrap/aceptar.
  void clearServicioActivoPendienteNavegacion() {
    _servicioActivoPendienteNavegacion = null;
  }

  List<Map<String, dynamic>> get solicitudesActivas =>
      (_enServicio || _enDescanso) ? const [] : _solicitudesPorId.values.toList();

  String? get ultimaSyncSolicitudesEn => _ultimaSyncSolicitudesEn;

  /// Pestaña «En espera»: publicados en API cuyo overlay TTL ya expiró (o solo llegaron por sync).
  List<Map<String, dynamic>> get solicitudesEnEsperaOrdenadas {
    if (_enServicio || _enDescanso) return const [];
    final solicitudes = _solicitudesPorId.values
        .where((s) {
          final id = ConductorSolicitudPayloadHelper.obtenerSolicitudId(s);
          return id != null && _overlayOcultoPorTtl.contains(id);
        })
        .toList();
    solicitudes.sort(ConductorSolicitudRankingHelper.compararRecientesPrimero);
    return solicitudes;
  }

  int get totalSolicitudesEnEspera => solicitudesEnEsperaOrdenadas.length;

  /// «A 450 m de ti» hasta la recogida (API o GPS actual).
  String distanciaDesdeConductorTexto(Map<String, dynamic> solicitud) {
    return ConductorSolicitudDistanceHelper.resolveLabel(
          solicitud,
          driverLat: _currentPosition?.latitude,
          driverLng: _currentPosition?.longitude,
        ) ??
        '';
  }

  Map<String, dynamic>? buscarSolicitudPorId(String solicitudId) =>
      _solicitudesPorId[solicitudId];
  String? get lastAcceptError => _lastAcceptError;
  String? get lastTurnoError => _lastTurnoError;
  bool get enDescanso => _enDescanso;
  bool get visibleEnMapa => _visibleEnMapa;
  bool get recibeServicios => _recibeServicios && !_enDescanso;
  bool get cambiandoDescanso => _cambiandoDescanso;
  String? get lastDescansoError => _lastDescansoError;
  bool get puedeUsarModoDescanso =>
      _isOnline && !_enServicio && _turnoActivo != null;
  /// Pestaña «Llegando»: overlay activo (Pusher / servicio.cercano, TTL no expirado).
  List<Map<String, dynamic>> get solicitudesOrdenadas =>
      _solicitudesOrdenadasVisiblesEnOverlay();

  List<Map<String, dynamic>> _solicitudesOrdenadasTodas() {
    final solicitudes = List<Map<String, dynamic>>.from(_solicitudesPorId.values);
    solicitudes.sort(ConductorSolicitudRankingHelper.compararRecientesPrimero);
    return solicitudes;
  }

  List<Map<String, dynamic>> _solicitudesOrdenadasVisiblesEnOverlay() {
    final solicitudes = _solicitudesPorId.values
        .where((s) {
          final id = ConductorSolicitudPayloadHelper.obtenerSolicitudId(s);
          return id != null && !_overlayOcultoPorTtl.contains(id);
        })
        .toList();
    solicitudes.sort(ConductorSolicitudRankingHelper.compararRecientesPrimero);
    return solicitudes;
  }

  /// Ofertas cercanas al punto hacia donde va el conductor (viaje activo).
  List<Map<String, dynamic>> solicitudesEnRuta({
    required double haciaLat,
    required double haciaLng,
    int? excluirServicioId,
    double radioKm = 18,
  }) {
    final radioMetros = radioKm * 1000;
    final candidatas = _solicitudesOrdenadasTodas().where((s) {
      final idStr = ConductorSolicitudPayloadHelper.obtenerSolicitudId(s);
      if (idStr == null || idStr.isEmpty) return false;
      final idNum = int.tryParse(idStr);
      if (excluirServicioId != null &&
          idNum != null &&
          idNum == excluirServicioId) {
        return false;
      }

      final lat = SolicitudDisplayHelper.parseCoordinate(s['origen_lat']);
      final lng = SolicitudDisplayHelper.parseCoordinate(s['origen_lng']);
      if (lat == null || lng == null) return true;

      final distancia = Geolocator.distanceBetween(
        haciaLat,
        haciaLng,
        lat,
        lng,
      );
      s['distancia_hacia_ruta_km'] = distancia / 1000.0;
      return distancia <= radioMetros;
    }).toList();

    candidatas.sort((a, b) {
      final da = JsonPayloadHelper.parseDouble(
        a['distancia_hacia_ruta_km'],
        fallback: 999,
      );
      final db = JsonPayloadHelper.parseDouble(
        b['distancia_hacia_ruta_km'],
        fallback: 999,
      );
      return da.compareTo(db);
    });

    return candidatas;
  }

  Map<String, dynamic>? get solicitudPrincipal =>
      solicitudesOrdenadas.isEmpty ? null : solicitudesOrdenadas.first;
  bool get tieneTurnoActivo => _turnoActivo != null;

  void addSolicitudTomadaListener(void Function(String servicioId) listener) {
    if (!_solicitudTomadaListeners.contains(listener)) {
      _solicitudTomadaListeners.add(listener);
    }
  }

  void removeSolicitudTomadaListener(void Function(String servicioId) listener) {
    _solicitudTomadaListeners.remove(listener);
  }

  void addNuevaSolicitudListener(
    void Function(Map<String, dynamic> solicitud) listener,
  ) {
    if (!_nuevaSolicitudListeners.contains(listener)) {
      _nuevaSolicitudListeners.add(listener);
    }
  }

  void removeNuevaSolicitudListener(
    void Function(Map<String, dynamic> solicitud) listener,
  ) {
    _nuevaSolicitudListeners.remove(listener);
  }

  /// Restaura turno desde SharedPreferences (sin red) para no bloquear el home.
  Future<bool> restaurarTurnoDesdeCache() async {
    if (_turnoActivo != null) return true;

    try {
      final prefs = await SharedPreferences.getInstance();
      final turnoId = prefs.getInt('turno_activo_id');
      if (turnoId == null || turnoId <= 0) return false;

      final idVehiculo = prefs.getInt('turno_vehiculo_id') ?? 0;
      _turnoActivo = TurnoActivo(
        id: turnoId,
        idConductor: 0,
        idVehiculo: idVehiculo,
        fechaTurno: prefs.getString('turno_fecha') ?? '',
        horaInicio: prefs.getString('turno_hora_inicio') ?? '',
        estado: 'ACTIVO',
      );
      _isOnline = true;
      _sincronizarVehiculoSeleccionadoConTurno();
      if (!_isDisposed) notifyListeners();
      AppLogger.d('✅ Turno restaurado desde cache: $turnoId');
      return true;
    } catch (e) {
      AppLogger.d('⚠️ restaurarTurnoDesdeCache: $e');
      return false;
    }
  }

  /// Inicializar el provider
  Future<void> initialize() async {
    await restaurarTurnoDesdeCache();
    await initializeLocation();
    await cargarVehiculos();
    if (_turnoActivo != null) {
      _sincronizarVehiculoSeleccionadoConTurno();
    }
    await bootstrapTaxiConductor();
    await cargarSolicitudesRechazadas();
    if (!_enServicio) {
      if (_turnoActivo != null) {
        unawaited(cargarTurnoActual());
      } else {
        await cargarTurnoActual();
      }
    }
  }

  /// Sync rechazos: `GET /conductor/solicitudes-rechazadas` + cache local.
  Future<void> cargarSolicitudesRechazadas() async {
    _serviciosRechazados.addAll(
      await ConductorSessionHelper.cargarServiciosRechazadosLocal(),
    );

    final remoto = await _conductorService.getSolicitudesRechazadas();
    _serviciosRechazados.addAll(remoto.servicioIds);

    await ConductorSessionHelper.guardarServiciosRechazados(_serviciosRechazados);

    _purgaSolicitudesRechazadasDelMapa();

    if (!_isDisposed) notifyListeners();
  }

  void _purgaSolicitudesRechazadasDelMapa() {
    final rechazados = _solicitudesPorId.keys
        .where((id) => esServicioRechazado(id))
        .toList();
    for (final id in rechazados) {
      _removerSolicitudDelMapa(id);
    }
  }

  static int? servicioIdNumerico(String? id) {
    if (id == null || id.isEmpty) return null;
    if (id.startsWith('temp_')) return null;
    return int.tryParse(id);
  }

  bool esServicioRechazado(String? solicitudId) {
    final num = servicioIdNumerico(solicitudId);
    return num != null && _serviciosRechazados.contains(num);
  }

  bool _esServicioRechazadoEnPayload(Map<String, dynamic> raw) {
    for (final key in const [
      'servicio_id',
      'servicioId',
      'solicitud_id',
      'solicitudId',
      'id',
    ]) {
      if (esServicioRechazado(raw[key]?.toString())) return true;
    }
    return false;
  }

  /// Rechaza en backend y oculta en app (no vuelve en pendientes ni Pusher).
  Future<bool> rechazarSolicitudParaConductor(String solicitudId) async {
    final servicioId = servicioIdNumerico(solicitudId);
    var exitoRemoto = true;

    if (servicioId != null) {
      try {
        await _conductorService.rechazarSolicitud(servicioId: servicioId);
        _serviciosRechazados.add(servicioId);
        await ConductorSessionHelper.agregarServicioRechazado(servicioId);
      } catch (e) {
        exitoRemoto = false;
        AppLogger.d('⚠️ Error POST solicitud/rechazar: $e');
        _serviciosRechazados.add(servicioId);
        await ConductorSessionHelper.agregarServicioRechazado(servicioId);
      }
    }

    rechazarSolicitud(solicitudId);
    if (!_isDisposed) notifyListeners();
    return exitoRemoto;
  }

  /// Bootstrap taxi: estado-actual → servicio activo si aplica.
  Future<void> bootstrapTaxiConductor() async {
    try {
      final estado = await _conductorService.getEstadoActualConductor();
      if (estado?.enServicio == true) {
        await _activarModoEnServicio(
          servicioActivoId: estado!.servicioActivoId,
        );
        return;
      }

      if (estado != null) {
        _aplicarFlagsDescanso(
          enDescanso: estado.enDescanso,
          recibeServicios: estado.recibeServicios,
          visibleEnMapa: estado.visibleEnMapa,
        );
        if (estado.enDescanso && estado.turnoActivo) {
          _isOnline = true;
          await _desuscribirRecepcionServicios();
          await _suscribirEmergenciasFlota();
          _limpiarColaSolicitudesLocal();
          if (!_isDisposed) notifyListeners();
          return;
        }
      }

      final detalle = await _conductorService.getServicioActivoConductor();
      if (detalle != null) {
        await _activarModoEnServicio(
          servicioActivoId: detalle['servicio']?['id'] as int?,
          detalleNavegacion: detalle,
        );
      }
    } catch (e) {
      AppLogger.d('⚠️ bootstrapTaxiConductor: $e');
    }
  }

  Future<Map<String, dynamic>?> _fetchServicioActivoDetalle() async {
    // Delegado al servicio de restauración vía endpoint existente.
    try {
      final response = await _conductorService.getServicioActivoConductor();
      return response;
    } catch (_) {
      return null;
    }
  }

  /// Marca conductor en viaje: limpia cola y deja de escuchar solicitudes.
  Future<void> marcarEnServicio({
    required int servicioId,
    Map<String, dynamic>? detalleNavegacion,
  }) async {
    await _activarModoEnServicio(
      servicioActivoId: servicioId,
      detalleNavegacion: detalleNavegacion,
    );
  }

  Future<void> _activarModoEnServicio({
    int? servicioActivoId,
    Map<String, dynamic>? detalleNavegacion,
  }) async {
    _enServicio = true;
    _servicioActivoId = servicioActivoId;

    _limpiarColaSolicitudesLocal();
    await _desuscribirCanalSolicitudesServicio();

    if (detalleNavegacion != null) {
      _servicioActivoPendienteNavegacion = detalleNavegacion;
    } else if (servicioActivoId != null) {
      final detalle = await _fetchServicioActivoDetalle();
      if (detalle != null) {
        _servicioActivoPendienteNavegacion = detalle;
      }
    }

    final pos = _currentPosition;
    if (pos != null) {
      // Un heartbeat al entrar en viaje: backend marca ocupado y oculta en mapa flota.
      unawaited(_sendMapHeartbeat(pos, force: true));
    }

    _reconfigurarSeguimientoUbicacion();
    if (!_isDisposed) notifyListeners();
  }

  /// Libera conductor tras finalizar/cancelar viaje.
  Future<void> marcarDisponible() async {
    _enServicio = false;
    _servicioActivoId = null;
    _servicioActivoPendienteNavegacion = null;
    _limpiarColaSolicitudesLocal();

    await _sincronizarModoDescansoDesdeBackend();

    // El turno sigue abierto; solo re-sincronizar en segundo plano.
    if (_turnoActivo != null) {
      unawaited(cargarTurnoActual());
    } else {
      unawaited(
        restaurarTurnoDesdeCache().then((ok) {
          if (ok) unawaited(cargarTurnoActual());
        }),
      );
    }

    if (_isOnline && !_enDescanso && !_suscritoAPusher) {
      await conectarPusher();
    }

    final pos = _currentPosition;
    if (pos != null) {
      // Re-sincroniza disponible en mapa flota; el viaje usó servicios/actualizar-ubicacion.
      unawaited(_sendMapHeartbeat(pos, force: true));
    }

    _reconfigurarSeguimientoUbicacion();
    if (!_isDisposed) notifyListeners();
  }

  void _aplicarFlagsDescanso({
    required bool enDescanso,
    required bool recibeServicios,
    required bool visibleEnMapa,
  }) {
    _enDescanso = enDescanso;
    _recibeServicios = recibeServicios;
    _visibleEnMapa = visibleEnMapa;
  }

  void _aplicarResultadoDescanso(TaxiModoDescansoEstado result) {
    _aplicarFlagsDescanso(
      enDescanso: result.enDescanso,
      recibeServicios: result.recibeServicios,
      visibleEnMapa: result.visibleEnMapa,
    );
  }

  Future<void> _sincronizarModoDescansoDesdeBackend() async {
    try {
      final estado =
          await _conductorService.getModoDescanso() ??
          await _conductorService.getEstadoActualConductor().then(
            (e) => e == null
                ? null
                : TaxiModoDescansoEstado(
                    enDescanso: e.enDescanso,
                    turnoActivo: e.turnoActivo,
                    recibeServicios: e.recibeServicios,
                    visibleEnMapa: e.visibleEnMapa,
                  ),
          );
      if (estado == null) return;
      _aplicarResultadoDescanso(estado);
    } catch (e) {
      AppLogger.d('⚠️ Sync modo descanso: $e');
    }
  }

  /// Activa o desactiva modo descanso (turno activo, sin viaje).
  Future<bool> setModoDescanso(bool descanso) async {
    if (_cambiandoDescanso) return false;
    if (descanso && !puedeUsarModoDescanso) return false;
    if (!descanso && !_enDescanso) return true;

    _cambiandoDescanso = true;
    _lastDescansoError = null;
    if (!_isDisposed) notifyListeners();

    try {
      var position = _currentPosition;
      if (position == null) {
        position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 8),
          ),
        );
        _currentPosition = position;
      }

      final result = await _conductorService.setModoDescanso(
        descanso: descanso,
        lat: position.latitude,
        lng: position.longitude,
      );
      _aplicarResultadoDescanso(result);

      if (descanso) {
        _limpiarColaSolicitudesLocal();
        await _desuscribirRecepcionServicios();
        await _suscribirEmergenciasFlota();
        await _sendMapHeartbeat(position, force: true);
      } else {
        await conectarPusher();
        await _sendMapHeartbeat(position, force: true);
      }

      if (!_isDisposed) notifyListeners();
      return true;
    } catch (e) {
      _lastDescansoError = e.toString().replaceAll('Exception: ', '').trim();
      AppLogger.d('❌ Error cambiando modo descanso: $e');
      if (!_isDisposed) notifyListeners();
      return false;
    } finally {
      _cambiandoDescanso = false;
      if (!_isDisposed) notifyListeners();
    }
  }

  Future<bool> toggleModoDescanso() => setModoDescanso(!_enDescanso);

  void _limpiarColaSolicitudesLocal() {
    for (final timer in _timersExpiracion.values) {
      timer.cancel();
    }
    _timersExpiracion.clear();
    _expiracionPorSolicitud.clear();
    _overlayOcultoPorTtl.clear();
    _recibidaPorRealtimeEn.clear();
    _sonidoEmitidoPorSolicitudId.clear();
    _solicitudesPorId.clear();
    _detenerTickerSiNoHaySolicitudes();
  }

  void _removerSolicitudDelMapa(String solicitudId) {
    _solicitudesPorId.remove(solicitudId);
    _overlayOcultoPorTtl.remove(solicitudId);
    _recibidaPorRealtimeEn.remove(solicitudId);
    _sonidoEmitidoPorSolicitudId.remove(solicitudId);
    _expiracionPorSolicitud.remove(solicitudId);
    _timersExpiracion[solicitudId]?.cancel();
    _timersExpiracion.remove(solicitudId);
  }

  void _marcarRecibidaPorRealtime(String solicitudId) {
    _recibidaPorRealtimeEn[solicitudId] = DateTime.now();
  }

  /// Tono de alerta solo para alta en «Llegando» (Pusher/FCM), no en «En espera» ni sync API.
  void _dispararSonidoNuevaSolicitud(
    String solicitudId, {
    bool decirNuevoServicioEnVoz = true,
  }) {
    if (_isDisposed || _enServicio || _enDescanso || !_isOnline) return;

    final prev = _sonidoEmitidoPorSolicitudId[solicitudId];
    if (prev != null &&
        DateTime.now().difference(prev).inSeconds <
            kSonidoSolicitudDedupeSegundos) {
      return;
    }
    _sonidoEmitidoPorSolicitudId[solicitudId] = DateTime.now();

    unawaited(_reproducirSonidoNotificacion());
    if (decirNuevoServicioEnVoz) {
      unawaited(VoiceAlertService.announceNewService());
    }
  }

  /// No borrar en sync si acaba de llegar por Pusher/FCM o sigue en «Llegando».
  bool _conservarEnMapaTrasSync(String id) {
    if (!_overlayOcultoPorTtl.contains(id)) {
      return true;
    }
    final recibida = _recibidaPorRealtimeEn[id];
    if (recibida == null) return false;
    return DateTime.now().difference(recibida).inSeconds <
        kConservarRealtimeTrasSyncSegundos;
  }

  @override
  void dispose() {
    _isDisposed = true;
    // Cancelar todos los timers
    for (var timer in _timersExpiracion.values) {
      timer.cancel();
    }
    _timersExpiracion.clear();
    _tickerExpiracionUI?.cancel();
    _tickerExpiracionUI = null;
    _detenerSincronizacionSolicitudes();
    _detenerSeguimientoUbicacion();
    _detenerPollOfertaActiva();
    _detenerTickOfertaExclusiva();
    VoiceAlertService.dispose();
    desconectarPusher();
    super.dispose();
  }

  // ==================== CONEXIÓN PUSHER ====================

  /// Conecta a Pusher y se suscribe al canal de solicitudes
  Future<void> conectarPusher() async {
    if (_enServicio) {
      AppLogger.d('ℹ️ En servicio: no suscribir solicitudes-servicio');
      await _suscribirEmergenciasFlota();
      return;
    }

    if (_enDescanso) {
      AppLogger.d('ℹ️ En descanso: no suscribir solicitudes-servicio');
      await _suscribirEmergenciasFlota();
      return;
    }

    try {
      if (_suscritoAPusher) {
        AppLogger.d('⚠️ Ya está suscrito a solicitudes-servicio');
        return;
      }

      AppLogger.d('🔌 Suscribiéndose al canal de solicitudes...');

      await PusherService.subscribeSecondary(TaxiPusherChannels.solicitudesServicio);

      // Registrar handlers para variantes del evento de nuevas solicitudes
      for (final eventName in const [
        TaxiPusherEvents.nuevaSolicitud,
        'nueva_solicitud',
        'nueva-oferta',
        'nueva_oferta',
      ]) {
        PusherService.registerEventHandlerSecondary(
          '${TaxiPusherChannels.solicitudesServicio}:$eventName',
          (data) {
            AppLogger.d('🔔 Evento recibido: $eventName');
            if (data != null) {
              _procesarNuevaSolicitud(data);
            }
          },
        );
      }

      for (final eventName in const [
        TaxiPusherEvents.solicitudTomada,
        'solicitud_tomada',
      ]) {
        PusherService.registerEventHandlerSecondary(
          '${TaxiPusherChannels.solicitudesServicio}:$eventName',
          (data) {
            if (data != null) _procesarSolicitudTomada(data);
          },
        );
      }

      final idPersona = await ConductorSessionHelper.obtenerIdPersonaConductor();
      final candidateChannels =
          ConductorSessionHelper.canalesOfertaDirecta(idPersona);
      if (candidateChannels.isNotEmpty) {
        for (final channel in candidateChannels) {
          await PusherService.subscribeSecondary(channel);
          _offerChannels.add(channel);

          for (final eventName in const [
            'oferta.directa',
            'oferta_directa',
            'oferta-directa',
          ]) {
            final key = '$channel:$eventName';
            _offerHandlerKeys.add(key);
            PusherService.registerEventHandlerSecondary(key, (data) {
              AppLogger.d('🔔 Evento recibido: $eventName en $channel');
              if (data != null) {
                _procesarNuevaSolicitud(data, isDirectOffer: true);
              }
            });
          }

          for (final eventName in const [
            TaxiPusherEvents.servicioCercano,
            'servicio_cercano',
          ]) {
            final key = '$channel:$eventName';
            _offerHandlerKeys.add(key);
            PusherService.registerEventHandlerSecondary(key, (data) {
              AppLogger.d('🔔 Evento recibido: $eventName en $channel');
              if (data != null) _procesarNuevaSolicitud(data);
            });
          }

          for (final eventName in const [
            TaxiPusherEvents.ofertaServicioExclusiva,
            'oferta.servicio.exclusiva',
          ]) {
            final key = '$channel:$eventName';
            _offerHandlerKeys.add(key);
            PusherService.registerEventHandlerSecondary(key, (data) {
              AppLogger.d('🔔 Oferta exclusiva inDrive: $eventName');
              if (data != null) {
                unawaited(_aplicarOfertaExclusivaDesdePayload(data));
              }
            });
          }

          for (final eventName in const [
            TaxiPusherEvents.ofertaServicioCerrada,
            'oferta.servicio.cerrada',
          ]) {
            final key = '$channel:$eventName';
            _offerHandlerKeys.add(key);
            PusherService.registerEventHandlerSecondary(key, (data) {
              AppLogger.d('🔔 Oferta cerrada inDrive: $eventName');
              if (data != null) _procesarOfertaCerrada(data);
            });
          }

          // Mismo merge que `solicitudes-servicio` (modo broadcast / backend legacy).
          for (final eventName in const [
            TaxiPusherEvents.nuevaSolicitud,
            'nueva_solicitud',
          ]) {
            final key = '$channel:$eventName';
            _offerHandlerKeys.add(key);
            PusherService.registerEventHandlerSecondary(key, (data) {
              AppLogger.d('🔔 Evento recibido: $eventName en $channel');
              if (data != null) _procesarNuevaSolicitud(data);
            });
          }
        }

        AppLogger.d(
          '✅ Canales oferta directa suscritos: ${_offerChannels.toList()}',
        );
        AppLogger.d('✅ Handlers oferta directa: ${_offerHandlerKeys.toList()}');
      } else {
        AppLogger.d(
          '⚠️ No se pudo resolver id de sesión del conductor para ofertas directas',
        );
      }

      await _suscribirEmergenciasFlota();

      _suscritoAPusher = true;
      _iniciarSincronizacionSolicitudes();
      _iniciarPollOfertaActiva();
      unawaited(sincronizarSolicitudesPublicadasConductor());
      unawaited(sincronizarOfertaActiva());
      AppLogger.d('✅ Suscrito correctamente al canal de solicitudes');
    } catch (e) {
      AppLogger.d('❌ Error al conectarse a Pusher: $e');
    }
  }

  void _iniciarSincronizacionSolicitudes() {
    if (_enServicio || _enDescanso) return;
    _syncSolicitudesTimer?.cancel();
    _syncSolicitudesTimer = Timer.periodic(const Duration(seconds: 50), (_) {
      if (!_isDisposed && _suscritoAPusher && _isOnline && !_enDescanso) {
        sincronizarSolicitudesPublicadasConductor();
      }
    });
  }

  void _detenerSincronizacionSolicitudes() {
    _syncSolicitudesTimer?.cancel();
    _syncSolicitudesTimer = null;
  }

  /// Alinea la cola local con el backend (otro conductor aceptó, realtime perdido, etc.).
  Future<void> sincronizarSolicitudesPublicadasConductor() async {
    if (_isDisposed || !_isOnline || _enServicio || _enDescanso) return;
    try {
      final result = await _conductorService.listarSolicitudesPublicadasConductor(
        lat: _currentPosition?.latitude,
        lng: _currentPosition?.longitude,
      );

      if (result.enServicio) {
        await _activarModoEnServicio(
          servicioActivoId: result.servicioActivoId,
        );
        return;
      }

      if (result.enDescanso) {
        _aplicarFlagsDescanso(
          enDescanso: true,
          recibeServicios: false,
          visibleEnMapa: false,
        );
        _limpiarColaSolicitudesLocal();
        await _desuscribirRecepcionServicios();
        if (!_isDisposed) notifyListeners();
        return;
      }

      final list = result.solicitudes;
      _ultimaSyncSolicitudesEn = DateTime.now().toIso8601String();
      final serverIds = <String>{};
      for (final m in list) {
        final sid = m['servicio_id'] ?? m['solicitud_id'] ?? m['id'];
        if (sid != null) serverIds.add(sid.toString());
      }

      for (final id in _solicitudesPorId.keys.toList()) {
        if (id.startsWith('temp_')) continue;
        if (int.tryParse(id) == null) continue;
        if (!serverIds.contains(id)) {
          if (_conservarEnMapaTrasSync(id)) {
            AppLogger.d(
              'ℹ️ Sync: conservando $id (realtime/overlay; API no lo listó)',
            );
            continue;
          }
          _removerSolicitudDelMapa(id);
        }
      }

      for (final m in list) {
        final map = m is Map<String, dynamic>
            ? m
            : Map<String, dynamic>.from(m as Map);
        final sid = map['servicio_id'] ?? map['solicitud_id'] ?? map['id'];
        if (sid != null) {
          final sidStr = sid.toString();
          if (ConductorOfertaIndriverHelper.esFaseExclusiva(map) &&
              _ofertaExclusiva?.solicitudId != sidStr) {
            continue;
          }
          _recibidaPorRealtimeEn.remove(sidStr);
        }
        _procesarNuevaSolicitud(map, fromSync: true);
      }

      _iniciarTickerExpiracionUI();
      if (!_isDisposed) notifyListeners();
    } catch (e) {
      AppLogger.d('⚠️ Sync solicitudes publicadas: $e');
    }
  }

  /// Desconecta de Pusher
  Future<void> desconectarPusher() async {
    try {
      await _desuscribirRecepcionServicios();
      await _desuscribirEmergenciasFlota();
      AppLogger.d('✅ Desconectado de Pusher');
    } catch (e) {
      AppLogger.d('❌ Error al desconectar Pusher: $e');
    }
  }

  Future<void> _desuscribirRecepcionServicios() async {
    _detenerSincronizacionSolicitudes();
    _detenerPollOfertaActiva();
    for (final eventName in const [
      TaxiPusherEvents.nuevaSolicitud,
      'nueva_solicitud',
      'nueva-oferta',
      'nueva_oferta',
      TaxiPusherEvents.solicitudTomada,
      'solicitud_tomada',
    ]) {
      PusherService.unregisterEventHandlerSecondary(
        '${TaxiPusherChannels.solicitudesServicio}:$eventName',
      );
    }
    try {
      await PusherService.unsubscribeSecondary(
        TaxiPusherChannels.solicitudesServicio,
      );
    } catch (_) {}

    for (final key in _offerHandlerKeys) {
      PusherService.unregisterEventHandlerSecondary(key);
    }
    _offerHandlerKeys.clear();

    for (final channel in _offerChannels) {
      await PusherService.unsubscribeSecondary(channel);
    }
    _offerChannels.clear();

    _suscritoAPusher = false;
  }

  Future<void> _desuscribirCanalSolicitudesServicio() async {
    await _desuscribirRecepcionServicios();
  }

  void _marcarAceptacionPropiaEnCurso(String servicioId) {
    _servicioIdAceptacionPropia = servicioId;
    _aceptacionPropiaEn = DateTime.now();
  }

  void _limpiarMarcaAceptacionPropia() {
    _servicioIdAceptacionPropia = null;
    _aceptacionPropiaEn = null;
  }

  bool _esAceptacionPropiaReciente(String servicioId) {
    if (_servicioIdAceptacionPropia != servicioId) return false;
    final t = _aceptacionPropiaEn;
    if (t == null) return false;
    return DateTime.now().difference(t) < const Duration(seconds: 25);
  }

  Future<bool> _yoTomeServicioSegunPayload(
    String servicioId,
    Map<String, dynamic> raw,
  ) async {
    if (_esAceptacionPropiaReciente(servicioId)) return true;
    final cid =
        ConductorSolicitudPayloadHelper.conductorIdFromTomadaPayload(raw);
    if (cid == null) return false;
    final miId = await ConductorSessionHelper.obtenerIdPersonaConductor();
    return miId != null && miId == cid;
  }

  void _procesarSolicitudTomada(dynamic data) {
    try {
      final raw = ConductorSolicitudPayloadHelper.parsePayload(data);
      final servicioId =
          ConductorSolicitudPayloadHelper.servicioIdFromTomadaPayload(raw);
      if (servicioId == null) return;

      unawaited(() async {
        final yoLoTome = await _yoTomeServicioSegunPayload(servicioId, raw);
        if (_isDisposed) return;

        if (yoLoTome) {
          if (_ofertaExclusiva?.solicitudId == servicioId) {
            _limpiarOfertaExclusivaLocal(
              cerrarPantalla: ConductorOfertaNavigation.pantallaVisible,
            );
          }
          _limpiarMarcaAceptacionPropia();
          return;
        }

        if (_ofertaExclusiva?.solicitudId == servicioId) {
          _limpiarOfertaExclusivaLocal(
            cerrarPantalla: true,
            mensaje: 'Otro conductor tomó este servicio',
          );
        }
        rechazarSolicitud(servicioId);
        for (final listener in List.of(_solicitudTomadaListeners)) {
          listener(servicioId);
        }
      }());
    } catch (e) {
      AppLogger.d('⚠️ Error procesando solicitud.tomada: $e');
    }
  }

  // ==================== OFERTA INDIRVE (EXCLUSIVA) ====================

  void _iniciarPollOfertaActiva() {
    _detenerPollOfertaActiva();
    _ofertaExclusivaPollTimer = Timer.periodic(
      const Duration(seconds: 12),
      (_) => unawaited(sincronizarOfertaActiva()),
    );
  }

  void _detenerPollOfertaActiva() {
    _ofertaExclusivaPollTimer?.cancel();
    _ofertaExclusivaPollTimer = null;
  }

  void _detenerTickOfertaExclusiva() {
    _ofertaExclusivaTickTimer?.cancel();
    _ofertaExclusivaTickTimer = null;
  }

  void _iniciarTickOfertaExclusiva() {
    if (_ofertaExclusivaTickTimer != null) return;
    _ofertaExclusivaTickTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_isDisposed || _ofertaExclusiva == null) {
        _detenerTickOfertaExclusiva();
        return;
      }
      final expira = _ofertaExclusivaExpiraEn;
      if (expira == null) return;
      _actualizarSegundosOfertaDesdeExpira(expira);
      if (_ofertaExclusivaSegundos <= 0) {
        _limpiarOfertaExclusivaLocal(
          cerrarPantalla: true,
          mensaje: 'El tiempo para responder terminó',
        );
        return;
      }
      if (!_isDisposed) notifyListeners();
    });
  }

  void _actualizarSegundosOfertaDesdeExpira(DateTime expira) {
    final rest = expira.difference(DateTime.now()).inSeconds;
    _ofertaExclusivaSegundos = rest > 0 ? rest : 0;
  }

  DateTime? _parseExpiraOfertaExclusiva(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final parsed = DateTime.tryParse(raw.trim());
    if (parsed == null) return null;
    return parsed.isUtc ? parsed.toLocal() : parsed;
  }

  /// Fija [expiraEn] solo en oferta nueva o si el servidor acorta el plazo (nunca sube el contador).
  void _fijarExpiraOfertaExclusiva({
    required String solicitudId,
    required ConductorOfertaExclusiva oferta,
  }) {
    final ttl = oferta.segundosRestantes ?? oferta.ttlSegundos ?? 45;
    final expiraServidor = _parseExpiraOfertaExclusiva(oferta.expiraEn);
    final candidataDesdePayload = expiraServidor ??
        DateTime.now().add(Duration(seconds: ttl > 0 ? ttl : 45));

    final esMismaOferta = _ofertaExclusivaExpiraEn != null &&
        _ofertaExclusiva?.solicitudId == solicitudId;

    if (esMismaOferta) {
      if (expiraServidor != null &&
          expiraServidor.isBefore(_ofertaExclusivaExpiraEn!)) {
        _ofertaExclusivaExpiraEn = expiraServidor;
      }
    } else {
      _ofertaExclusivaExpiraEn = candidataDesdePayload;
      final rest =
          _ofertaExclusivaExpiraEn!.difference(DateTime.now()).inSeconds;
      _ofertaExclusivaTtlInicial = rest > 0 ? rest : (ttl > 0 ? ttl : 45);
    }

    if (_ofertaExclusivaExpiraEn != null) {
      _actualizarSegundosOfertaDesdeExpira(_ofertaExclusivaExpiraEn!);
    }
  }

  Future<void> sincronizarOfertaActiva() async {
    if (_isDisposed || !_isOnline || _enServicio || _enDescanso) return;
    try {
      final result = await _conductorService.getOfertaActiva();
      if (result.tieneOferta && result.oferta != null) {
        await _aplicarOfertaExclusivaDesdePayload(
          result.oferta!,
          abrirPantalla: !ConductorOfertaNavigation.pantallaVisible,
        );
      } else if (_ofertaExclusiva != null &&
          !ConductorOfertaNavigation.pantallaVisible) {
        _limpiarOfertaExclusivaLocal(cerrarPantalla: false);
      }
    } catch (e) {
      AppLogger.d('⚠️ sincronizarOfertaActiva: $e');
    }
  }

  Future<void> _aplicarOfertaExclusivaDesdePayload(
    dynamic data, {
    bool abrirPantalla = true,
  }) async {
    if (_isDisposed || _enServicio || _enDescanso) return;

    final oferta = ConductorOfertaExclusiva.tryFromDynamic(data);
    if (oferta == null) return;

    final sid = oferta.solicitudId;
    if (esServicioRechazado(sid)) return;

    final esMismaOferta =
        _ofertaExclusiva?.solicitudId == sid && _ofertaExclusivaExpiraEn != null;

    _ofertaExclusiva = oferta;
    _fijarExpiraOfertaExclusiva(solicitudId: sid, oferta: oferta);
    _iniciarTickOfertaExclusiva();

    final solicitud = ConductorSolicitudPayloadHelper.normalizarSolicitud(
      oferta.toSolicitudMap(),
      isDirectOffer: true,
    );
    solicitud['_local_id'] = sid;
    solicitud['fase_oferta'] = 'exclusiva';
    solicitud['oferta_exclusiva'] = true;
    _solicitudesPorId[sid] = solicitud;
    _overlayOcultoPorTtl.add(sid);

    _marcarRecibidaPorRealtime(sid);
    if (!esMismaOferta) {
      // Oferta exclusiva: solo sonido; la dirección la dice TTS en la pantalla.
      _dispararSonidoNuevaSolicitud(sid, decirNuevoServicioEnVoz: false);
    }

    final showAlert = await AppLifecycleHelper.shouldShowIncomingServiceAlert();
    if (showAlert) {
      await IncomingServiceNotificationService.instance.showIncomingService(
        solicitud,
      );
    }

    if (!_isDisposed) notifyListeners();

    if (abrirPantalla && !ConductorOfertaNavigation.pantallaVisible) {
      unawaited(ConductorOfertaNavigation.abrirOfertaExclusiva(oferta));
    }

    unawaited(_enriquecerDireccionesSolicitud(sid));
  }

  void _procesarOfertaCerrada(dynamic data) {
    try {
      final raw = ConductorSolicitudPayloadHelper.parsePayload(data);
      final sid = raw['servicio_id']?.toString() ??
          raw['solicitud_id']?.toString();
      if (sid == null || sid.isEmpty) return;

      final motivo = raw['motivo']?.toString().toLowerCase() ?? '';

      unawaited(() async {
        final yoLoTome = await _yoTomeServicioSegunPayload(sid, raw);
        if (_isDisposed) return;

        if (_ofertaExclusiva?.solicitudId == sid) {
          if (yoLoTome) {
            _limpiarOfertaExclusivaLocal(
              cerrarPantalla: ConductorOfertaNavigation.pantallaVisible,
            );
          } else {
            final mensaje = motivo == 'tomada_por_otro'
                ? 'Otro conductor tomó este servicio'
                : motivo == 'expirada'
                    ? 'La oferta expiró'
                    : 'La oferta ya no está disponible';
            _limpiarOfertaExclusivaLocal(
              cerrarPantalla: true,
              mensaje: mensaje,
            );
          }
        }

        if (!yoLoTome &&
            (motivo == 'tomada_por_otro' || motivo == 'expirada')) {
          rechazarSolicitud(sid);
        }
        if (yoLoTome) {
          _limpiarMarcaAceptacionPropia();
        }
      }());
    } catch (e) {
      AppLogger.d('⚠️ Error procesando oferta.cerrada: $e');
    }
  }

  void _limpiarOfertaExclusivaLocal({
    required bool cerrarPantalla,
    String? mensaje,
  }) {
    _ofertaExclusiva = null;
    _ofertaExclusivaSegundos = 0;
    _ofertaExclusivaTtlInicial = 45;
    _ofertaExclusivaExpiraEn = null;
    _detenerTickOfertaExclusiva();
    if (cerrarPantalla) {
      ConductorOfertaNavigation.cerrarSiVisible(mensaje: mensaje);
    } else if (mensaje != null && mensaje.trim().isNotEmpty) {
      final ctx = navigatorKey.currentContext;
      if (ctx != null && ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(content: Text(mensaje), duration: const Duration(seconds: 3)),
        );
      }
    }
    if (!_isDisposed) notifyListeners();
  }

  Future<bool> rechazarOfertaExclusiva() async {
    final oferta = _ofertaExclusiva;
    if (oferta == null) return false;
    final ok = await rechazarSolicitudParaConductor(oferta.solicitudId);
    _limpiarOfertaExclusivaLocal(cerrarPantalla: false);
    return ok;
  }

  Future<Map<String, dynamic>?> aceptarOfertaExclusiva({
    required int vehiculoId,
  }) async {
    final oferta = _ofertaExclusiva;
    if (oferta == null) return null;
    final response = await aceptarSolicitud(
      oferta.solicitudId,
      vehiculoId,
      precioOfertado: oferta.precioEstimado,
    );
    _limpiarOfertaExclusivaLocal(cerrarPantalla: false);
    return response;
  }

  void _notificarNuevaSolicitudExterna(Map<String, dynamic> solicitud) {
    final copia = Map<String, dynamic>.from(solicitud);
    for (final listener in List.of(_nuevaSolicitudListeners)) {
      listener(copia);
    }
  }

  Future<void> _suscribirEmergenciasFlota() async {
    if (_suscritoEmergenciasFlota) return;
    const channel = 'emergencias-conductores';
    try {
      await PusherService.subscribeSecondary(channel);
      for (final eventName in const [
        'nueva-emergencia',
        'nueva_emergencia',
        'emergencia-conductor',
        'emergencia_conductor',
        'emergencia-nueva',
      ]) {
        PusherService.registerEventHandlerSecondary(
          '$channel:$eventName',
          (data) {
            if (data != null) {
              unawaited(FleetEmergencyAlertService.instance.handlePayload(data));
            }
          },
        );
      }
      _suscritoEmergenciasFlota = true;
      AppLogger.d('✅ Suscrito a alertas de emergencia de flota');
    } catch (e) {
      AppLogger.d('⚠️ No se pudo suscribir emergencias de flota: $e');
    }
  }

  Future<void> _desuscribirEmergenciasFlota() async {
    if (!_suscritoEmergenciasFlota) return;
    const channel = 'emergencias-conductores';
    for (final eventName in const [
      'nueva-emergencia',
      'nueva_emergencia',
      'emergencia-conductor',
      'emergencia_conductor',
      'emergencia-nueva',
    ]) {
      PusherService.unregisterEventHandlerSecondary('$channel:$eventName');
    }
    await PusherService.unsubscribeSecondary(channel);
    _suscritoEmergenciasFlota = false;
  }

  /// FCM / alerta: primero tarjeta + sonido; sync después (sin borrar overlay activo).
  Future<void> procesarAlertaSolicitudEntrante(Map<String, dynamic> data) async {
    if (_isDisposed || _enServicio || _enDescanso) return;

    final raw = ConductorSolicitudPayloadHelper.parsePayload(data);
    final tipo = raw['tipo']?.toString().toLowerCase() ?? '';
    if (tipo.contains('oferta_servicio_exclusiva') ||
        raw['fullscreen'] == true ||
        raw['fullscreen'] == 1 ||
        raw['fullscreen'] == '1') {
      await _aplicarOfertaExclusivaDesdePayload(raw);
      return;
    }

    final servicioId =
        ConductorSolicitudPayloadHelper.servicioIdFromAlertaPayload(raw);

    if (servicioId != null) {
      final payload = raw.isNotEmpty
          ? raw
          : <String, dynamic>{
              'servicio_id': servicioId,
              'solicitud_id': servicioId,
              'id': servicioId,
            };
      _procesarNuevaSolicitud(payload, mostrarEnOverlay: true);
      unawaited(sincronizarSolicitudesPublicadasConductor());
      return;
    }

    await sincronizarSolicitudesPublicadasConductor();
  }

  /// Procesa una nueva solicitud (Pusher, sync API o alerta FCM).
  void _procesarNuevaSolicitud(
    dynamic data, {
    bool isDirectOffer = false,
    bool fromSync = false,
    bool mostrarEnOverlay = false,
  }) {
    if (_enServicio) {
      AppLogger.d('ℹ️ Ignorando nueva solicitud: conductor en servicio');
      return;
    }
    if (_enDescanso) {
      AppLogger.d('ℹ️ Ignorando nueva solicitud: conductor en descanso');
      return;
    }

    try {
      final raw = ConductorSolicitudPayloadHelper.parsePayload(data);

      if (ConductorOfertaExclusiva.tryFromDynamic(raw) != null && !fromSync) {
        unawaited(_aplicarOfertaExclusivaDesdePayload(raw));
        return;
      }

      if (!isDirectOffer &&
          ConductorOfertaIndriverHelper.ignorarNuevaSolicitudPublica(
            raw,
            tengoOfertaExclusivaActiva: _ofertaExclusiva != null,
            miOfertaExclusivaServicioId: _ofertaExclusiva?.servicioId,
          )) {
        AppLogger.d(
          'ℹ️ Ignorando nueva-solicitud (fase exclusiva / oferta activa para otro)',
        );
        return;
      }

      if (ConductorOfertaIndriverHelper.esFaseExclusiva(raw) && !isDirectOffer) {
        AppLogger.d('ℹ️ Ignorando solicitud en fase exclusiva (canal público)');
        return;
      }
      if (_esServicioRechazadoEnPayload(raw)) {
        AppLogger.d('ℹ️ Ignorando solicitud: rechazada por este conductor');
        return;
      }
      final solicitud = ConductorSolicitudPayloadHelper.normalizarSolicitud(
        raw,
        isDirectOffer: isDirectOffer,
      );
      var solicitudId = ConductorSolicitudPayloadHelper.obtenerSolicitudId(solicitud);
      if (solicitudId == null || solicitudId.isEmpty) {
        solicitudId = ConductorSolicitudPayloadHelper.generarSolicitudTemporalId();
        solicitud['temp_id'] = solicitudId;
        solicitud['solicitud_id'] = solicitud['solicitud_id'] ?? solicitudId;
        solicitud['servicio_id'] = solicitud['servicio_id'] ?? solicitudId;
        solicitud['id'] = solicitud['id'] ?? solicitudId;
        AppLogger.d('ℹ️ Solicitud sin id, asignando temporal: $solicitudId');
      }
      solicitud['_local_id'] = solicitudId;

      if (esServicioRechazado(solicitudId)) {
        AppLogger.d('ℹ️ Ignorando solicitud rechazada: $solicitudId');
        return;
      }

      final existente = _solicitudesPorId[solicitudId];
      final esNueva = existente == null;
      if (esNueva) {
        AppLogger.d('📩 Nueva solicitud: $solicitudId');
      }
      final overlayEstabaOculto =
          !esNueva && _overlayOcultoPorTtl.contains(solicitudId);
      _solicitudesPorId[solicitudId] = existente != null
          ? {...existente, ...solicitud}
          : solicitud;
      ConductorSolicitudPayloadHelper.anclarExpiracionCola(
        _solicitudesPorId[solicitudId]!,
        anterior: existente,
      );
      if (ConductorSolicitudPayloadHelper.tieneExpiracionColaActiva(
        _solicitudesPorId[solicitudId]!,
      )) {
        _iniciarTickerExpiracionUI();
      }

      // Sync API también debe mostrar tarjeta en «Llegando» (no solo sonido + «En espera»).
      final enOverlay = mostrarEnOverlay || !fromSync || esNueva;
      final solicitudMap = _solicitudesPorId[solicitudId]!;
      if (enOverlay) {
        if (esNueva || overlayEstabaOculto) {
          _aplicarOverlayLlegando(
            solicitudId,
            solicitud: solicitudMap,
            esNueva: esNueva || overlayEstabaOculto,
          );
          unawaited(
            _enriquecerPoiTrasMostrar(
              solicitudId,
              esNueva: esNueva || overlayEstabaOculto,
            ).catchError((_) {}),
          );
        } else {
          _aplicarOverlayLlegando(
            solicitudId,
            solicitud: solicitudMap,
            esNueva: false,
          );
        }
      } else {
        if (esNueva) {
          _overlayOcultoPorTtl.add(solicitudId);
        }
        unawaited(
          _enriquecerDireccionesSolicitud(solicitudId).catchError((_) {}),
        );
      }

      final visibleEnLlegando =
          enOverlay && !_overlayOcultoPorTtl.contains(solicitudId);
      if (esNueva && visibleEnLlegando && !fromSync) {
        _dispararSonidoNuevaSolicitud(solicitudId);
      }

      if (!_isDisposed) notifyListeners();
    } catch (e, st) {
      AppLogger.e(
        'Error procesando solicitud Pusher',
        tag: 'ConductorHome',
        error: e,
        stackTrace: st,
      );
    }
  }

  void _aplicarOverlayLlegando(
    String solicitudId, {
    required Map<String, dynamic> solicitud,
    required bool esNueva,
  }) {
    _marcarRecibidaPorRealtime(solicitudId);
    _overlayOcultoPorTtl.remove(solicitudId);
    if (esNueva) {
      unawaited(_notificarYEnriquecerSolicitud(solicitudId));
    } else {
      unawaited(_enriquecerDireccionesSolicitud(solicitudId));
    }

    final expiraEn =
        ConductorSolicitudPayloadHelper.resolverOverlayExpiraEn(solicitud);
    final ttlSegundos =
        ConductorSolicitudPayloadHelper.resolverTtlSegundos(solicitud);
    _expiracionPorSolicitud[solicitudId] = expiraEn ??
        DateTime.now().add(Duration(seconds: ttlSegundos));
    _configurarTimerExpiracion(solicitudId, ttlSegundos: ttlSegundos);
    _iniciarTickerExpiracionUI();
    _notificarNuevaSolicitudExterna(_solicitudesPorId[solicitudId]!);
  }

  Future<void> _notificarYEnriquecerSolicitud(String solicitudId) async {
    try {
      await _enriquecerDireccionesSolicitud(solicitudId);
      if (_isDisposed) return;
      final solicitud = _solicitudesPorId[solicitudId];
      if (solicitud == null) return;

      final showAlert = await AppLifecycleHelper.shouldShowIncomingServiceAlert();
      if (showAlert) {
        await IncomingServiceNotificationService.instance.showIncomingService(
          solicitud,
        );
      } else {
        AppDiagnostics.record(
          'incoming',
          'tarjeta en app (sin notificación full-screen)',
          extra: 'id=$solicitudId',
        );
      }
    } catch (e, st) {
      AppLogger.e(
        'Error enriqueciendo/notificando solicitud',
        tag: 'ConductorHome',
        error: e,
        stackTrace: st,
      );
    }
  }

  /// POI/nombres extra sin bloquear la tarjeta «Llegando» (antes esperaba Places y no pintaba UI).
  Future<void> _enriquecerPoiTrasMostrar(
    String solicitudId, {
    required bool esNueva,
  }) async {
    if (_isDisposed) return;

    await _enriquecerPoiAntesDeAlerta(solicitudId).timeout(
      const Duration(seconds: 5),
      onTimeout: () {},
    );

    if (_isDisposed) return;
    if (esNueva) {
      await _enriquecerDireccionesSolicitud(solicitudId).timeout(
        const Duration(seconds: 8),
        onTimeout: () {},
      );
    }
    if (!_isDisposed) notifyListeners();
  }

  Future<void> _enriquecerPoiAntesDeAlerta(String solicitudId) async {
    try {
      final solicitud = _solicitudesPorId[solicitudId];
      if (solicitud == null || _isDisposed) return;
      await _solicitudEnrichment.enrichPickupPoiIfNeeded(solicitud);
    } catch (_) {
      // Red/timeout: opcional.
    }
  }

  Future<void> _enriquecerDireccionesSolicitud(String solicitudId) async {
    try {
      final solicitud = _solicitudesPorId[solicitudId];
      if (solicitud == null || _isDisposed) return;

      if (!SolicitudDisplayHelper.necesitaEnriquecimientoGeocode(solicitud)) {
        return;
      }

      final changed = await _solicitudEnrichment.enrich(solicitud);
      if (changed && !_isDisposed) notifyListeners();
    } catch (_) {
      // Red/timeout: la tarjeta ya tiene datos del API.
    }
  }

  /// Configurar timer de expiración para una solicitud
  void _configurarTimerExpiracion(
    String solicitudId, {
    int ttlSegundos = kOportunidadConductorSegundos,
  }) {
    _timersExpiracion[solicitudId]?.cancel();

    _timersExpiracion[solicitudId] = Timer(Duration(seconds: ttlSegundos), () {
      _expirarSolicitud(solicitudId);
    });
  }

  /// TTL del overlay: oculta tarjeta en «Llegando»; el ítem sigue en el mapa (p. ej. «En espera»).
  void _expirarSolicitud(String solicitudId) {
    if (!_solicitudesPorId.containsKey(solicitudId)) return;
    AppLogger.d('⏱️ Overlay TTL expirado (sigue en lista API): $solicitudId');
    _overlayOcultoPorTtl.add(solicitudId);
    _expiracionPorSolicitud.remove(solicitudId);
    _timersExpiracion.remove(solicitudId);
    _detenerTickerSiNoHaySolicitudes();
    if (!_isDisposed) notifyListeners();
  }

  /// Reproduce el tono elegido por el conductor en ajustes.
  Future<void> _reproducirSonidoNotificacion() async {
    await ConductorNotificationSoundService.playNewServiceSound();
  }

  /// Corta tono, voz y notificación full-screen de solicitud entrante.
  Future<void> detenerAlertasSolicitudEntrante() async {
    await Future.wait([
      ConductorNotificationSoundService.stopNewServiceSound(),
      VoiceAlertService.stop(),
      IncomingServiceNotificationService.instance.dismiss(),
    ]);
  }

  // ==================== MANEJO DE SOLICITUDES ====================

  /// Quita una solicitud del mapa local (tomada por otro, cancelada, rechazo, etc.).
  void rechazarSolicitud(String solicitudId) {
    unawaited(detenerAlertasSolicitudEntrante());
    AppLogger.d('❌ Quitando solicitud del mapa local: $solicitudId');

    final idsAEliminar = <String>{solicitudId};
    for (final entry in _solicitudesPorId.entries) {
      final s = entry.value;
      final obtenido = ConductorSolicitudPayloadHelper.obtenerSolicitudId(s);
      if (obtenido == solicitudId || entry.key == solicitudId) {
        idsAEliminar.add(entry.key);
        if (obtenido != null) idsAEliminar.add(obtenido);
      }
    }

    for (final id in idsAEliminar) {
      _removerSolicitudDelMapa(id);
    }

    _detenerTickerSiNoHaySolicitudes();
    if (!_isDisposed) notifyListeners();
  }

  /// Acepta una solicitud de servicio
  Future<Map<String, dynamic>?> aceptarSolicitud(
    String solicitudId,
    int idVehiculo, {
    double? precioOfertado,
  }) async {
    unawaited(detenerAlertasSolicitudEntrante());
    _marcarAceptacionPropiaEnCurso(solicitudId);
    try {
      _lastAcceptError = null;
      AppLogger.d('✅ Aceptando solicitud: $solicitudId');

      // Validar que el ID no sea nulo o inválido
      if (solicitudId.isEmpty || solicitudId == 'null') {
        throw Exception('ID de servicio inválido: $solicitudId');
      }

      // Cancelar el timer de expiración
      _timersExpiracion[solicitudId]?.cancel();
      _timersExpiracion.remove(solicitudId);

      var precio = precioOfertado ?? 0.0;
      if (precioOfertado == null) {
        final s = _solicitudesPorId[solicitudId];
        if (s != null) {
          precio = JsonPayloadHelper.parseDouble(
            s['precio_ofertado'],
            fallback: 0,
          );
        }
      }

      final response = await _conductorService.aceptarSolicitud(
        servicioId: solicitudId,
        precioOfertado: precio,
      );

      final servicioIdInt = int.tryParse(solicitudId);
      if (servicioIdInt != null) {
        Map<String, dynamic>? detalle;
        final data = response['data'];
        if (data is Map<String, dynamic>) {
          detalle = Map<String, dynamic>.from(data);
        } else if (response['servicio'] != null) {
          detalle = Map<String, dynamic>.from(response);
        }
        await marcarEnServicio(
          servicioId: servicioIdInt,
          detalleNavegacion: detalle,
        );
      }

      _removerSolicitudDelMapa(solicitudId);
      _detenerTickerSiNoHaySolicitudes();

      if (!_isDisposed) notifyListeners();
      return response;
    } on TaxiEnServicioException catch (e) {
      _limpiarMarcaAceptacionPropia();
      _lastAcceptError = e.message;
      if (e.servicioActivoId != null) {
        await marcarEnServicio(servicioId: e.servicioActivoId!);
      }
      return null;
    } catch (e) {
      _limpiarMarcaAceptacionPropia();
      _lastAcceptError = e.toString().replaceAll('Exception: ', '');
      AppLogger.d('❌ Error aceptando solicitud: $e');
      // Si hubo conflicto (otro conductor aceptó), retirar de la cola local.
      if (_lastAcceptError?.toLowerCase().contains('ya fue aceptado') == true) {
        rechazarSolicitud(solicitudId);
      }
      return null;
    }
  }

  // ==================== UBICACIÓN ====================

  /// Inicializa la ubicación del conductor
  Future<void> initializeLocation() async {
    _isLoadingLocation = true;
    _locationMessage = 'Estableciendo conexión satelital...';
    if (!_isDisposed) notifyListeners();

    bool permissionGranted = await _checkAndRequestPermissions();

    if (!permissionGranted) {
      _isLoadingLocation = false;
      _locationMessage = 'Permisos de ubicación denegados';
      if (!_isDisposed) notifyListeners();
      return;
    }

    await _getCurrentLocation();
  }

  Future<void> handleLocationRecoveryAction() async {
    if (_isDisposed) return;

    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _isLoadingLocation = false;
      _locationMessage =
          'Activa la ubicación del dispositivo y vuelve a IntelliTaxi.';
      if (!_isDisposed) notifyListeners();
      await Geolocator.openLocationSettings();
      return;
    }

    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.deniedForever) {
      _isLoadingLocation = false;
      _locationMessage =
          'Activa el permiso de ubicación para IntelliTaxi en ajustes.';
      if (!_isDisposed) notifyListeners();
      await openAppSettings();
      return;
    }

    await initializeLocation();
  }

  /// Verifica y solicita permisos de ubicación
  Future<bool> _checkAndRequestPermissions() async {
    // Verificar si el servicio de ubicación está habilitado
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _locationMessage = 'El servicio de ubicación está deshabilitado';
      if (!_isDisposed) notifyListeners();
      return false;
    }

    // Verificar permisos
    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _locationMessage = 'Permisos de ubicación denegados';
        if (!_isDisposed) notifyListeners();
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      _locationMessage = 'Permisos de ubicación denegados permanentemente';
      if (!_isDisposed) notifyListeners();
      return false;
    }

    return true;
  }

  /// Obtiene la ubicación actual del conductor
  Future<void> _getCurrentLocation() async {
    try {
      if (_currentPosition == null) {
        _locationMessage = 'Obteniendo ubicación GPS...';
        if (!_isDisposed) notifyListeners();
      }

      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );

      if (_isDisposed) return;

      _currentPosition = position;
      _isLoadingLocation = false;
      _locationMessage = 'Ubicación obtenida';
      if (!_isDisposed) notifyListeners();
      _iniciarSeguimientoUbicacion();
      await _sendMapHeartbeat(position, force: true);
      await _requestNotificationPermissionAfterLocation();

      AppLogger.d(
        '📍 Ubicación obtenida: ${position.latitude}, ${position.longitude}',
      );
    } catch (e) {
      AppLogger.d('❌ Error obteniendo ubicación: $e');

      if (_isDisposed) return;

      _isLoadingLocation = false;
      _locationMessage = 'Error obteniendo ubicación: ${e.toString()}';
      if (!_isDisposed) notifyListeners();
    }
  }

  LocationSettings _locationStreamSettings() {
    if (_enServicio) {
      return const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: RuntimePerfFlags.conductorGpsDistanceFilterActive,
      );
    }
    return const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: RuntimePerfFlags.conductorGpsDistanceFilterIdle,
    );
  }

  void _iniciarSeguimientoUbicacion() {
    _detenerSeguimientoUbicacion();

    _locationSubscription = Geolocator.getPositionStream(
      locationSettings: _locationStreamSettings(),
    ).listen(
      _onPositionUpdate,
      onError: (Object e) {
        AppLogger.d('⚠️ Error en stream de ubicación (home): $e');
      },
    );
  }

  void _reconfigurarSeguimientoUbicacion() {
    if (_locationSubscription == null) return;
    _iniciarSeguimientoUbicacion();
  }

  void _detenerSeguimientoUbicacion() {
    _locationSubscription?.cancel();
    _locationSubscription = null;
  }

  void _onPositionUpdate(Position position) {
    if (_isDisposed) return;
    _currentPosition = position;
    unawaited(_sendMapHeartbeat(position));
    _notifyLocationUiIfNeeded(position);
  }

  /// Evita rebuild del home en cada tick GPS; el mapa sigue fluido con intervalo corto.
  void _notifyLocationUiIfNeeded(Position position) {
    final now = DateTime.now();
    final lastAt = _lastLocationUiNotifyAt;
    final lastPos = _lastLocationUiNotifyPosition;

    final minInterval = _enServicio
        ? RuntimePerfFlags.conductorGpsUiMinIntervalNav
        : RuntimePerfFlags.conductorGpsUiMinIntervalIdle;
    final minMoveMeters = _enServicio
        ? RuntimePerfFlags.conductorGpsUiMinMoveMetersNav
        : RuntimePerfFlags.conductorGpsUiMinMoveMetersIdle;

    var shouldNotify = lastAt == null || lastPos == null;
    if (!shouldNotify) {
      if (now.difference(lastAt) >= minInterval) {
        shouldNotify = true;
      } else {
        final moved = Geolocator.distanceBetween(
          lastPos.latitude,
          lastPos.longitude,
          position.latitude,
          position.longitude,
        );
        shouldNotify = moved >= minMoveMeters;
      }
    }

    if (!shouldNotify) return;
    _lastLocationUiNotifyAt = now;
    _lastLocationUiNotifyPosition = position;
    if (!_isDisposed) notifyListeners();
  }

  Future<void> _sendMapHeartbeat(
    Position position, {
    bool force = false,
  }) async {
    if (_isDisposed || !_isOnline || _turnoActivo == null) return;
    // Durante servicio activo el tracking va por servicios/actualizar-ubicacion.
    if (_enServicio && !force) return;
    if (_isSendingMapHeartbeat) return;

    final now = DateTime.now();
    final lastSentAt = _lastMapHeartbeatAt;
    if (!force &&
        lastSentAt != null &&
        now.difference(lastSentAt) < const Duration(seconds: 5)) {
      return;
    }

    _isSendingMapHeartbeat = true;
    try {
      final ubicacion = await _conductorService.actualizarUbicacionMapa(
        lat: position.latitude,
        lng: position.longitude,
        velocidad: position.speed.isFinite && position.speed >= 0
            ? position.speed
            : 0,
        direccion: position.heading.isFinite && position.heading >= 0
            ? position.heading
            : 0,
        estado: _enDescanso ? 'descanso' : 'disponible',
      );
      _lastMapHeartbeatAt = DateTime.now();

      if (ubicacion != null && ubicacion.hasZona) {
        _aplicarZonaDesdeServidor(ubicacion.displayZona, position: position);
      } else {
        await _actualizarZonaActual(position, force: force);
      }
    } catch (e) {
      AppLogger.d('⚠️ No se pudo enviar heartbeat de mapa: $e');
      await _actualizarZonaActual(position, force: force);
    } finally {
      _isSendingMapHeartbeat = false;
    }
  }

  void _aplicarZonaDesdeServidor(String label, {required Position position}) {
    final trimmed = label.trim();
    if (trimmed.isEmpty) return;
    _lastAreaResolvedPosition = position;
    _lastAreaResolvedAt = DateTime.now();
    if (_zonaActual == trimmed) return;
    _zonaActual = trimmed;
    if (!_isDisposed) notifyListeners();
  }

  /// Chip «Tu zona: Cra. 20b» (primordial para el conductor). Nunca se desactiva;
  /// el ahorro es caché + no repetir Geocoding en cada tick de GPS.
  Future<void> _actualizarZonaActual(
    Position position, {
    bool force = false,
  }) async {
    final lastPos = _lastAreaResolvedPosition;
    final lastAt = _lastAreaResolvedAt;
    if (!force && lastPos != null && lastAt != null) {
      final movedMeters = Geolocator.distanceBetween(
        lastPos.latitude,
        lastPos.longitude,
        position.latitude,
        position.longitude,
      );
      final elapsed = DateTime.now().difference(lastAt);
      final minMove = MapsConfig.useBackendProxy
          ? MapsConfig.reverseGeocodeMinMoveMeters
          : RuntimePerfFlags.conductorZonaMinMoveMeters;
      final minInterval = MapsConfig.useBackendProxy
          ? MapsConfig.reverseGeocodeMinInterval
          : RuntimePerfFlags.conductorZonaMinInterval;
      if (movedMeters < minMove && elapsed < minInterval) {
        return;
      }
    }

    var area = await _reverseGeocodingService.resolveZonaConductor(
      lat: position.latitude,
      lng: position.longitude,
    );
    if (area == null || area.trim().isEmpty) {
      area = await _reverseGeocodingService.resolveAreaName(
        lat: position.latitude,
        lng: position.longitude,
      );
    }

    if (area == null || area.trim().isEmpty) {
      // Sin bloquear reintentos: si Google falló, el próximo GPS vuelve a intentar.
      if (kDebugMode) {
        AppLogger.w(
          'Zona conductor vacía (revisar Geocoding API / facturación)',
          tag: 'ZonaConductor',
        );
      }
      return;
    }

    _lastAreaResolvedPosition = position;
    _lastAreaResolvedAt = DateTime.now();

    final label = area.trim();
    if (_zonaActual == label) return;
    _zonaActual = label;
    if (!_isDisposed) notifyListeners();
  }

  Future<void> _requestNotificationPermissionAfterLocation() async {
    if (_isDisposed || _notificationPermissionRequestedInSession) return;
    _notificationPermissionRequestedInSession = true;
    try {
      final status = await Permission.notification.status;
      if (status.isGranted || status.isPermanentlyDenied) return;
      await Permission.notification.request();
    } catch (_) {
      // Silencioso: no bloquear la app por permisos de notificaciones.
    }
  }

  // ==================== VEHÍCULOS ====================

  /// Carga los vehículos disponibles del conductor.
  /// Devuelve `true` si la petición terminó bien (aunque la lista venga vacía).
  Future<bool> cargarVehiculos() async {
    try {
      final vehiculos = await _conductorService.getVehiculosConductor();
      if (_isDisposed) return false;
      _vehiculosDisponibles = vehiculos;
      _lastVehiculosLoadError = null;
      _sincronizarVehiculoSeleccionadoConTurno();
      if (!_isDisposed) notifyListeners();
      return true;
    } catch (e) {
      _lastVehiculosLoadError = e
          .toString()
          .replaceAll('Exception: ', '')
          .trim();
      AppLogger.d('❌ Error cargando vehículos: $e');
      if (!_isDisposed) notifyListeners();
      return false;
    }
  }

  /// Selecciona un vehículo
  void seleccionarVehiculo(VehiculoConductor vehiculo) {
    _vehiculoSeleccionado = vehiculo;
    if (!_isDisposed) notifyListeners();
  }

  // ==================== TURNOS ====================

  /// Carga el turno actual del conductor
  Future<void> cargarTurnoActual() async {
    final teniaTurnoLocal = _turnoActivo != null;
    try {
      final turno = await _conductorService.getTurnoActivo();

      AppLogger.d(
        '🔄 cargarTurnoActual: encontrado=${turno?.id ?? 'null'}',
      );
      if (turno != null) {
        await _aplicarTurnoActivoLocal(turno);
        if (!_isDisposed) notifyListeners();
      } else if (teniaTurnoLocal || _isOnline) {
        AppLogger.d(
          'ℹ️ Sin turno en servidor; limpiando cache local (id=${_turnoActivo?.id})',
        );
        await _limpiarTurnoActivoLocal(clearSelectedVehicle: false);
      }
    } catch (e) {
      AppLogger.d('⚠️ cargarTurnoActual falló (red/servidor), se conserva turno local: $e');
      await _restaurarTurnoTrasFalloDeRed();
    }
  }

  Future<void> _restaurarTurnoTrasFalloDeRed() async {
    if (_turnoActivo != null) {
      _isOnline = true;
      if (!_enDescanso && !_suscritoAPusher) {
        unawaited(conectarPusher());
      }
      if (!_isDisposed) notifyListeners();
      return;
    }
    final ok = await restaurarTurnoDesdeCache();
    if (ok && !_enDescanso) {
      unawaited(conectarPusher());
    }
  }

  /// Al volver a la app: restaura GPS con última posición conocida para no vaciar el mapa.
  Future<void> refrescarUbicacionEnResume() async {
    if (_isDisposed) return;
    try {
      final last = await Geolocator.getLastKnownPosition();
      if (last != null) {
        _currentPosition = last;
        _isLoadingLocation = false;
        _locationMessage = 'Ubicación obtenida';
        if (_locationSubscription == null) {
          _iniciarSeguimientoUbicacion();
        }
        if (!_isDisposed) notifyListeners();
        unawaited(_sendMapHeartbeat(last, force: true));
        return;
      }
    } catch (e) {
      AppLogger.d('⚠️ getLastKnownPosition en resume: $e');
    }

    if (_currentPosition == null) {
      await initializeLocation();
    }
  }

  /// Re-sincroniza turno y heartbeat al volver al foreground (sin borrar turno si falla la red).
  Future<void> refrescarTurnoYHeartbeatEnResume() async {
    if (_isDisposed) return;
    if (_enServicio) return;

    try {
      AppLogger.d(
        '🔄 [Resume] estado antes: isOnline=$_isOnline turno=${_turnoActivo?.id} enDescanso=$_enDescanso',
      );

      if (_turnoActivo == null) {
        await restaurarTurnoDesdeCache();
      }

      await cargarTurnoActual();

      if (_turnoActivo == null || !_isOnline) {
        return;
      }

      Position? position = _currentPosition;
      if (position == null) {
        try {
          position = await Geolocator.getLastKnownPosition();
        } catch (_) {}
      }
      if (position == null) {
        try {
          position = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
              timeLimit: Duration(seconds: 6),
            ),
          );
        } catch (e) {
          AppLogger.d('⚠️ [Resume] sin GPS puntual: $e');
        }
      }
      if (position != null) {
        _currentPosition = position;
        await _sendMapHeartbeat(position, force: true);
      }

      if (!_isDisposed) notifyListeners();

      AppLogger.d(
        '✅ [Resume] estado después: isOnline=$_isOnline turno=${_turnoActivo?.id} enDescanso=$_enDescanso',
      );
    } catch (e) {
      AppLogger.d('⚠️ [Resume] Error refrescando turno/heartbeat: $e');
      await _restaurarTurnoTrasFalloDeRed();
    }
  }

  /// Inicia un turno con el vehículo seleccionado
  Future<bool> iniciarTurno(int idVehiculo) async {
    try {
      _lastTurnoError = null;
      VehiculoConductor? vehiculo;
      for (final item in _vehiculosDisponibles) {
        if (item.id == idVehiculo) {
          vehiculo = item;
          break;
        }
      }
      if (vehiculo != null && !vehiculo.puedeOperarPorVinculacion) {
        throw Exception(
          'No puedes operar este vehículo: ${vehiculo.motivoBloqueoVinculacion}',
        );
      }

      final turnoExistente = await _conductorService.getTurnoActivo();
      if (turnoExistente != null) {
        if (turnoExistente.idVehiculo == idVehiculo) {
          await _aplicarTurnoActivoLocal(turnoExistente);
          return true;
        }
        throw Exception(
          'Ya tienes un turno activo con otro vehículo. Finalízalo antes de cambiar.',
        );
      }

      // Obtener ubicación actual
      Position? position = _currentPosition;

      if (position == null) {
        try {
          position = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
              timeLimit: Duration(seconds: 5),
            ),
          );
        } catch (e) {
          AppLogger.d('⚠️ Error obteniendo ubicación: $e');
          throw Exception('No se pudo obtener la ubicación');
        }
      }

      // Llamar al servicio para iniciar turno
      final turno = await _conductorService.iniciarTurno(
        idVehiculo,
        lat: position.latitude,
        lng: position.longitude,
      );

      await _aplicarTurnoActivoLocal(turno);
      await _sendMapHeartbeat(position, force: true);
      return true;
    } catch (e) {
      _lastTurnoError = e.toString().replaceAll('Exception: ', '').trim();
      AppLogger.d('❌ Error iniciando turno: $e');
      if (!_isDisposed) notifyListeners();
      return false;
    }
  }

  Future<void> _aplicarTurnoActivoLocal(TurnoActivo turno) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('turno_activo_id', turno.id);
    await prefs.setInt('turno_vehiculo_id', turno.idVehiculo);
    await prefs.setString('turno_fecha', turno.fechaTurno);
    await prefs.setString('turno_hora_inicio', turno.horaInicio);

    _turnoActivo = turno;
    _isOnline = true;
    _enDescanso = false;
    _recibeServicios = true;
    _visibleEnMapa = true;
    _sincronizarVehiculoSeleccionadoConTurno();
    await conectarPusher();
    final pos = _currentPosition;
    if (pos != null) {
      unawaited(_sendMapHeartbeat(pos, force: true));
    }
    if (!_isDisposed) notifyListeners();
  }

  /// Finaliza el turno actual (por id; si 403, intenta `finalizar-activo`).
  Future<bool> finalizarTurno() async {
    if (_turnoActivo == null) return false;

    _lastTurnoError = null;
    final idTurno = _turnoActivo!.id;

    try {
      await _conductorService.finalizarTurno(idTurno);
      await _limpiarTurnoActivoLocal();
      return true;
    } catch (e) {
      AppLogger.d('❌ Error finalizando turno $idTurno: $e');

      final dioStatus = e is DioException ? e.response?.statusCode : null;
      final mensaje = e.toString().replaceAll('Exception: ', '').trim();
      final puedeReintentar =
          dioStatus == 403 || dioStatus == 404 || mensaje.contains('autorizado');

      if (puedeReintentar) {
        try {
          await _conductorService.finalizarTurnoActivo();
          await _limpiarTurnoActivoLocal();
          AppLogger.d('✅ Turno cerrado vía finalizar-activo');
          return true;
        } catch (e2) {
          AppLogger.d('⚠️ finalizar-activo falló: $e2');
        }

        final activo = await _conductorService.getTurnoActivo();
        if (activo == null) {
          AppLogger.d(
            'ℹ️ Backend sin turno abierto; limpiando estado local obsoleto',
          );
          await _limpiarTurnoActivoLocal();
          return true;
        }
      }

      _lastTurnoError = mensaje.isNotEmpty
          ? mensaje
          : 'No se pudo finalizar el turno';
      if (!_isDisposed) notifyListeners();
      return false;
    }
  }

  /// Toggle del estado online/offline
  Future<void> toggleOnlineStatus() async {
    if (!_isOnline) {
      // Activándose: mostrar selector de vehículo o iniciar turno si ya hay uno seleccionado
      if (_vehiculoSeleccionado != null) {
        await iniciarTurno(_vehiculoSeleccionado!.id);
      }
    } else {
      // Desactivándose: finalizar turno
      await finalizarTurno();
    }
  }

  void _sincronizarVehiculoSeleccionadoConTurno() {
    if (_turnoActivo == null) return;

    final idVehiculoTurno = _turnoActivo!.idVehiculo;
    final match = _vehiculosDisponibles
        .where((v) => v.id == idVehiculoTurno)
        .toList();

    if (match.isNotEmpty) {
      _vehiculoSeleccionado = match.first;
      return;
    }

    // Fallback: usar vehículo embebido del turno cuando la lista aún no llega.
    if (_turnoActivo!.vehiculo != null) {
      _vehiculoSeleccionado = _turnoActivo!.vehiculo;
    }
  }

  /// Verifica documentos del conductor
  Future<Map<String, dynamic>> verificarDocumentos(int userId) async {
    try {
      return await _conductorService.verificarDocumentos(userId);
    } catch (e) {
      AppLogger.d('❌ Error verificando documentos: $e');
      return {'vencidos': [], 'porVencer': []};
    }
  }

  /// Verifica si un vehículo debe bloquearse por documentos vencidos.
  Future<Map<String, dynamic>> verificarBloqueoVehiculo(int idVehiculo) async {
    try {
      return await _conductorService.verificarBloqueoVehiculo(idVehiculo);
    } catch (e) {
      AppLogger.d('❌ Error verificando bloqueo de vehículo: $e');
      return {
        'bloqueado': false,
        'vencidos': <DocumentoVehiculo>[],
        'porVencer': <DocumentoVehiculo>[],
        'documentos': <DocumentoVehiculo>[],
      };
    }
  }

  /// Cancelar servicio activo
  Future<bool> cancelarServicio({
    required int servicioId,
    required String motivo,
  }) async {
    try {
      AppLogger.d('🚫 Cancelando servicio: $servicioId');

      await _conductorService.cancelarServicio(
        servicioId: servicioId,
        motivo: motivo,
      );

      _removerSolicitudDelMapa(servicioId.toString());
      _detenerTickerSiNoHaySolicitudes();

      if (!_isDisposed) notifyListeners();
      return true;
    } catch (e) {
      AppLogger.d('❌ Error cancelando servicio: $e');
      return false;
    }
  }

  int obtenerSegundosRestantes(String solicitudId) {
    if (!_overlayOcultoPorTtl.contains(solicitudId)) {
      final expiracion = _expiracionPorSolicitud[solicitudId];
      if (expiracion != null) {
        final restantes = expiracion.difference(DateTime.now()).inSeconds;
        if (restantes > 0) return restantes;
      }
    }

    final solicitud = _solicitudesPorId[solicitudId];
    if (solicitud != null) {
      final cola = ConductorSolicitudPayloadHelper.segundosRestantesCola(solicitud);
      if (cola != null && cola > 0) return cola;
    }
    return 0;
  }

  void _iniciarTickerExpiracionUI() {
    if (!_hayCuentaRegresivaActiva()) return;
    if (_tickerExpiracionUI != null) return;
    _tickerExpiracionUI = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_isDisposed) return;
      _purgarSolicitudesExpiradas();
      _detenerTickerSiNoHaySolicitudes();
      if (_tickerExpiracionUI != null) {
        notifyListeners();
      }
    });
  }

  bool _hayCuentaRegresivaActiva() {
    if (_expiracionPorSolicitud.isNotEmpty) return true;
    for (final s in _solicitudesPorId.values) {
      if (ConductorSolicitudPayloadHelper.tieneExpiracionColaActiva(s)) {
        return true;
      }
    }
    return false;
  }

  void _detenerTickerSiNoHaySolicitudes() {
    if (!_hayCuentaRegresivaActiva() && _tickerExpiracionUI != null) {
      _tickerExpiracionUI?.cancel();
      _tickerExpiracionUI = null;
    }
  }

  void _purgarSolicitudesExpiradas() {
    if (_expiracionPorSolicitud.isEmpty) return;
    final now = DateTime.now();
    final expiradas = _expiracionPorSolicitud.entries
        .where((entry) => !entry.value.isAfter(now))
        .map((entry) => entry.key)
        .toList();

    for (final solicitudId in expiradas) {
      _expirarSolicitud(solicitudId);
    }
  }

  Future<bool> finalizarTurnoActivoAnterior() async {
    try {
      final finalizado = await _turnoService.finalizarTurnoActivo();

      if (!finalizado) return false;

      await _limpiarTurnoActivoLocal(clearSelectedVehicle: false);
      return true;
    } catch (e) {
      AppLogger.d('❌ Error finalizando turno anterior: $e');
      return false;
    }
  }

  Future<void> _limpiarTurnoActivoLocal({
    bool clearSelectedVehicle = true,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('turno_activo_id');
    await prefs.remove('turno_vehiculo_id');
    await prefs.remove('turno_fecha');
    await prefs.remove('turno_hora_inicio');

    await desconectarPusher();

    _turnoActivo = null;
    _isOnline = false;
    _enDescanso = false;
    _recibeServicios = true;
    _visibleEnMapa = true;
    if (clearSelectedVehicle) {
      _vehiculoSeleccionado = null;
    }
    _solicitudesPorId.clear();
    _overlayOcultoPorTtl.clear();
    _expiracionPorSolicitud.clear();
    _tickerExpiracionUI?.cancel();
    _tickerExpiracionUI = null;

    if (!_isDisposed) notifyListeners();
  }
}
