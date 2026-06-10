import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intellitaxi/core/services/app_logger.dart';
import 'package:intellitaxi/core/services/incoming_service_alert_service.dart';
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
import 'package:intellitaxi/features/taxi/utils/taxi_socket_channels.dart';
import 'package:intellitaxi/config/socket_service.dart';

import 'package:intellitaxi/core/utils/api_rate_limit_guard.dart';
import 'package:intellitaxi/core/utils/dio_error_message.dart';
import 'package:intellitaxi/features/auth/services/auth_service.dart';
import 'package:intellitaxi/core/services/driver_overlay_service.dart';
import 'package:intellitaxi/features/conductor/utils/conductor_overlay_badge_store.dart';
import 'package:intellitaxi/features/conductor/conductor_constants.dart';
import 'package:intellitaxi/features/conductor/services/conductor_solicitud_enrichment_service.dart';
import 'package:intellitaxi/features/conductor/utils/conductor_session_helper.dart';
import 'package:intellitaxi/features/conductor/utils/conductor_solicitud_payload_helper.dart';
import 'package:intellitaxi/features/conductor/utils/conductor_solicitud_distance_helper.dart';
import 'package:intellitaxi/features/conductor/utils/conductor_solicitud_ranking_helper.dart';
import 'package:intellitaxi/features/conductor/data/conductor_oferta_exclusiva.dart';
import 'package:intellitaxi/features/conductor/utils/conductor_oferta_indriver_helper.dart';
import 'package:intellitaxi/features/conductor/utils/conductor_socket_payload_router.dart';
import 'package:intellitaxi/features/conductor/services/conductor_oferta_navigation.dart';
import 'package:intellitaxi/features/conductor/utils/oferta_exclusiva_display.dart';
import 'package:intellitaxi/main.dart';
import 'package:intellitaxi/core/diagnostics/app_diagnostics.dart';
import 'package:intellitaxi/core/services/background_location_service.dart';
import 'package:intellitaxi/core/utils/app_lifecycle_helper.dart';
import 'package:intellitaxi/core/services/servicio_payload_adapter.dart';
import 'package:intellitaxi/core/utils/json_payload_helper.dart';
import 'package:intellitaxi/features/taxi/utils/servicio_espera_timer.dart';

export 'package:intellitaxi/features/conductor/conductor_constants.dart';

/// Provider para gestionar toda la lógica de la pantalla home del conductor
/// Incluye: ubicación, turnos, vehículos, solicitudes de servicio y conexión a Pusher.

class ConductorHomeProvider extends ChangeNotifier {
  // Servicios
  final ConductorService _conductorService = ConductorService();
  // Estado de ubicación
  Position? _currentPosition;
  bool _isLoadingLocation = true;
  String _locationMessage =
      'Estableciendo conexión satelital para rastreo en tiempo real...';
  String? _zonaActual;
  StreamSubscription<Position>? _locationSubscription;
  Timer? _locationPollFallbackTimer;
  Future<void>? _locationStreamStartFuture;
  Position? _lastAreaResolvedPosition;
  DateTime? _lastAreaResolvedAt;
  DateTime? _lastLocationUiNotifyAt;
  Position? _lastLocationUiNotifyPosition;
  DateTime? _lastMapHeartbeatAt;
  Position? _lastMapHeartbeatPosition;
  bool _isSendingMapHeartbeat = false;
  bool _streamGpsActivo = false;
  DateTime? _lastResumeRefreshAt;
  bool _resumeRefreshInFlight = false;
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

  /// true tras confirmar turno (o su ausencia) con el API en esta sesión.
  bool _turnoValidadoConServidorEnSesion = false;

  // Solicitudes: un mapa por servicio_id. API = verdad de lista; Pusher/FCM = merge;
  // TTL solo oculta overlay «Llegando»; el ítem sigue en mapa / «En espera».
  final Map<String, Map<String, dynamic>> _solicitudesPorId = {};
  final Set<String> _overlayOcultoPorTtl = {};
  final Map<String, DateTime> _recibidaPorRealtimeEn = {};
  /// Evita procesar el mismo id 2× en ráfaga (público + privado / Pusher + FCM).
  final Map<String, DateTime> _ultimoRealtimeProcesadoPorId = {};
  static const Duration _ventanaDedupeRealtime = Duration(seconds: 4);
  final Map<String, DateTime> _sonidoEmitidoPorSolicitudId = {};
  /// Evita 2.º beep si el mismo id sigue en «Llegando» (sync/realtime duplicado).
  final Map<String, DateTime> _silenciarBeepLlegandoHasta = {};
  /// Tras exclusiva: una publicación en «Llegando» y sin ping-pong con «En espera».
  final Set<String> _publicadoLlegandoTrasExclusiva = {};
  final Map<String, DateTime> _mantenerLlegandoTrasExclusivaHasta = {};
  /// Ventana mínima en «Llegando» desde la 1.ª vez visible (evita ~10 s si Pusher/GPS llega tarde).
  final Map<String, DateTime> _minimoLlegandoVisibleHasta = {};
  final Set<String> _vozDireccionLlegandoHecha = {};
  final Map<String, Timer> _timersExpiracion = {};
  final Map<String, DateTime> _expiracionPorSolicitud = {};
  String? _ultimaSyncSolicitudesEn;
  Timer? _tickerExpiracionUI;
  Timer? _syncSolicitudesTimer;
  Timer? _syncSolicitudesDebounceTimer;
  Timer? _syncTrasHeartbeatTimer;
  bool _syncSolicitudesEnCurso = false;
  DateTime? _ultimaSyncSolicitudesAt;
  static const Duration _minIntervaloSyncSolicitudes = Duration(seconds: 30);
  static const Duration _minIntervaloSyncColaVacia = Duration(seconds: 12);
  bool _suscritoASocket = false;
  bool _suscritoEmergenciasFlota = false;
  bool _enServicio = false;
  int? _servicioActivoId;
  Map<String, dynamic>? _servicioActivoPendienteNavegacion;
  final Set<String> _offerChannels = {};
  final Set<String> _offerHandlerKeys = {};
  Future<void>? _desuscribirRecepcionFuture;
  String? _lastAcceptError;
  String? _lastRadioDismissMessage;
  String? _lastTurnoError;
  bool _procesandoTurno = false;
  bool _enDescanso = false;
  bool _recibeServicios = true;
  bool _visibleEnMapa = true;
  bool _cambiandoDescanso = false;
  String? _lastDescansoError;
  final List<void Function(String servicioId)> _solicitudTomadaListeners = [];
  final List<void Function(Map<String, dynamic> solicitud)>
      _nuevaSolicitudListeners = [];
  final Set<int> _serviciosRechazados = {};
  /// Servicios descartados por radio en esta sesión (evita beep duplicado Pusher+FCM).
  final Set<String> _idsDescartadosPorRadio = {};

  /// Asignación empresa (`/solicitudes-pendientes` → `companyAssignmentSettings`).
  bool _listaGlobalSolicitudes = true;
  String? _assignmentMethod;
  double? _driverSearchRadiusKm;
  int? _ofertaExclusivaSegundosEmpresa;
  int? _ofertaMaxIntentosEmpresa;

  /// Oferta inDrive exclusiva (solo este conductor).
  ConductorOfertaExclusiva? _ofertaExclusiva;
  int _ofertaExclusivaSegundos = 0;
  int _ofertaExclusivaTtlInicial = 0;
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
  bool get listaGlobalSolicitudes => _listaGlobalSolicitudes;
  String? get assignmentMethod => _assignmentMethod;
  /// Radio efectivo km (BD vía API). No usar constantes locales para asignación.
  double? get driverSearchRadiusKm => _driverSearchRadiusKm;
  double? get radioKmAsignacion => _driverSearchRadiusKm;
  int? get ofertaExclusivaSegundosEmpresa => _ofertaExclusivaSegundosEmpresa;
  int? get ofertaMaxIntentosEmpresa => _ofertaMaxIntentosEmpresa;

  int get _segundosOfertaEmpresa =>
      _ofertaExclusivaSegundosEmpresa ?? kMantenerLlegandoTrasExclusivaSegundos;

  bool get _filtrarPorRadioAsignacion => !_listaGlobalSolicitudes;

  bool _requiereFiltroRadio(Map<String, dynamic> solicitud) {
    if (_filtrarPorRadioAsignacion) return true;
    return ConductorSocketPayloadRouter.esCercanoBroadcast(solicitud);
  }

  void _marcarPayloadCercanoBroadcast(
    Map<String, dynamic> raw, {
    String? eventName,
  }) {
    if (ConductorSocketPayloadRouter.esCercanoBroadcast(raw)) return;
    final ev = eventName?.toLowerCase() ?? '';
    if (ev.contains('servicio.cercano') || ev.contains('servicio_cercano')) {
      raw.putIfAbsent('notificacion_tipo', () => 'cercano_broadcast');
    }
  }

  bool _dentroDelRadioAsignacion(Map<String, dynamic> solicitud) {
    return _veredictoRadioAsignacion(solicitud) == true;
  }

  /// `false` solo cuando el radio ya se pudo evaluar y queda fuera; `null` = pendiente.
  bool _visibleSegunRadio(Map<String, dynamic> solicitud) {
    if (!_requiereFiltroRadio(solicitud)) return true;
    if (ConductorSolicitudPayloadHelper.esOfertaDirecta(solicitud)) return true;
    return _veredictoRadioAsignacion(solicitud) != false;
  }

  /// `true` dentro, `false` fuera, `null` aún no evaluable (falta GPS/coords/radio).
  bool? _veredictoRadioAsignacion(Map<String, dynamic> solicitud) {
    if (ConductorSolicitudPayloadHelper.esOfertaDirecta(solicitud)) return true;
    if (!_requiereFiltroRadio(solicitud)) return true;
    final radio = _driverSearchRadiusKm;
    if (radio == null || radio <= 0) return null;
    final pos = _currentPosition;
    if (pos == null) return null;
    if (!SolicitudDisplayHelper.origenTieneMapa(solicitud)) return null;
    return ConductorSolicitudDistanceHelper.dentroDelRadioAsignacion(
      solicitud,
      radioKm: radio,
      driverLat: pos.latitude,
      driverLng: pos.longitude,
    );
  }

  void _descartarSolicitudFueraDeRadio(
    Map<String, dynamic> raw, {
    bool avisarSiEstabaVisible = false,
  }) {
    AppLogger.d(
      'ℹ️ Ignorando solicitud fuera de radio '
      '(${_driverSearchRadiusKm ?? "?"} km, modo cercanos)',
    );
    final id = ConductorSolicitudPayloadHelper.obtenerSolicitudId(raw) ??
        ConductorSolicitudPayloadHelper.servicioIdFromAlertaPayload(raw);
    final estabaVisible = id != null &&
        id.isNotEmpty &&
        _solicitudesPorId.containsKey(id) &&
        !_overlayOcultoPorTtl.contains(id);
    if (id != null && id.isNotEmpty) {
      _idsDescartadosPorRadio.add(id);
      _silenciarBeepLlegandoHasta[id] =
          DateTime.now().add(const Duration(minutes: 10));
      IncomingServiceAlertService.bloquearBeep(id);
    }
    if (id != null && id.isNotEmpty && _solicitudesPorId.containsKey(id)) {
      AppLogger.d('ℹ️ Quitando $id (ya estaba en cola, fuera de radio)');
      if (estabaVisible || avisarSiEstabaVisible) {
        unawaited(IncomingServiceAlertService.cancel());
        _lastRadioDismissMessage =
            'Servicio fuera de tu zona (${_driverSearchRadiusKm ?? "?"} km)';
      }
      _removerSolicitudDelMapa(id);
      if (!_isDisposed) notifyListeners();
    }
  }

  bool _esDescartadaPorRadio(String? solicitudId) {
    if (solicitudId == null || solicitudId.isEmpty) return false;
    return _idsDescartadosPorRadio.contains(solicitudId);
  }

  bool _solicitudListaParaOverlay(Map<String, dynamic> solicitud) {
    if (SolicitudDisplayHelper.origenTieneMapa(solicitud)) return true;
    final headline = SolicitudDisplayHelper.pickupHeadline(solicitud);
    return headline.isNotEmpty &&
        !SolicitudDisplayHelper.isPlaceholderPickup(headline);
  }

  void _purgarSolicitudesFueraDeRadio() {
    if (_driverSearchRadiusKm == null) return;
    var removidas = false;
    for (final id in _solicitudesPorId.keys.toList()) {
      final solicitud = _solicitudesPorId[id];
      if (solicitud == null) continue;
      if (ConductorSolicitudPayloadHelper.esOfertaDirecta(solicitud)) continue;
      if (!_requiereFiltroRadio(solicitud)) continue;
      if (_veredictoRadioAsignacion(solicitud) != false) continue;
      AppLogger.d(
        'ℹ️ Quitando $id fuera de radio ($_driverSearchRadiusKm km)',
      );
      _removerSolicitudDelMapa(id);
      removidas = true;
    }
    if (removidas && !_isDisposed) notifyListeners();
  }

  /// Reabre overlays diferidos cuando ya hay GPS, radio y coords de recogida.
  void _reintentarOverlaysPendientesRadio() {
    if (_isDisposed || _overlayOcultoPorTtl.isEmpty) return;
    var cambio = false;
    for (final id in _overlayOcultoPorTtl.toList()) {
      final solicitud = _solicitudesPorId[id];
      if (solicitud == null) continue;
      if (!_requiereFiltroRadio(solicitud)) continue;
      if (_veredictoRadioAsignacion(solicitud) == false) continue;
      if (!_solicitudListaParaOverlay(solicitud)) continue;
      _aplicarOverlayLlegando(
        id,
        solicitud: solicitud,
        esNueva: false,
      );
      cambio = true;
    }
    if (cambio && !_isDisposed) notifyListeners();
  }

  bool _esOfertaExclusivaActiva(String? solicitudId) =>
      solicitudId != null && _ofertaExclusiva?.solicitudId == solicitudId;

  bool _perteneceTabEspera(Map<String, dynamic> solicitud, String id) {
    if (_esOfertaExclusivaActiva(id) || !_visibleSegunRadio(solicitud)) {
      return false;
    }
    if (ConductorOfertaIndriverHelper.esBroadcastRebote(solicitud)) {
      return false;
    }
    if (ConductorSolicitudPayloadHelper.usaConductorTabApi(solicitud)) {
      return ConductorSolicitudPayloadHelper.esTabEspera(solicitud) &&
          obtenerSegundosRestantes(id) > 0;
    }
    return _overlayOcultoPorTtl.contains(id) &&
        ConductorSolicitudPayloadHelper.segundosRestantesEspera(solicitud) > 0;
  }

  bool _perteneceTabLlegando(Map<String, dynamic> solicitud, String id) {
    if (_esOfertaExclusivaActiva(id) || !_visibleSegunRadio(solicitud)) {
      return false;
    }
    if (ConductorOfertaIndriverHelper.esBroadcastRebote(solicitud)) {
      if (solicitud['en_lista_espera'] == true) return false;
      final seg = obtenerSegundosRestantes(id);
      if (seg > 0) return true;
      return ConductorSolicitudPayloadHelper.segundosCountdownLlegando(solicitud) >
          0;
    }
    if (_enMinimoLlegandoVisible(id) || _mantenerEnLlegandoTrasExclusiva(id)) {
      return obtenerSegundosRestantes(id) > 0 || _enMinimoLlegandoVisible(id);
    }
    if (ConductorSolicitudPayloadHelper.usaConductorTabApi(solicitud)) {
      return ConductorSolicitudPayloadHelper.esTabLlegando(solicitud) &&
          obtenerSegundosRestantes(id) > 0;
    }
    return !_overlayOcultoPorTtl.contains(id);
  }

  /// Pestaña «En espera»: `conductor_tab == espera` y countdown de cola abierta.
  List<Map<String, dynamic>> get solicitudesEnEsperaOrdenadas {
    if (_enServicio || _enDescanso) return const [];
    final solicitudes = _solicitudesPorId.values
        .where((s) {
          final id = ConductorSolicitudPayloadHelper.obtenerSolicitudId(s);
          return id != null && _perteneceTabEspera(s, id);
        })
        .toList();
    solicitudes.sort(ConductorSolicitudRankingHelper.compararRecientesPrimero);
    return solicitudes;
  }

  int get totalSolicitudesEnEspera => solicitudesEnEsperaOrdenadas.length;

  /// «A 450 m de ti» hasta la recogida (GPS actual; API solo si no hay fix).
  String distanciaDesdeConductorTexto(Map<String, dynamic> solicitud) {
    final pos = _currentPosition;
    if (pos != null) {
      final meters = ConductorSolicitudDistanceHelper.metersToPickup(
        solicitud,
        driverLat: pos.latitude,
        driverLng: pos.longitude,
      );
      if (meters != null) {
        return ConductorSolicitudDistanceHelper.labelDesdeConductor(meters);
      }
    }
    return ConductorSolicitudDistanceHelper.resolveLabel(
          solicitud,
          driverLat: pos?.latitude,
          driverLng: pos?.longitude,
        ) ??
        '';
  }

  Map<String, dynamic>? buscarSolicitudPorId(String solicitudId) =>
      _solicitudesPorId[solicitudId];
  String? get lastAcceptError => _lastAcceptError;
  String? takeLastRadioDismissMessage() {
    final msg = _lastRadioDismissMessage;
    _lastRadioDismissMessage = null;
    return msg;
  }
  String? get lastTurnoError => _lastTurnoError;
  bool get procesandoTurno => _procesandoTurno;
  bool get enDescanso => _enDescanso;
  bool get visibleEnMapa => _visibleEnMapa;
  bool get recibeServicios => _recibeServicios && !_enDescanso;
  bool get cambiandoDescanso => _cambiandoDescanso;
  String? get lastDescansoError => _lastDescansoError;
  bool get puedeUsarModoDescanso =>
      _isOnline && !_enServicio && _turnoActivo != null;

  /// Cola local con solicitudes aún no visibles (p. ej. conductor fuera de línea).
  bool get tieneColaSolicitudesLocal =>
      !_enServicio && !_enDescanso && _solicitudesPorId.isNotEmpty;

  static const _pendingSyncKey = 'conductor_pending_solicitudes_sync';
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
          return id != null && _perteneceTabLlegando(s, id);
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
    double? radioKm,
  }) {
    final radioEfectivo = radioKm ?? _driverSearchRadiusKm;
    final radioMetros = radioEfectivo != null && radioEfectivo > 0
        ? radioEfectivo * 1000
        : null;
    final candidatas = _solicitudesOrdenadasTodas().where((s) {
      final idStr = ConductorSolicitudPayloadHelper.obtenerSolicitudId(s);
      if (idStr == null || idStr.isEmpty) return false;
      final idNum = int.tryParse(idStr);
      if (excluirServicioId != null &&
          idNum != null &&
          idNum == excluirServicioId) {
        return false;
      }

      if (!_dentroDelRadioAsignacion(s)) return false;

      final lat = SolicitudDisplayHelper.parseCoordinate(s['origen_lat']);
      final lng = SolicitudDisplayHelper.parseCoordinate(s['origen_lng']);
      if (lat == null || lng == null) return true;
      if (radioMetros == null) return true;

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

  /// Tras wake/FCM: no borrar turno local si el API aún no respondió.
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

  /// Inicializar el provider (valida turno primero; el resto no bloquea el chip).
  Future<void> initialize() async {
    unawaited(_completarInicializacionLenta());

    Future<void> bootstrapSeguro() async {
      try {
        await bootstrapTaxiConductor().timeout(const Duration(seconds: 8));
      } catch (e) {
        AppLogger.d('⚠️ bootstrapTaxiConductor en arranque: $e', tag: 'Turno');
      }
    }

    Future<void> turnoSeguro() async {
      if (_enServicio) return;
      try {
        await cargarTurnoActual(restaurarCacheSiFallaRed: false).timeout(
          const Duration(seconds: 15),
        );
      } catch (e) {
        AppLogger.d('⚠️ cargarTurnoActual en arranque: $e', tag: 'Turno');
      }
    }

    await Future.wait([bootstrapSeguro(), turnoSeguro()]);
  }

  Future<void> _completarInicializacionLenta() async {
    try {
      await Future.wait([
        _initUbicacionConTimeout(),
        cargarVehiculos(),
      ]);
      await cargarSolicitudesRechazadas();
      unawaited(resolverSolicitudesPendientesTrasArranque());
    } catch (e) {
      AppLogger.d('⚠️ _completarInicializacionLenta: $e');
    }
  }

  Future<void> _initUbicacionConTimeout() async {
    try {
      await initializeLocation().timeout(const Duration(seconds: 12));
    } on TimeoutException {
      _isLoadingLocation = false;
      if (_currentPosition == null) {
        _locationMessage =
            'El GPS tardó demasiado. Toca reintentar para continuar.';
      }
      if (!_isDisposed) notifyListeners();
      AppLogger.d('⏱️ initializeLocation timeout en arranque', tag: 'Turno');
    }
  }

  Future<void> _marcarSolicitudesPendientesDeSync() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_pendingSyncKey, true);
  }

  /// Tras FCM en segundo plano o estando fuera de línea: alinear cola con el API.
  Future<void> resolverSolicitudesPendientesTrasArranque() async {
    final prefs = await SharedPreferences.getInstance();
    final habiaMarca = prefs.getBool(_pendingSyncKey) ?? false;
    if (habiaMarca) {
      await prefs.remove(_pendingSyncKey);
    }
    if (!_isOnline || _enServicio || _enDescanso) return;
    if (!habiaMarca && _solicitudesPorId.isEmpty) return;
    // Si el socket ya está activo, la alineación inicial va diferida en conectarSocket.
    if (_suscritoASocket) return;
    await sincronizarSolicitudesPublicadasConductor();
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
        if (!estado.turnoActivo) {
          final prefs = await SharedPreferences.getInstance();
          final cacheId = prefs.getInt('turno_activo_id');
          if (_turnoActivo != null ||
              _isOnline ||
              (cacheId != null && cacheId > 0)) {
            AppLogger.d(
              'ℹ️ estado-actual: sin turno activo; limpiando cache local',
              tag: 'Turno',
            );
            await _limpiarTurnoActivoLocal(clearSelectedVehicle: false);
          }
        }

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

    if (detalleNavegacion != null) {
      final nav =
          ServicioPayloadAdapter.unwrapNavegacionPayload(detalleNavegacion) ??
              detalleNavegacion;
      _servicioActivoPendienteNavegacion = nav;
    }

    if (!_isDisposed) notifyListeners();

    // No bloquear el POST de aceptación: socket/WhatsApp van afterResponse en backend.
    unawaited(_desuscribirCanalSolicitudesServicio());

    if (_servicioActivoPendienteNavegacion == null && servicioActivoId != null) {
      unawaited(() async {
        final detalle = await _fetchServicioActivoDetalle();
        if (detalle != null && !_isDisposed) {
          _servicioActivoPendienteNavegacion = detalle;
          notifyListeners();
        }
      }());
    }

    final pos = _currentPosition;
    if (pos != null) {
      unawaited(_sendMapHeartbeat(pos, force: true));
    }

    _syncGpsConEstadoTurno();
    if (!_isDisposed) notifyListeners();
  }

  /// Libera conductor tras finalizar/cancelar viaje.
  Future<void> marcarDisponible() async {
    _enServicio = false;
    _servicioActivoId = null;
    _servicioActivoPendienteNavegacion = null;
    _limpiarColaSolicitudesLocal();

    await _sincronizarModoDescansoDesdeBackend();

    unawaited(cargarTurnoActual());

    if (_isOnline && !_enDescanso && !_suscritoASocket) {
      await conectarSocket();
    }

    final pos = _currentPosition;
    if (pos != null) {
      // Re-sincroniza disponible en mapa flota; el viaje usó servicios/actualizar-ubicacion.
      unawaited(_sendMapHeartbeat(pos, force: true));
    }

    _syncGpsConEstadoTurno();
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
        await conectarSocket();
        await _sendMapHeartbeat(position, force: true);
      }

      _syncGpsConEstadoTurno();

      if (!_isDisposed) notifyListeners();
      return true;
    } catch (e) {
      _lastDescansoError = _mensajeParaUsuario(
        e,
        'No se pudo cambiar el modo descanso. Intenta de nuevo.',
      );
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
    _silenciarBeepLlegandoHasta.clear();
    _publicadoLlegandoTrasExclusiva.clear();
    _mantenerLlegandoTrasExclusivaHasta.clear();
    _vozDireccionLlegandoHecha.clear();
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
    _publicadoLlegandoTrasExclusiva.remove(solicitudId);
    _mantenerLlegandoTrasExclusivaHasta.remove(solicitudId);
    _minimoLlegandoVisibleHasta.remove(solicitudId);
    _vozDireccionLlegandoHecha.remove(solicitudId);
  }

  void _marcarRecibidaPorRealtime(String solicitudId) {
    _recibidaPorRealtimeEn[solicitudId] = DateTime.now();
  }

  bool _esRealtimeDuplicado(String solicitudId) {
    final now = DateTime.now();
    final prev = _ultimoRealtimeProcesadoPorId[solicitudId];
    if (prev != null && now.difference(prev) < _ventanaDedupeRealtime) {
      return true;
    }
    _ultimoRealtimeProcesadoPorId[solicitudId] = now;
    return false;
  }

  String _textoVozRecogidaLlegando(Map<String, dynamic> solicitud) {
    var texto = OfertaExclusivaDisplay.textoParaVozRecogida(solicitud).trim();
    if (texto.isNotEmpty) return texto;

    final n = SolicitudDisplayHelper.normalizeSolicitudMap(solicitud);
    final origen = n['origen']?.toString().trim() ?? '';
    if (origen.isNotEmpty &&
        !SolicitudDisplayHelper.isPlaceholderPickup(origen)) {
      return SolicitudDisplayHelper.formatReadablePlaceName(origen);
    }
    return '';
  }

  /// Tras beep: lee recogida cuando el geocode/POI ya enriqueció la tarjeta.
  Future<void> _anunciarDireccionLlegandoTrasEnriquecer(String solicitudId) async {
    if (_isDisposed || _vozDireccionLlegandoHecha.contains(solicitudId)) return;
    if (_overlayOcultoPorTtl.contains(solicitudId)) return;
    if (_esOfertaExclusivaActiva(solicitudId)) return;

    try {
      await _enriquecerPoiAntesDeAlerta(solicitudId).timeout(
        const Duration(seconds: 4),
        onTimeout: () {},
      );
      await _enriquecerDireccionesSolicitud(solicitudId).timeout(
        const Duration(seconds: 6),
        onTimeout: () {},
      );
    } catch (_) {}

    if (_isDisposed || _vozDireccionLlegandoHecha.contains(solicitudId)) return;
    if (_overlayOcultoPorTtl.contains(solicitudId)) return;

    final solicitud = _solicitudesPorId[solicitudId];
    if (solicitud == null) return;

    final texto = _textoVozRecogidaLlegando(solicitud);
    if (texto.isEmpty) return;

    _vozDireccionLlegandoHecha.add(solicitudId);
    await VoiceAlertService.announceNewServiceWithAddress(texto);
  }

  /// Beep (+ voz con dirección de recogida) al entrar en «Llegando».
  void _dispararSonidoNuevaSolicitud(
    String solicitudId, {
    Map<String, dynamic>? solicitud,
    bool decirNuevoServicioEnVoz = true,
    bool beepInmediato = false,
  }) {
    if (_isDisposed || _enServicio || _enDescanso || !_isOnline) return;

    _sonidoEmitidoPorSolicitudId[solicitudId] = DateTime.now();

    final tipo = decirNuevoServicioEnVoz ? 'llegando' : 'exclusiva';
    final textoVoz = decirNuevoServicioEnVoz && solicitud != null
        ? _textoVozRecogidaLlegando(solicitud)
        : '';

    if (textoVoz.isNotEmpty) {
      _vozDireccionLlegandoHecha.add(solicitudId);
    }

    unawaited(
      IncomingServiceAlertService.alert(
        includeVoice: decirNuevoServicioEnVoz,
        dedupeKey: '$solicitudId:$tipo',
        beepInmediato: beepInmediato,
        direccionVoz: textoVoz.isNotEmpty ? textoVoz : null,
      ),
    );

    if (decirNuevoServicioEnVoz &&
        textoVoz.isEmpty &&
        solicitud != null &&
        !_vozDireccionLlegandoHecha.contains(solicitudId)) {
      unawaited(_anunciarDireccionLlegandoTrasEnriquecer(solicitudId));
    }
  }

  bool _beepLlegandoSilenciado(String solicitudId) {
    final hasta = _silenciarBeepLlegandoHasta[solicitudId];
    if (hasta == null) return false;
    if (DateTime.now().isAfter(hasta)) {
      _silenciarBeepLlegandoHasta.remove(solicitudId);
      return false;
    }
    return true;
  }

  void _marcarBeepLlegandoRecienEmitido(String solicitudId) {
    _silenciarBeepLlegandoHasta[solicitudId] =
        DateTime.now().add(const Duration(seconds: 12));
  }

  bool _mantenerEnLlegandoTrasExclusiva(String solicitudId) {
    final hasta = _mantenerLlegandoTrasExclusivaHasta[solicitudId];
    if (hasta == null) return false;
    if (DateTime.now().isAfter(hasta)) {
      _mantenerLlegandoTrasExclusivaHasta.remove(solicitudId);
      return false;
    }
    return true;
  }

  bool _enMinimoLlegandoVisible(String solicitudId) {
    final hasta = _minimoLlegandoVisibleHasta[solicitudId];
    if (hasta == null) return false;
    if (DateTime.now().isAfter(hasta)) {
      _minimoLlegandoVisibleHasta.remove(solicitudId);
      return false;
    }
    return true;
  }

  void _marcarMinimoLlegandoVisible(String solicitudId, int segundos) {
    if (segundos <= 0) return;
    _minimoLlegandoVisibleHasta[solicitudId] =
        DateTime.now().add(Duration(seconds: segundos));
  }

  /// Al mostrar la tarjeta por 1.ª vez: al menos [oferta_exclusiva_segundos] de BD.
  int _segundosLlegandoAlMostrar(
    Map<String, dynamic> solicitud, {
    required bool primeraVista,
  }) {
    final segApi =
        ConductorSolicitudPayloadHelper.segundosCountdownLlegando(solicitud);
    if (!primeraVista) return segApi > 0 ? segApi : 0;
    final minimo = _segundosOfertaEmpresa;
    if (minimo <= 0) return segApi > 0 ? segApi : 0;
    if (segApi <= 0) return minimo;
    return segApi > minimo ? segApi : minimo;
  }

  void _marcarMantenerEnLlegandoTrasExclusiva(String solicitudId) {
    _mantenerLlegandoTrasExclusivaHasta[solicitudId] = DateTime.now().add(
      Duration(seconds: _segundosOfertaEmpresa),
    );
  }

  /// Al cerrar exclusiva: una vez en «Llegando» + beep; sin rebotes ni sync a espera.
  void _publicarEnLlegandoTrasExclusiva(String solicitudId) {
    if (_isDisposed || _enServicio || _enDescanso || !_isOnline) return;
    if (!_publicadoLlegandoTrasExclusiva.add(solicitudId)) return;

    var solicitud = _solicitudesPorId[solicitudId];
    if (solicitud == null) return;

    final anterior = Map<String, dynamic>.from(solicitud);
    solicitud = Map<String, dynamic>.from(solicitud)
      ..['fase_oferta'] = 'abierta'
      ..['oferta_exclusiva'] = false
      ..remove('status');
    ConductorSolicitudPayloadHelper.anclarOverlayExpiraEn(
      solicitud,
      anterior: anterior,
    );
    _solicitudesPorId[solicitudId] = solicitud;
    _marcarMantenerEnLlegandoTrasExclusiva(solicitudId);

    _aplicarOverlayLlegando(
      solicitudId,
      solicitud: solicitud,
      esNueva: true,
      forzarBeepLlegando: true,
    );
    _programarSyncSolicitudesTrasEvento();
    if (!_isDisposed) notifyListeners();
  }

  /// No borrar en sync si acaba de llegar por Pusher/FCM o sigue en «Llegando».
  bool _conservarEnMapaTrasSync(String id) {
    final item = _solicitudesPorId[id];
    if (item != null &&
        !ConductorSolicitudPayloadHelper.esOfertaDirecta(item) &&
        _requiereFiltroRadio(item) &&
        !_dentroDelRadioAsignacion(item)) {
      return false;
    }
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
    unawaited(_detenerHeartbeatMapaSegundoPlano());
    _detenerPollOfertaActiva();
    _detenerTickOfertaExclusiva();
    SocketService.removeReconnectListener(_onSocketReconectado);
    VoiceAlertService.dispose();
    desconectarSocket();
    super.dispose();
  }

  // ==================== CONEXIÓN SOCKET ====================

  void _onSocketReconectado() {
    if (_isDisposed || !_isOnline || _enServicio || _enDescanso) return;
    AppLogger.d('🔄 Pusher reconectado: alinear cola con API (diferido)');
    _programarSyncInicialTrasConexionSocket();
    _iniciarSincronizacionSolicitudes();
  }

  /// Conecta a Pusher y se suscribe al canal de solicitudes
  Future<void> conectarSocket() async {
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
      SocketService.addReconnectListener(_onSocketReconectado);

      if (_suscritoASocket) {
        AppLogger.d('⚠️ Ya está suscrito a solicitudes-servicio');
        return;
      }

      AppLogger.d('🔌 Suscribiéndose al canal de solicitudes...');

      await SocketService.initialize();
      await SocketService.subscribeSecondary(TaxiSocketChannels.solicitudesServicio);

      // Registrar handlers para variantes del evento de nuevas solicitudes
      for (final eventName in const [
        TaxiSocketEvents.nuevaSolicitud,
        'nueva_solicitud',
        'nueva-oferta',
        'nueva_oferta',
      ]) {
        SocketService.registerEventHandlerSecondary(
          '${TaxiSocketChannels.solicitudesServicio}:$eventName',
          (data) {
            AppLogger.d('🔔 Evento recibido: $eventName');
            if (data != null) {
              _procesarPayloadSocket(data, eventName: eventName);
            }
          },
        );
      }

      for (final eventName in const [
        TaxiSocketEvents.solicitudTomada,
        'solicitud_tomada',
      ]) {
        SocketService.registerEventHandlerSecondary(
          '${TaxiSocketChannels.solicitudesServicio}:$eventName',
          (data) {
            if (data != null) _procesarSolicitudTomada(data);
          },
        );
      }

      final idsConductor =
          await ConductorSessionHelper.obtenerIdsConductorSesion();
      final candidateChannels =
          ConductorSessionHelper.canalesOfertaDirecta(idsConductor);
      if (candidateChannels.isNotEmpty) {
        for (final channel in candidateChannels) {
          await SocketService.subscribeSecondary(channel);
          _offerChannels.add(channel);

          for (final eventName in const [
            'oferta.directa',
            'oferta_directa',
            'oferta-directa',
          ]) {
            final key = '$channel:$eventName';
            _offerHandlerKeys.add(key);
            SocketService.registerEventHandlerSecondary(key, (data) {
              AppLogger.d('🔔 Evento privado: $eventName en $channel');
              if (data != null) {
                _procesarPayloadSocket(data, eventName: eventName);
              }
            });
          }

          for (final eventName in const [
            TaxiSocketEvents.servicioCercano,
            'servicio_cercano',
          ]) {
            final key = '$channel:$eventName';
            _offerHandlerKeys.add(key);
            SocketService.registerEventHandlerSecondary(key, (data) {
              AppLogger.d('🔔 Evento privado: $eventName en $channel');
              if (data != null) {
                _procesarPayloadSocket(data, eventName: eventName);
              }
            });
          }

          for (final eventName in const [
            TaxiSocketEvents.ofertaServicioExclusiva,
            'oferta.servicio.exclusiva',
          ]) {
            final key = '$channel:$eventName';
            _offerHandlerKeys.add(key);
            SocketService.registerEventHandlerSecondary(key, (data) {
              AppLogger.d('🔔 Evento privado: $eventName en $channel');
              if (data != null) {
                _procesarPayloadSocket(data, eventName: eventName);
              }
            });
          }

          for (final eventName in const [
            TaxiSocketEvents.ofertaServicioCerrada,
            'oferta.servicio.cerrada',
          ]) {
            final key = '$channel:$eventName';
            _offerHandlerKeys.add(key);
            SocketService.registerEventHandlerSecondary(key, (data) {
              AppLogger.d('🔔 Evento privado: $eventName en $channel');
              if (data != null) {
                _procesarPayloadSocket(data, eventName: eventName);
              }
            });
          }

          // `nueva-solicitud` solo en `solicitudes-servicio` (evita doble tarjeta/beep).
          // Fase cercana: `servicio.cercano` en canal privado.
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

      _suscritoASocket = true;
      _iniciarSincronizacionSolicitudes();
      _reprogramarPollOfertaActiva();
      unawaited(sincronizarSolicitudesPublicadasConductor(forzar: true));
      _programarSyncInicialTrasConexionSocket();
      AppLogger.d('✅ Suscrito correctamente al canal de solicitudes');
    } catch (e) {
      AppLogger.d('❌ Error al conectarse al socket: $e');
      if (_isOnline && !_enServicio && !_enDescanso) {
        _iniciarSincronizacionSolicitudes();
      }
    }
  }

  void _iniciarSincronizacionSolicitudes() {
    if (_enServicio || _enDescanso) return;
    _programarProximoPollSolicitudes();
  }

  Duration _intervaloPollSolicitudes() {
    if (!_suscritoASocket) {
      return const Duration(
        seconds: kPollSolicitudesPendientesSinSocketSegundos,
      );
    }
    final tieneCola = _solicitudesPorId.isNotEmpty;
    return Duration(
      seconds: tieneCola
          ? kPollSolicitudesPendientesConSocketColaSegundos
          : kPollSolicitudesPendientesConSocketVacioSegundos,
    );
  }

  void _programarProximoPollSolicitudes() {
    _syncSolicitudesTimer?.cancel();
    if (_isDisposed || _enServicio || _enDescanso) return;

    _syncSolicitudesTimer = Timer(_intervaloPollSolicitudes(), () {
      if (!_isDisposed &&
          _isOnline &&
          !_enDescanso &&
          !ApiRateLimitGuard.instance.isBlocked) {
        sincronizarSolicitudesPublicadasConductor();
      }
      _programarProximoPollSolicitudes();
    });
  }

  /// Una sola alineación tras conectar Pusher (no en ráfaga con arranque/turno).
  void _programarSyncInicialTrasConexionSocket() {
    if (_isDisposed || !_isOnline || _enServicio || _enDescanso) return;
    _syncSolicitudesDebounceTimer?.cancel();
    _syncSolicitudesDebounceTimer = Timer(
      const Duration(seconds: kSyncSolicitudesTrasConexionSocketSegundos),
      () async {
        if (_isDisposed || !_isOnline || _enServicio || _enDescanso) return;
        await sincronizarOfertaActiva();
        if (_isDisposed || !_isOnline || _enServicio || _enDescanso) return;
        await sincronizarSolicitudesPublicadasConductor();
      },
    );
  }

  /// Alineación diferida tras Pusher/FCM (el payload ya actualizó la UI).
  void _programarSyncSolicitudesTrasEvento() {
    if (_isDisposed || !_isOnline || _enServicio || _enDescanso) return;
    _syncSolicitudesDebounceTimer?.cancel();
    _syncSolicitudesDebounceTimer = Timer(
      const Duration(seconds: kSyncSolicitudesTrasEventoSegundos),
      () {
        if (_isDisposed || !_isOnline || _enServicio || _enDescanso) return;
        sincronizarSolicitudesPublicadasConductor();
      },
    );
  }

  void _detenerSincronizacionSolicitudes() {
    _syncSolicitudesTimer?.cancel();
    _syncSolicitudesTimer = null;
    _syncSolicitudesDebounceTimer?.cancel();
    _syncSolicitudesDebounceTimer = null;
    _syncTrasHeartbeatTimer?.cancel();
    _syncTrasHeartbeatTimer = null;
  }

  Duration _minIntervaloSyncEfectivo() =>
      _solicitudesPorId.isEmpty
          ? _minIntervaloSyncColaVacia
          : _minIntervaloSyncSolicitudes;

  /// Si el backend indexó ubicación pero no hubo Pusher privado, alinear por API.
  void _programarSyncTrasHeartbeatUbicacion() {
    if (_isDisposed || !_isOnline || _enServicio || _enDescanso) return;
    if (_solicitudesPorId.isNotEmpty) return;
    _syncTrasHeartbeatTimer?.cancel();
    _syncTrasHeartbeatTimer = Timer(
      const Duration(seconds: kSyncSolicitudesTrasHeartbeatSegundos),
      () {
        if (_isDisposed || !_isOnline || _enServicio || _enDescanso) return;
        sincronizarSolicitudesPublicadasConductor();
      },
    );
  }

  /// Alinea la cola local con el backend (otro conductor aceptó, realtime perdido, etc.).
  Future<void> sincronizarSolicitudesPublicadasConductor({
    bool propagarError = false,
    bool forzar = false,
  }) async {
    if (_isDisposed || !_isOnline || _enServicio || _enDescanso) return;
    if (ApiRateLimitGuard.instance.isBlocked) {
      AppLogger.d(
        '⏭️ Sync solicitudes omitido (rate limit ${ApiRateLimitGuard.instance.secondsRemaining}s)',
      );
      return;
    }
    if (_syncSolicitudesEnCurso) {
      AppLogger.d('⏭️ Sync solicitudes omitido (ya en curso)');
      return;
    }
    final ultima = _ultimaSyncSolicitudesAt;
    if (!forzar &&
        ultima != null &&
        DateTime.now().difference(ultima) < _minIntervaloSyncEfectivo()) {
      return;
    }
    _syncSolicitudesEnCurso = true;
    try {
      final result = await _conductorService.getSolicitudesPendientes(
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

      _listaGlobalSolicitudes = result.listaGlobal;
      _assignmentMethod = result.assignmentMethod;
      _driverSearchRadiusKm = result.driverSearchRadiusKm;
      _ofertaExclusivaSegundosEmpresa = result.ofertaExclusivaSegundos;
      _ofertaMaxIntentosEmpresa = result.ofertaMaxIntentos;

      final list = result.pendientes;
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
        } else {
          final item = _solicitudesPorId[id];
          if (item != null &&
              _requiereFiltroRadio(item) &&
              !ConductorSolicitudPayloadHelper.esOfertaDirecta(item) &&
              _veredictoRadioAsignacion(item) == false) {
            _removerSolicitudDelMapa(id);
          }
        }
      }

      for (final m in list) {
        final map = m;
        final sid = map['servicio_id'] ?? map['solicitud_id'] ?? map['id'];
        if (sid != null) {
          final sidStr = sid.toString();
          if (!_listaGlobalSolicitudes &&
              !ConductorSolicitudPayloadHelper.esOfertaDirecta(map) &&
              ConductorOfertaIndriverHelper.esFaseExclusiva(map) &&
              !ConductorOfertaIndriverHelper.esAsignacionColaParaMi(map) &&
              _ofertaExclusiva?.solicitudId != sidStr) {
            continue;
          }
          final esNuevaEnMapa = !_solicitudesPorId.containsKey(sidStr);
          final tuvoRealtime = _recibidaPorRealtimeEn.containsKey(sidStr);
          _recibidaPorRealtimeEn.remove(sidStr);
          _procesarNuevaSolicitud(map, fromSync: true);
          if (esNuevaEnMapa && !tuvoRealtime) {
            AppLogger.d(
              'DIAG [sync] solicitud solo por API (sin Pusher previo) | id=$sidStr',
            );
          }
          continue;
        }
        _procesarNuevaSolicitud(map, fromSync: true);
      }

      _purgarSolicitudesFueraDeRadio();
      _reintentarOverlaysPendientesRadio();
      _iniciarTickerExpiracionUI();
      _ultimaSyncSolicitudesAt = DateTime.now();
      if (!_isDisposed) notifyListeners();
    } catch (e) {
      ApiRateLimitGuard.instance.recordIfRateLimit(e);
      if (ApiRateLimitGuard.looksLikeRateLimit(e)) {
        AppLogger.d(
          '⏭️ Sync solicitudes: rate limit servidor '
          '(cooldown ${ApiRateLimitGuard.instance.secondsRemaining}s)',
        );
      } else {
        AppLogger.d('⚠️ Sync solicitudes publicadas: $e');
      }
      if (propagarError) rethrow;
    } finally {
      _syncSolicitudesEnCurso = false;
    }
  }

  /// Desconecta de Pusher
  Future<void> desconectarSocket() async {
    try {
      await _desuscribirRecepcionServicios();
      await _desuscribirEmergenciasFlota();
      AppLogger.d('✅ Desconectado del socket');
    } catch (e) {
      AppLogger.d('❌ Error al desconectar socket: $e');
    }
  }

  Future<void> _desuscribirRecepcionServicios() async {
    final inFlight = _desuscribirRecepcionFuture;
    if (inFlight != null) {
      await inFlight;
      return;
    }

    final task = _desuscribirRecepcionServiciosImpl();
    _desuscribirRecepcionFuture = task;
    try {
      await task;
    } finally {
      if (identical(_desuscribirRecepcionFuture, task)) {
        _desuscribirRecepcionFuture = null;
      }
    }
  }

  Future<void> _desuscribirRecepcionServiciosImpl() async {
    _detenerSincronizacionSolicitudes();
    _detenerPollOfertaActiva();
    for (final eventName in const [
      TaxiSocketEvents.nuevaSolicitud,
      'nueva_solicitud',
      'nueva-oferta',
      'nueva_oferta',
      TaxiSocketEvents.solicitudTomada,
      'solicitud_tomada',
    ]) {
      SocketService.unregisterEventHandlerSecondary(
        '${TaxiSocketChannels.solicitudesServicio}:$eventName',
      );
    }
    try {
      await SocketService.unsubscribeSecondary(
        TaxiSocketChannels.solicitudesServicio,
      );
    } catch (_) {}

    for (final key in _offerHandlerKeys.toList(growable: false)) {
      SocketService.unregisterEventHandlerSecondary(key);
    }
    _offerHandlerKeys.clear();

    for (final channel in _offerChannels.toList(growable: false)) {
      await SocketService.unsubscribeSecondary(channel);
    }
    _offerChannels.clear();

    _suscritoASocket = false;
  }

  Future<void> _desuscribirCanalSolicitudesServicio() async {
    await _desuscribirRecepcionServicios();
  }

  void _marcarAceptacionPropiaEnCurso(String servicioId) {
    _servicioIdAceptacionPropia = servicioId;
    _aceptacionPropiaEn = DateTime.now();
  }

  /// Al tocar Aceptar: marca antes del POST para ignorar `oferta.cerrada` inmediato.
  void prepararAceptacionOfertaExclusiva() {
    final sid = _ofertaExclusiva?.solicitudId;
    if (sid != null) _marcarAceptacionPropiaEnCurso(sid);
  }

  void cancelarAceptacionOfertaEnUi() {
    _limpiarMarcaAceptacionPropia();
  }

  void _limpiarMarcaAceptacionPropia() {
    _servicioIdAceptacionPropia = null;
    _aceptacionPropiaEn = null;
  }

  bool _esAceptacionPropiaReciente(String servicioId) {
    if (_servicioIdAceptacionPropia != servicioId) return false;
    final t = _aceptacionPropiaEn;
    if (t == null) return false;
    return DateTime.now().difference(t) <
        Duration(seconds: _segundosOfertaEmpresa);
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

  /// Poll adaptativo: 12 s con pantalla grande abierta; 45 s si hay oferta en segundo plano.
  void _reprogramarPollOfertaActiva() {
    _detenerPollOfertaActiva();
    if (_isDisposed || !_isOnline || _enServicio || _enDescanso) return;

    final pantalla = ConductorOfertaNavigation.pantallaVisible;
    if (!pantalla && _ofertaExclusiva == null) return;

    final segundos = pantalla
        ? kPollOfertaActivaPantallaSegundos
        : kPollOfertaActivaFondoSegundos;
    _ofertaExclusivaPollTimer = Timer.periodic(
      Duration(seconds: segundos),
      (_) => unawaited(sincronizarOfertaActiva()),
    );
  }

  void notificarPantallaOfertaExclusivaAbierta() =>
      _reprogramarPollOfertaActiva();

  void notificarPantallaOfertaExclusivaCerrada() =>
      _reprogramarPollOfertaActiva();

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
        unawaited(_manejarOfertaExclusivaExpiradaLocal());
        return;
      }
      if (!_isDisposed) notifyListeners();
    });
  }

  void _actualizarSegundosOfertaDesdeExpira(DateTime expira) {
    final rest = expira.difference(DateTime.now()).inSeconds;
    _ofertaExclusivaSegundos = rest > 0 ? rest : 0;
  }

  DateTime? _parseExpiraOfertaExclusiva(String? raw) =>
      ServicioEsperaTimer.parseExpiraEn(raw);

  /// Fija [expiraEn] solo en oferta nueva o si el servidor acorta el plazo (nunca sube el contador).
  void _fijarExpiraOfertaExclusiva({
    required String solicitudId,
    required ConductorOfertaExclusiva oferta,
  }) {
    final expiraServidor = _parseExpiraOfertaExclusiva(
          oferta.expiraEn ??
              oferta.raw['oferta_expira_en']?.toString() ??
              oferta.raw['expira_en']?.toString() ??
              oferta.raw['overlay_expira_en']?.toString(),
        ) ??
        ServicioEsperaTimer.parseExpiraEn(
          oferta.raw['oferta_expira_en'] ??
              oferta.raw['expira_en'] ??
              oferta.raw['overlay_expira_en'],
        );
    final seg = ServicioEsperaTimer.segundosOferta(oferta.raw);
    final candidataDesdePayload = expiraServidor ??
        (seg > 0 ? DateTime.now().add(Duration(seconds: seg)) : null);

    if (candidataDesdePayload == null) return;

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
      _ofertaExclusivaTtlInicial = rest > 0 ? rest : (seg > 0 ? seg : 0);
    }

    if (_ofertaExclusivaExpiraEn != null) {
      _actualizarSegundosOfertaDesdeExpira(_ofertaExclusivaExpiraEn!);
    }
  }

  /// Cierra la UI al llegar a 0 s y confirma con el API (rotación sin depender de Pusher).
  Future<void> _manejarOfertaExclusivaExpiradaLocal() async {
    if (_isDisposed) return;
    final sid = _ofertaExclusiva?.solicitudId;
    _detenerTickOfertaExclusiva();
    _limpiarOfertaExclusivaLocal(
      cerrarPantalla: true,
      mensaje: 'El tiempo para responder terminó',
    );
    if (sid != null && sid.isNotEmpty) {
      _publicarEnLlegandoTrasExclusiva(sid);
    }
    unawaited(sincronizarOfertaActiva());
  }

  Future<void> sincronizarOfertaActiva() async {
    if (_isDisposed || !_isOnline || _enServicio || _enDescanso) return;
    if (ApiRateLimitGuard.instance.isBlocked) return;
    try {
      final result = await _conductorService.getOfertaActiva();
      if (result.tieneOferta && result.oferta != null) {
        await _aplicarOfertaExclusivaDesdePayload(
          result.oferta!,
          abrirPantalla: !ConductorOfertaNavigation.pantallaVisible,
        );
      } else if (_ofertaExclusiva != null) {
        _limpiarOfertaExclusivaLocal(
          cerrarPantalla: ConductorOfertaNavigation.pantallaVisible,
        );
      }
    } catch (e) {
      ApiRateLimitGuard.instance.recordIfRateLimit(e);
      if (!ApiRateLimitGuard.looksLikeRateLimit(e)) {
        AppLogger.d('⚠️ sincronizarOfertaActiva: $e');
      }
    } finally {
      _reprogramarPollOfertaActiva();
    }
  }

  Future<void> _aplicarOfertaExclusivaDesdePayload(
    dynamic data, {
    bool abrirPantalla = true,
  }) async {
    if (_isDisposed || _enServicio || _enDescanso) return;

    final oferta = ConductorOfertaExclusiva.tryFromDynamic(data);
    if (oferta == null) return;

    if (ServicioEsperaTimer.ofertaExpirada(oferta.raw)) {
      _limpiarOfertaExclusivaLocal(
        cerrarPantalla: ConductorOfertaNavigation.pantallaVisible,
      );
      return;
    }

    final sid = oferta.solicitudId;
    if (esServicioRechazado(sid)) return;

    final esMismaOferta =
        _ofertaExclusiva?.solicitudId == sid && _ofertaExclusivaExpiraEn != null;

    _ofertaExclusiva = oferta;
    _fijarExpiraOfertaExclusiva(solicitudId: sid, oferta: oferta);
    _iniciarTickOfertaExclusiva();

    final solicitud = ConductorSolicitudPayloadHelper.normalizarSolicitud(
      oferta.toSolicitudMap(),
      isDirectOffer: oferta.esDirecta,
    );
    solicitud['_local_id'] = sid;
    if (oferta.esDirecta) {
      solicitud['status'] = 'oferta_directa';
      solicitud['notificacion_tipo'] = 'oferta_directa';
    } else {
      solicitud['fase_oferta'] = 'exclusiva';
      solicitud['oferta_exclusiva'] = true;
    }
    _solicitudesPorId[sid] = solicitud;
    _overlayOcultoPorTtl.remove(sid);

    _marcarRecibidaPorRealtime(sid);
    if (!esMismaOferta) {
      // Oferta exclusiva: solo sonido; la dirección la dice TTS en la pantalla.
      _dispararSonidoNuevaSolicitud(sid, decirNuevoServicioEnVoz: false);
    }

    if (abrirPantalla && !ConductorOfertaNavigation.pantallaVisible) {
      unawaited(ConductorOfertaNavigation.abrirOfertaExclusiva(oferta));
    }
    if (!_isDisposed) notifyListeners();

    unawaited(() async {
      final showAlert =
          await AppLifecycleHelper.shouldShowIncomingServiceAlert();
      if (showAlert && !_isDisposed) {
        await IncomingServiceNotificationService.instance.showIncomingService(
          solicitud,
        );
      }
      await enriquecerOfertaExclusivaActiva();
      if (!_isDisposed) notifyListeners();
    }());
    _reprogramarPollOfertaActiva();
  }

  /// POI + geocode para que la pantalla/TTS de oferta exclusiva tengan recogida legible.
  Future<void> enriquecerOfertaExclusivaActiva() async {
    final sid = _ofertaExclusiva?.solicitudId;
    if (sid == null || sid.isEmpty || _isDisposed) return;
    await _enriquecerPoiAntesDeAlerta(sid);
    await _enriquecerDireccionesSolicitud(sid);
  }

  bool _motivoOfertaCerradaPorMi(String motivo) {
    return motivo == 'aceptada' ||
        motivo == 'asignada' ||
        motivo == 'tomada' ||
        motivo == 'aceptada_por_conductor' ||
        motivo == 'aceptada_por_mi';
  }

  void _procesarOfertaCerrada(dynamic data) {
    try {
      final raw = ConductorSolicitudPayloadHelper.parsePayload(data);
      final sid = raw['servicio_id']?.toString() ??
          raw['solicitud_id']?.toString();
      if (sid == null || sid.isEmpty) return;

      // POST aceptar en vuelo: no cerrar overlay; navegación la hace el HTTP 200.
      if (_esAceptacionPropiaReciente(sid)) {
        AppLogger.d(
          'ℹ️ oferta.cerrada ignorada (aceptación HTTP en curso): $sid',
        );
        return;
      }

      final motivo = raw['motivo']?.toString().toLowerCase() ?? '';
      final eraMiExclusiva = _ofertaExclusiva?.solicitudId == sid;

      // Expiración: mensaje inmediato (no es auto-aceptación).
      if (eraMiExclusiva && motivo == 'expirada') {
        _limpiarOfertaExclusivaLocal(
          cerrarPantalla: true,
          mensaje: 'La oferta expiró',
        );
        _publicarEnLlegandoTrasExclusiva(sid);
      } else if (_listaGlobalSolicitudes &&
          !eraMiExclusiva &&
          (motivo == 'max_intentos' ||
              motivo == 'expirada' ||
              motivo == 'rechazada')) {
        _publicarEnLlegandoTrasExclusiva(sid);
      }

      // No mostrar «otro conductor» en sincrónico: Pusher puede llegar ms después del POST 200 propio.
      unawaited(() async {
        final yoLoTome = await _yoTomeServicioSegunPayload(sid, raw);
        if (_isDisposed) return;

        if (eraMiExclusiva) {
          if (motivo == 'expirada') return;

          if (yoLoTome || _motivoOfertaCerradaPorMi(motivo)) {
            _limpiarOfertaExclusivaLocal(
              cerrarPantalla: ConductorOfertaNavigation.pantallaVisible,
            );
            _limpiarMarcaAceptacionPropia();
            return;
          }

          final mensaje = motivo == 'tomada_por_otro'
              ? 'Otro conductor tomó este servicio'
              : 'La oferta ya no está disponible';
          _limpiarOfertaExclusivaLocal(
            cerrarPantalla: true,
            mensaje: mensaje,
          );
          return;
        }

        if (!yoLoTome && motivo == 'tomada_por_otro') {
          rechazarSolicitud(sid);
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
    _ofertaExclusivaTtlInicial = 0;
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
    if (!_isDisposed) {
      notifyListeners();
    }
    _reprogramarPollOfertaActiva();
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
    return aceptarSolicitud(
      oferta.solicitudId,
      vehiculoId,
      precioOfertado: oferta.precioEstimado,
    );
  }

  /// Tras POST 200: cierra overlay, limpia estado y marca de aceptación en curso.
  void finalizarAceptacionOfertaEnUi({bool cerrarPantalla = true}) {
    if (cerrarPantalla) {
      ConductorOfertaNavigation.cerrarSiVisible();
    } else {
      ConductorOfertaNavigation.marcarReemplazada();
    }
    _limpiarOfertaExclusivaLocal(cerrarPantalla: false);
    _limpiarMarcaAceptacionPropia();
  }

  /// Tras POST 200: limpia estado local sin esperar `oferta.servicio.cerrada`.
  void limpiarOfertaExclusivaTrasAceptacionHttp() {
    finalizarAceptacionOfertaEnUi();
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
      await SocketService.subscribeSecondary(channel);
      for (final eventName in const [
        'nueva-emergencia',
        'nueva_emergencia',
        'emergencia-conductor',
        'emergencia_conductor',
        'emergencia-nueva',
      ]) {
        SocketService.registerEventHandlerSecondary(
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
      SocketService.unregisterEventHandlerSecondary('$channel:$eventName');
    }
    await SocketService.unsubscribeSecondary(channel);
    _suscritoEmergenciasFlota = false;
  }

  /// Enruta payload Pusher/FCM: `notificacion_tipo` > nombre evento > overlay (§5 spec).
  void _procesarPayloadSocket(dynamic data, {String? eventName}) {
    if (_isDisposed || _enServicio || _enDescanso) return;
    if (_isOnline) _programarSyncSolicitudesTrasEvento();

    final raw = ConductorSolicitudPayloadHelper.parsePayload(data);
    switch (ConductorSocketPayloadRouter.accionParaPayload(
      raw,
      eventName: eventName,
    )) {
      case ConductorSocketAccion.overlayFullscreen:
        unawaited(_aplicarOfertaExclusivaDesdePayload(raw));
        break;
      case ConductorSocketAccion.cerrarOverlay:
        _procesarOfertaCerrada(raw);
        break;
      case ConductorSocketAccion.mergeColaCercano:
        _marcarPayloadCercanoBroadcast(raw, eventName: eventName);
        if (ConductorSolicitudPayloadHelper.esOfertaDirecta(raw) ||
            ConductorSocketPayloadRouter.requiereOverlayFullscreen(raw)) {
          unawaited(_aplicarOfertaExclusivaDesdePayload(raw));
        } else {
          _procesarNuevaSolicitud(raw, mostrarEnOverlay: true);
        }
        break;
      case ConductorSocketAccion.mergeCola:
        if (ConductorSolicitudPayloadHelper.esOfertaDirecta(raw) ||
            ConductorSocketPayloadRouter.requiereOverlayFullscreen(raw)) {
          unawaited(_aplicarOfertaExclusivaDesdePayload(raw));
        } else {
          _procesarNuevaSolicitud(raw);
        }
        break;
    }
  }

  /// FCM / alerta: primero tarjeta + sonido; sync después (sin borrar overlay activo).
  Future<void> procesarAlertaSolicitudEntrante(Map<String, dynamic> data) async {
    if (_isDisposed || _enServicio || _enDescanso) return;

    final raw = ConductorSolicitudPayloadHelper.parsePayload(data);
    final notifTipo = ConductorSocketPayloadRouter.notificacionTipo(raw) ?? '';
    if (notifTipo.contains('oferta_servicio_exclusiva') ||
        notifTipo == 'exclusiva_indrive' ||
        notifTipo == 'oferta_directa') {
      if (ConductorOfertaExclusiva.tryFromDynamic(raw) != null) {
        await _aplicarOfertaExclusivaDesdePayload(raw);
      } else {
        await sincronizarOfertaActiva();
      }
      return;
    }

    final accion = ConductorSocketPayloadRouter.accionParaPayload(raw);
    if (accion == ConductorSocketAccion.overlayFullscreen) {
      unawaited(_aplicarOfertaExclusivaDesdePayload(raw));
      return;
    }
    if (accion == ConductorSocketAccion.cerrarOverlay) {
      _procesarOfertaCerrada(raw);
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
      _procesarNuevaSolicitud(
        payload,
        isDirectOffer: ConductorSolicitudPayloadHelper.esOfertaDirecta(raw),
        mostrarEnOverlay: accion == ConductorSocketAccion.mergeColaCercano,
      );
      if (_isOnline) {
        _programarSyncSolicitudesTrasEvento();
      } else {
        await _marcarSolicitudesPendientesDeSync();
      }
      return;
    }

    if (_isOnline) {
      _programarSyncSolicitudesTrasEvento();
    } else {
      await _marcarSolicitudesPendientesDeSync();
    }
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
      final esDirecta =
          isDirectOffer || ConductorSolicitudPayloadHelper.esOfertaDirecta(raw);

      if (esDirecta &&
          ConductorSocketPayloadRouter.requiereOverlayFullscreen(raw)) {
        unawaited(_aplicarOfertaExclusivaDesdePayload(raw));
        return;
      }

      final ofertaExclusiva = ConductorOfertaExclusiva.tryFromDynamic(raw);
      if (ofertaExclusiva != null &&
          !fromSync &&
          !esDirecta &&
          !ConductorSolicitudPayloadHelper.usaConductorTabApi(raw)) {
        final abrirPantalla =
            ConductorOfertaIndriverHelper.esPayloadOfertaExclusivaParaMi(raw) ||
            !_listaGlobalSolicitudes;
        if (abrirPantalla) {
          unawaited(_aplicarOfertaExclusivaDesdePayload(raw));
          return;
        }
      }

      if (!esDirecta &&
          ConductorOfertaIndriverHelper.ignorarNuevaSolicitudPublica(
            raw,
            listaGlobal: _listaGlobalSolicitudes,
            tengoOfertaExclusivaActiva: _ofertaExclusiva != null,
            miOfertaExclusivaServicioId: _ofertaExclusiva?.servicioId,
          )) {
        AppLogger.d(
          'ℹ️ Ignorando nueva-solicitud (fase exclusiva / oferta activa para otro)',
        );
        return;
      }

      if (!_listaGlobalSolicitudes &&
          ConductorOfertaIndriverHelper.esFaseExclusiva(raw) &&
          !esDirecta &&
          !ConductorOfertaIndriverHelper.esAsignacionColaParaMi(raw)) {
        AppLogger.d('ℹ️ Ignorando solicitud en fase exclusiva (canal público)');
        return;
      }

      final metodoAsignacion = raw['assignment_method']?.toString() ??
          raw['assignmentMethod']?.toString();
      if (metodoAsignacion != null && metodoAsignacion.isNotEmpty) {
        _assignmentMethod = metodoAsignacion;
        _listaGlobalSolicitudes = metodoAsignacion.toUpperCase() !=
            'BROADCAST_NEARBY_DRIVERS';
      }
      if (_esServicioRechazadoEnPayload(raw)) {
        AppLogger.d('ℹ️ Ignorando solicitud: rechazada por este conductor');
        return;
      }
      final idTemprano = ConductorSolicitudPayloadHelper.obtenerSolicitudId(raw) ??
          ConductorSolicitudPayloadHelper.servicioIdFromAlertaPayload(raw);
      if (_esDescartadaPorRadio(idTemprano)) {
        AppLogger.d(
          'ℹ️ Ignorando solicitud $idTemprano (descartada por radio en sesión)',
        );
        return;
      }
      if (!esDirecta && _requiereFiltroRadio(raw)) {
        final veredicto = _veredictoRadioAsignacion(raw);
        if (veredicto == false) {
          _descartarSolicitudFueraDeRadio(raw);
          return;
        }
        if (veredicto == null) {
          AppLogger.d(
            'ℹ️ Solicitud cercana en cola local: pendiente GPS/coords/radio',
          );
        }
      }
      final solicitud = ConductorSolicitudPayloadHelper.normalizarSolicitud(
        raw,
        isDirectOffer: esDirecta,
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

      final esActualizarFase = ConductorOfertaIndriverHelper.esActualizarFase(raw);
      final debeReemplazar =
          ConductorOfertaIndriverHelper.debeReemplazarExistente(raw);

      if (!fromSync &&
          !esActualizarFase &&
          _esRealtimeDuplicado(solicitudId)) {
        AppLogger.d('ℹ️ Realtime duplicado ignorado: $solicitudId');
        return;
      }

      final existente = _solicitudesPorId[solicitudId];

      if (existente != null && debeReemplazar) {
        final fusionada = _fusionarSolicitud(existente, solicitud);
        _solicitudesPorId[solicitudId] = fusionada;
        _aplicarActualizacionFaseBroadcast(solicitudId, fusionada);
        _programarEnriquecimientoDireccion(solicitudId);
        if (!fromSync && _isOnline) {
          _programarSyncSolicitudesTrasEvento();
        }
        if (!_isDisposed) notifyListeners();
        return;
      }

      if (existente != null &&
          !fromSync &&
          !debeReemplazar &&
          ConductorOfertaIndriverHelper.esBroadcastRebote(raw)) {
        AppLogger.d('ℹ️ Broadcast duplicado ignorado: $solicitudId');
        return;
      }

      final esNueva = existente == null;
      if (esNueva) {
        AppLogger.d('📩 Nueva solicitud: $solicitudId');
        if (!AppLifecycleHelper.isInForeground()) {
          unawaited(_actualizarBurbujaSegundoPlano());
        }
      }
      final overlayEstabaOculto =
          !esNueva && _overlayOcultoPorTtl.contains(solicitudId);
      final pasoALlegandoPublico =
          ConductorOfertaIndriverHelper.pasoDeExclusivaAPublicoEnLlegando(
        existente,
        solicitud,
      );
      var pasoAEspera = ConductorOfertaIndriverHelper.pasoDeLlegandoAEspera(
        existente,
        solicitud,
      );
      if (pasoAEspera &&
          ConductorOfertaIndriverHelper.esBroadcastRebote(solicitud)) {
        pasoAEspera = false;
      }
      if (pasoALlegandoPublico &&
          _ofertaExclusiva?.solicitudId == solicitudId) {
        _limpiarOfertaExclusivaLocal(cerrarPantalla: true);
      }
      if (pasoALlegandoPublico || pasoAEspera) {
        _programarSyncSolicitudesTrasEvento();
      }
      final reboteRealtimeALlegando = overlayEstabaOculto &&
          !fromSync &&
          !esActualizarFase &&
          !ConductorOfertaIndriverHelper.esBroadcastRebote(solicitud);
      final altaEnLlegando =
          esNueva || reboteRealtimeALlegando || pasoALlegandoPublico;

      _solicitudesPorId[solicitudId] = _fusionarSolicitud(existente, solicitud);
      ConductorSolicitudPayloadHelper.anclarExpiracionCola(
        _solicitudesPorId[solicitudId]!,
        anterior: existente,
      );
      if (ConductorSolicitudPayloadHelper.tieneExpiracionColaActiva(
        _solicitudesPorId[solicitudId]!,
      )) {
        _iniciarTickerExpiracionUI();
      }

      final solicitudMap = _solicitudesPorId[solicitudId]!;

      // Sync: alinear pestañas con el API (`conductor_tab`); no reabrir Llegando por TTL local.
      if (fromSync && !mostrarEnOverlay) {
        if (esNueva) {
          if (ConductorSolicitudPayloadHelper.usaConductorTabApi(solicitudMap)) {
            if (ConductorSolicitudPayloadHelper.esTabLlegando(solicitudMap)) {
              _aplicarOverlayLlegando(
                solicitudId,
                solicitud: solicitudMap,
                esNueva: true,
                forzarBeepLlegando: pasoALlegandoPublico,
              );
              unawaited(
                _enriquecerPoiTrasMostrar(
                  solicitudId,
                  esNueva: true,
                ).catchError((_) {}),
              );
            } else {
              _sincronizarPestanaOverlayDesdeApi(
                solicitudId,
                solicitudMap,
                forzarReanclaje: true,
              );
              unawaited(
                _enriquecerDireccionesSolicitud(solicitudId).catchError((_) {}),
              );
            }
          } else if (ConductorSolicitudPayloadHelper.overlayVigenteEnServidor(
            solicitudMap,
          )) {
            _aplicarOverlayLlegando(
              solicitudId,
              solicitud: solicitudMap,
              esNueva: true,
            );
            unawaited(
              _enriquecerPoiTrasMostrar(
                solicitudId,
                esNueva: true,
              ).catchError((_) {}),
            );
          } else {
            _overlayOcultoPorTtl.add(solicitudId);
            unawaited(
              _enriquecerDireccionesSolicitud(solicitudId).catchError((_) {}),
            );
          }
        } else if (ConductorOfertaIndriverHelper.esBroadcastRebote(solicitudMap) &&
            ConductorSolicitudPayloadHelper.esTabLlegando(solicitudMap)) {
          _aplicarActualizacionFaseBroadcast(solicitudId, solicitudMap);
        } else if (ConductorSolicitudPayloadHelper.esTabLlegando(solicitudMap) &&
            (pasoALlegandoPublico ||
                (_overlayOcultoPorTtl.contains(solicitudId) &&
                    !ConductorOfertaIndriverHelper.esBroadcastRebote(
                      solicitudMap,
                    )))) {
          _aplicarOverlayLlegando(
            solicitudId,
            solicitud: solicitudMap,
            esNueva: false,
            forzarBeepLlegando: true,
          );
        } else {
          _sincronizarPestanaOverlayDesdeApi(
            solicitudId,
            solicitudMap,
            forzarReanclaje: pasoAEspera,
          );
        }
        _programarEnriquecimientoDireccion(solicitudId);
        if (!_isDisposed) notifyListeners();
        return;
      }

      if (ConductorSolicitudPayloadHelper.usaConductorTabApi(solicitudMap)) {
        if (ConductorSolicitudPayloadHelper.esTabLlegando(solicitudMap)) {
          _aplicarOverlayLlegando(
            solicitudId,
            solicitud: solicitudMap,
            esNueva: altaEnLlegando &&
                !_mantenerEnLlegandoTrasExclusiva(solicitudId),
            forzarBeepLlegando:
                pasoALlegandoPublico || reboteRealtimeALlegando,
          );
          if (altaEnLlegando || reboteRealtimeALlegando) {
            unawaited(
              _enriquecerPoiTrasMostrar(
                solicitudId,
                esNueva: true,
              ).catchError((_) {}),
            );
          }
        } else {
          _sincronizarPestanaOverlayDesdeApi(
            solicitudId,
            solicitudMap,
            forzarReanclaje: pasoAEspera || esNueva,
          );
          if (esNueva) {
            unawaited(
              _enriquecerDireccionesSolicitud(solicitudId).catchError((_) {}),
            );
          }
        }
        _programarEnriquecimientoDireccion(solicitudId);
        if (!_isDisposed) notifyListeners();
        return;
      }

      // Realtime / legacy sin `conductor_tab`.
      var enOverlay = mostrarEnOverlay ||
          !fromSync ||
          esNueva ||
          reboteRealtimeALlegando ||
          pasoALlegandoPublico;
      if (enOverlay) {
        if (pasoALlegandoPublico || _mantenerEnLlegandoTrasExclusiva(solicitudId)) {
          ConductorSolicitudPayloadHelper.anclarOverlayExpiraEn(
            _solicitudesPorId[solicitudId]!,
            anterior: existente,
          );
        }
        _aplicarOverlayLlegando(
          solicitudId,
          solicitud: _solicitudesPorId[solicitudId]!,
          esNueva: altaEnLlegando && !_mantenerEnLlegandoTrasExclusiva(solicitudId),
        );
        if (altaEnLlegando) {
          unawaited(
            _enriquecerPoiTrasMostrar(
              solicitudId,
              esNueva: true,
            ).catchError((_) {}),
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

      _programarEnriquecimientoDireccion(solicitudId);
      if (!fromSync && _isOnline) {
        _programarSyncSolicitudesTrasEvento();
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

  /// Evita que un poll/API sin dirección borre `origen_*` ya enriquecidos.
  Map<String, dynamic> _fusionarSolicitud(
    Map<String, dynamic>? anterior,
    Map<String, dynamic> nuevo,
  ) {
    if (anterior == null) return Map<String, dynamic>.from(nuevo);
    final out = Map<String, dynamic>.from(anterior);
    for (final entry in nuevo.entries) {
      final v = entry.value;
      if (v == null) continue;
      if (v is String) {
        final s = v.trim();
        if (s.isEmpty) continue;
        final k = entry.key.toString().toLowerCase();
        if (k.contains('origen') ||
            k.contains('destino') ||
            k == 'origen' ||
            k == 'destino' ||
            k.contains('pickup') ||
            k.contains('address')) {
          if (SolicitudDisplayHelper.isPlaceholderPickup(s)) continue;
        }
      }
      if (v is Map && v.isEmpty) continue;
      if (v is List && v.isEmpty) continue;
      out[entry.key] = v;
    }
    return out;
  }

  void _programarEnriquecimientoDireccion(String solicitudId) {
    final solicitud = _solicitudesPorId[solicitudId];
    if (solicitud == null || _isDisposed) return;
    if (!SolicitudDisplayHelper.necesitaEnriquecimientoGeocode(solicitud)) {
      return;
    }
    unawaited(
      _enriquecerPoiTrasMostrar(
        solicitudId,
        esNueva: false,
      ).catchError((_) {}),
    );
  }

  /// Ancla cuenta regresiva local; no reinicia en cada poll si el API repite el mismo valor.
  void _reanclarCountdownLocal(
    String solicitudId,
    int segundosApi, {
    bool forzar = false,
  }) {
    if (segundosApi <= 0) {
      _expiracionPorSolicitud.remove(solicitudId);
      return;
    }
    final now = DateTime.now();
    final prev = _expiracionPorSolicitud[solicitudId];
    if (!forzar && prev != null && prev.isAfter(now)) {
      final local = prev.difference(now).inSeconds;
      if (segundosApi < local - 2) {
        _expiracionPorSolicitud[solicitudId] =
            now.add(Duration(seconds: segundosApi));
      }
      return;
    }
    _expiracionPorSolicitud[solicitudId] =
        now.add(Duration(seconds: segundosApi));
  }

  int _segundosRestantesDesdeAncla(String solicitudId) {
    final exp = _expiracionPorSolicitud[solicitudId];
    if (exp == null) return -1;
    return exp.difference(DateTime.now()).inSeconds.clamp(0, 86400);
  }

  /// Rebote broadcast: actualiza countdown en la misma tarjeta (sin beep ni tab Espera).
  void _aplicarActualizacionFaseBroadcast(
    String solicitudId,
    Map<String, dynamic> solicitud,
  ) {
    final rebote = ConductorOfertaIndriverHelper.reboteNumero(solicitud);
    AppLogger.d(
      rebote != null && rebote > 1
          ? '🔄 Broadcast rebote $rebote: actualizar fase $solicitudId'
          : '🔄 Broadcast: actualizar fase $solicitudId',
    );
    _overlayOcultoPorTtl.remove(solicitudId);
    _marcarRecibidaPorRealtime(solicitudId);
    final seg = _segundosLlegandoAlMostrar(solicitud, primeraVista: false);
    if (seg > 0) {
      _reanclarCountdownLocal(solicitudId, seg, forzar: true);
      final rest = _segundosRestantesDesdeAncla(solicitudId);
      _configurarTimerExpiracion(
        solicitudId,
        ttlSegundos: rest > 0 ? rest : seg,
      );
      _iniciarTickerExpiracionUI();
    }
    unawaited(_enriquecerDireccionesSolicitud(solicitudId).catchError((_) {}));
  }

  /// Alinea «Llegando» / «En espera» con el API (`conductor_tab` o `overlay_expira_en`).
  void _sincronizarPestanaOverlayDesdeApi(
    String solicitudId,
    Map<String, dynamic> solicitud, {
    bool forzarReanclaje = false,
  }) {
    if (ConductorOfertaIndriverHelper.esBroadcastRebote(solicitud)) {
      _aplicarActualizacionFaseBroadcast(solicitudId, solicitud);
      return;
    }
    if (ConductorSolicitudPayloadHelper.usaConductorTabApi(solicitud)) {
      final tab = ConductorSolicitudPayloadHelper.conductorTab(solicitud)!;
      if (tab == 'llegando') {
        _overlayOcultoPorTtl.remove(solicitudId);
        final seg =
            ConductorSolicitudPayloadHelper.segundosCountdownLlegando(solicitud);
        if (seg > 0) {
          _reanclarCountdownLocal(
            solicitudId,
            seg,
            forzar: forzarReanclaje,
          );
          final rest = _segundosRestantesDesdeAncla(solicitudId);
          _configurarTimerExpiracion(
            solicitudId,
            ttlSegundos: rest > 0 ? rest : seg,
          );
        } else {
          _timersExpiracion[solicitudId]?.cancel();
          _timersExpiracion.remove(solicitudId);
          _expiracionPorSolicitud.remove(solicitudId);
        }
      } else if (_enMinimoLlegandoVisible(solicitudId)) {
        _overlayOcultoPorTtl.remove(solicitudId);
        final rest = _segundosRestantesDesdeAncla(solicitudId);
        if (rest > 0) {
          _configurarTimerExpiracion(
            solicitudId,
            ttlSegundos: rest,
          );
        }
      } else {
        _timersExpiracion[solicitudId]?.cancel();
        _timersExpiracion.remove(solicitudId);
        final seg =
            ConductorSolicitudPayloadHelper.segundosRestantesEspera(solicitud);
        if (seg > 0) {
          _reanclarCountdownLocal(
            solicitudId,
            seg,
            forzar: forzarReanclaje,
          );
        } else {
          _expiracionPorSolicitud.remove(solicitudId);
        }
        _overlayOcultoPorTtl.add(solicitudId);
      }
      _iniciarTickerExpiracionUI();
      return;
    }

    if (_mantenerEnLlegandoTrasExclusiva(solicitudId) &&
        !ConductorSolicitudPayloadHelper.overlayVigenteEnServidor(solicitud)) {
      return;
    }

    if (_beepLlegandoSilenciado(solicitudId) &&
        !ConductorSolicitudPayloadHelper.overlayVigenteEnServidor(solicitud)) {
      return;
    }

    if (ConductorSolicitudPayloadHelper.overlayVigenteEnServidor(solicitud)) {
      final expiraEn =
          ConductorSolicitudPayloadHelper.resolverOverlayExpiraEn(solicitud)!;
      _overlayOcultoPorTtl.remove(solicitudId);
      _expiracionPorSolicitud[solicitudId] = expiraEn;
      final segundos =
          ConductorSolicitudPayloadHelper.segundosRestantesOverlay(solicitud);
      _configurarTimerExpiracion(solicitudId, ttlSegundos: segundos);
      _iniciarTickerExpiracionUI();
    } else {
      _timersExpiracion[solicitudId]?.cancel();
      _timersExpiracion.remove(solicitudId);
      _expiracionPorSolicitud.remove(solicitudId);
      _overlayOcultoPorTtl.add(solicitudId);
    }
  }

  void _aplicarOverlayLlegando(
    String solicitudId, {
    required Map<String, dynamic> solicitud,
    required bool esNueva,
    bool forzarBeepLlegando = false,
  }) {
    if (_esDescartadaPorRadio(solicitudId)) {
      AppLogger.d('ℹ️ Overlay omitido: $solicitudId descartada por radio');
      return;
    }
    if (_requiereFiltroRadio(solicitud) &&
        !ConductorSolicitudPayloadHelper.esOfertaDirecta(solicitud)) {
      final veredicto = _veredictoRadioAsignacion(solicitud);
      if (veredicto == false) {
        AppLogger.d(
          'ℹ️ Overlay omitido: $solicitudId fuera de radio '
          '(${_driverSearchRadiusKm ?? "?"} km)',
        );
        _descartarSolicitudFueraDeRadio(
          solicitud,
          avisarSiEstabaVisible: true,
        );
        return;
      }
      if (veredicto == null) {
        AppLogger.d(
          'ℹ️ Overlay diferido: $solicitudId pendiente validación GPS/coords',
        );
        _overlayOcultoPorTtl.remove(solicitudId);
        if (ConductorSolicitudPayloadHelper.usaConductorTabApi(solicitud)) {
          final seg = _segundosLlegandoAlMostrar(
            solicitud,
            primeraVista: esNueva,
          );
          if (seg > 0) {
            _reanclarCountdownLocal(solicitudId, seg, forzar: esNueva);
            _configurarTimerExpiracion(solicitudId, ttlSegundos: seg);
            _iniciarTickerExpiracionUI();
          }
        }
        unawaited(
          _enriquecerDireccionesSolicitud(solicitudId).then((_) {
            if (_isDisposed) return;
            final enriquecida = _solicitudesPorId[solicitudId];
            if (enriquecida == null) return;
            if (_veredictoRadioAsignacion(enriquecida) == false) return;
            _aplicarOverlayLlegando(
              solicitudId,
              solicitud: enriquecida,
              esNueva: esNueva,
              forzarBeepLlegando: forzarBeepLlegando,
            );
            if (!_isDisposed) notifyListeners();
          }).catchError((_) {}),
        );
        return;
      }
    }
    if (!_solicitudListaParaOverlay(solicitud)) {
      AppLogger.d(
        'ℹ️ Overlay diferido: $solicitudId sin datos de recogida',
      );
      _overlayOcultoPorTtl.add(solicitudId);
      unawaited(
        _enriquecerDireccionesSolicitud(solicitudId).then((_) {
          if (_isDisposed) return;
          final enriquecida = _solicitudesPorId[solicitudId];
          if (enriquecida == null) return;
          if (!_solicitudListaParaOverlay(enriquecida)) {
            if (_requiereFiltroRadio(enriquecida) &&
                !ConductorSolicitudPayloadHelper.esOfertaDirecta(enriquecida) &&
                !_dentroDelRadioAsignacion(enriquecida)) {
              _removerSolicitudDelMapa(solicitudId);
            }
            return;
          }
          if (_veredictoRadioAsignacion(enriquecida) == false) return;
          _aplicarOverlayLlegando(
            solicitudId,
            solicitud: enriquecida,
            esNueva: esNueva,
            forzarBeepLlegando: forzarBeepLlegando,
          );
          if (!_isDisposed) notifyListeners();
        }).catchError((_) {}),
      );
      return;
    }
    final estabaEnEspera = _overlayOcultoPorTtl.contains(solicitudId);
    final yaVisibleEnLlegando = !estabaEnEspera &&
        _expiracionPorSolicitud.containsKey(solicitudId);
    final aunSinSonido =
        !_sonidoEmitidoPorSolicitudId.containsKey(solicitudId);
    final entraEnPestanaLlegando = forzarBeepLlegando ||
        estabaEnEspera ||
        (esNueva && !yaVisibleEnLlegando) ||
        (aunSinSonido &&
            ConductorSolicitudPayloadHelper.esTabLlegando(solicitud));

    _marcarRecibidaPorRealtime(solicitudId);
    _overlayOcultoPorTtl.remove(solicitudId);
    if (esNueva) {
      unawaited(_notificarYEnriquecerSolicitud(solicitudId));
    } else {
      unawaited(_enriquecerDireccionesSolicitud(solicitudId));
    }

    if (entraEnPestanaLlegando &&
        !_esOfertaExclusivaActiva(solicitudId) &&
        !_beepLlegandoSilenciado(solicitudId) &&
        !_esDescartadaPorRadio(solicitudId)) {
      AppLogger.d(
        forzarBeepLlegando
            ? '🔊 Beep: Llegando al cerrar exclusiva (id=$solicitudId)'
            : '🔊 Beep: entra en pestaña Llegando (id=$solicitudId)',
      );
      if (forzarBeepLlegando) {
        IncomingServiceAlertService.permitirNuevoBeepLlegando(solicitudId);
      }
      _dispararSonidoNuevaSolicitud(
        solicitudId,
        solicitud: solicitud,
        beepInmediato: true,
      );
      _marcarBeepLlegandoRecienEmitido(solicitudId);
    }

    final primeraVistaOverlay =
        esNueva || estabaEnEspera || forzarBeepLlegando;

    if (ConductorSolicitudPayloadHelper.usaConductorTabApi(solicitud)) {
      final seg = _segundosLlegandoAlMostrar(
        solicitud,
        primeraVista: primeraVistaOverlay,
      );
      if (primeraVistaOverlay && seg > 0) {
        _marcarMinimoLlegandoVisible(solicitudId, seg);
      }
      _reanclarCountdownLocal(
        solicitudId,
        seg,
        forzar: primeraVistaOverlay || esNueva,
      );
      final rest = _segundosRestantesDesdeAncla(solicitudId);
      if (rest > 0) {
        _configurarTimerExpiracion(
          solicitudId,
          ttlSegundos: rest,
        );
      }
    } else {
      var segundosOverlay =
          ConductorSolicitudPayloadHelper.segundosRestantesOverlay(solicitud);
      if (primeraVistaOverlay) {
        final minimo = _segundosOfertaEmpresa;
        if (minimo > 0 && segundosOverlay < minimo) {
          segundosOverlay = minimo;
          _marcarMinimoLlegandoVisible(solicitudId, minimo);
        }
      }
      final expiraEn =
          ConductorSolicitudPayloadHelper.resolverOverlayExpiraEn(solicitud);
      _expiracionPorSolicitud[solicitudId] = expiraEn ??
          DateTime.now().add(Duration(seconds: segundosOverlay));
      _configurarTimerExpiracion(
        solicitudId,
        ttlSegundos: segundosOverlay,
      );
    }
    _iniciarTickerExpiracionUI();
    _notificarNuevaSolicitudExterna(_solicitudesPorId[solicitudId]!);
    _programarEnriquecimientoDireccion(solicitudId);
  }

  Future<void> _notificarYEnriquecerSolicitud(String solicitudId) async {
    try {
      final solicitud = _solicitudesPorId[solicitudId];
      if (solicitud == null || _isDisposed) return;

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

      await _enriquecerDireccionesSolicitud(solicitudId).timeout(
        const Duration(seconds: 8),
        onTimeout: () {},
      );
      if (!_isDisposed) notifyListeners();
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
    final solicitud = _solicitudesPorId[solicitudId]!;
    if (ConductorOfertaIndriverHelper.esBroadcastRebote(solicitud)) {
      AppLogger.d(
        'ℹ️ TTL local omitido (broadcast; countdown lo maneja el API): $solicitudId',
      );
      return;
    }
    if (_mantenerEnLlegandoTrasExclusiva(solicitudId)) {
      final seg =
          ConductorSolicitudPayloadHelper.segundosRestantesOverlay(
        _solicitudesPorId[solicitudId]!,
      );
      _configurarTimerExpiracion(
        solicitudId,
        ttlSegundos: seg > 0 ? seg : kOportunidadConductorSegundos,
      );
      return;
    }
    AppLogger.d('⏱️ Overlay TTL expirado (sigue en lista API): $solicitudId');
    _sonidoEmitidoPorSolicitudId.remove(solicitudId);
    _overlayOcultoPorTtl.add(solicitudId);
    _expiracionPorSolicitud.remove(solicitudId);
    _timersExpiracion.remove(solicitudId);
    _detenerTickerSiNoHaySolicitudes();
    if (!_isDisposed) notifyListeners();
  }

  /// Corta tono, voz y notificación full-screen de solicitud entrante.
  Future<void> detenerAlertasSolicitudEntrante() async {
    await Future.wait([
      IncomingServiceAlertService.cancel(),
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

      final pos = _currentPosition;

      final response = await _conductorService.aceptarSolicitud(
        servicioId: solicitudId,
        precioOfertado: precio,
        lat: pos?.latitude,
        lng: pos?.longitude,
      );

      if (!ServicioPayloadAdapter.esAceptacionExitosa(response)) {
        throw Exception(
          response['message']?.toString() ??
              'No se pudo confirmar la aceptación del servicio',
        );
      }

      final servicioIdInt =
          int.tryParse(solicitudId) ??
          ServicioPayloadAdapter.servicioIdDesdeAceptacion(response);
      if (servicioIdInt != null) {
        var detalle =
            ServicioPayloadAdapter.unwrapNavegacionPayload(response);
        if (detalle == null &&
            _ofertaExclusiva?.solicitudId == solicitudId) {
          detalle = {
            'servicio': _ofertaExclusiva!.toSolicitudMap(),
          };
        }
        unawaited(
          marcarEnServicio(
            servicioId: servicioIdInt,
            detalleNavegacion: detalle,
          ),
        );
        _enServicio = true;
        _servicioActivoId = servicioIdInt;
        if (detalle != null) {
          _servicioActivoPendienteNavegacion = detalle;
        }
      }

      if (pos != null) {
        unawaited(_sendMapHeartbeat(pos, force: true));
      }

      _removerSolicitudDelMapa(solicitudId);
      _detenerTickerSiNoHaySolicitudes();

      final ofertaEnPantalla =
          _ofertaExclusiva?.solicitudId == solicitudId &&
          ConductorOfertaNavigation.pantallaVisible;
      if (_ofertaExclusiva?.solicitudId == solicitudId && !ofertaEnPantalla) {
        _limpiarOfertaExclusivaLocal(cerrarPantalla: false);
        _limpiarMarcaAceptacionPropia();
      } else if (!ofertaEnPantalla) {
        _limpiarMarcaAceptacionPropia();
      }

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
      _lastAcceptError = _mensajeParaUsuario(
        e,
        'No se pudo aceptar el servicio. Intenta de nuevo.',
      );
      AppLogger.d('❌ Error aceptando solicitud: $_lastAcceptError');
      if (ConductorOfertaIndriverHelper.debeRetirarTrasConflictoAceptacion(
        _lastAcceptError ?? '',
      )) {
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

        // Tras instalar o primer arranque, el GPS en frío tarda; la caché del SO evita pantalla vacía.
        try {
          final last = await Geolocator.getLastKnownPosition();
          if (last != null && !_isDisposed) {
            _currentPosition = last;
            _isLoadingLocation = false;
            _locationMessage = 'Ubicación obtenida';
            notifyListeners();
            _syncGpsConEstadoTurno();
            unawaited(_sendMapHeartbeat(last, force: true));
          }
        } catch (e) {
          AppLogger.d('⚠️ getLastKnownPosition en arranque: $e');
        }
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
      _syncGpsConEstadoTurno();
      await _sendMapHeartbeat(position, force: true);
      await _requestNotificationPermissionAfterLocation();

      AppLogger.d(
        '📍 Ubicación obtenida: ${position.latitude}, ${position.longitude}',
      );
    } catch (e) {
      AppLogger.d('❌ Error obteniendo ubicación: $e');

      if (_isDisposed) return;

      if (_currentPosition != null) {
        _isLoadingLocation = false;
        _locationMessage = 'Ubicación obtenida';
        if (!_isDisposed) notifyListeners();
        return;
      }

      _isLoadingLocation = false;
      _locationMessage = 'Error obteniendo ubicación: ${e.toString()}';
      if (!_isDisposed) notifyListeners();
    }
  }

  bool get _androidUsaTrackingEnViaje =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  bool _debeSeguirGps() =>
      _isOnline &&
      _turnoActivo != null &&
      !_enDescanso &&
      !(_enServicio && _androidUsaTrackingEnViaje);

  Future<bool> _tienePermisoUbicacionActivo() async {
    final permission = await Geolocator.checkPermission();
    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  bool _esErrorPermisoUbicacion(Object error) {
    final msg = error.toString().toLowerCase();
    return msg.contains('denied') ||
        msg.contains('permission') ||
        msg.contains('permiso');
  }

  /// GPS del home solo cuando hay turno y aporta (no duplicar FGS en viaje Android).
  void _syncGpsConEstadoTurno() {
    if (_isDisposed) return;

    if (!_debeSeguirGps()) {
      _detenerSeguimientoUbicacion();
      _detenerPollUbicacionFallback();
      unawaited(_detenerHeartbeatMapaSegundoPlano());
      return;
    }

    unawaited(_iniciarSeguimientoUbicacionConPermisos());
  }

  Future<void> _iniciarSeguimientoUbicacionConPermisos() async {
    if (_locationStreamStartFuture != null) {
      await _locationStreamStartFuture;
      return;
    }

    final future = _doIniciarSeguimientoUbicacionConPermisos();
    _locationStreamStartFuture = future;
    try {
      await future;
    } finally {
      if (identical(_locationStreamStartFuture, future)) {
        _locationStreamStartFuture = null;
      }
    }
  }

  Future<void> _doIniciarSeguimientoUbicacionConPermisos() async {
    if (_isDisposed || !_debeSeguirGps()) return;

    if (!await _tienePermisoUbicacionActivo()) {
      final granted = await _checkAndRequestPermissions();
      if (!granted || _isDisposed || !_debeSeguirGps()) {
        _detenerSeguimientoUbicacion();
        _iniciarPollUbicacionFallback();
        return;
      }
    }

    if (_locationSubscription == null || !_streamGpsActivo) {
      _iniciarSeguimientoUbicacion();
    }
    _detenerPollUbicacionFallback();
  }

  /// Poll de respaldo: solo si el stream GPS no está activo.
  void _iniciarPollUbicacionFallback() {
    if (_isDisposed || !_debeSeguirGps() || _streamGpsActivo) return;
    _detenerPollUbicacionFallback();
    unawaited(_pollUbicacionUnica());
    _locationPollFallbackTimer = Timer.periodic(
      RuntimePerfFlags.mapHeartbeatPollIntervalFallback,
      (_) => unawaited(_pollUbicacionUnica()),
    );
  }

  void _detenerPollUbicacionFallback() {
    _locationPollFallbackTimer?.cancel();
    _locationPollFallbackTimer = null;
  }

  Future<void> _pollUbicacionUnica() async {
    if (_isDisposed || !_debeSeguirGps()) return;
    if (!await _tienePermisoUbicacionActivo()) return;
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
      AppLogger.d(
        '📍 Poll GPS turno: ${position.latitude}, ${position.longitude}',
        tag: 'UbicacionAPI',
      );
      _onPositionUpdate(position);
    } catch (e) {
      AppLogger.d('⚠️ Poll ubicación fallback: $e');
    }
  }

  void _manejarErrorStreamUbicacion(Object error) {
    AppLogger.d('⚠️ Error en stream de ubicación (home): $error');
    _streamGpsActivo = false;
    _detenerSeguimientoUbicacion();
    if (_isDisposed || !_debeSeguirGps()) return;

    if (_esErrorPermisoUbicacion(error)) {
      _locationMessage = 'Permisos de ubicación denegados';
      if (!_isDisposed) notifyListeners();
    }

    _iniciarPollUbicacionFallback();
    unawaited(_iniciarSeguimientoUbicacionConPermisos());
  }

  bool _conductorEnMovimiento(Position position) {
    final speed = position.speed;
    return speed.isFinite && speed >= RuntimePerfFlags.conductorDrivingSpeedMps;
  }

  Duration _mapHeartbeatIntervalPara(Position position) {
    if (_conductorEnMovimiento(position)) {
      return RuntimePerfFlags.mapHeartbeatMinIntervalDriving;
    }
    return RuntimePerfFlags.mapHeartbeatMinInterval;
  }

  LocationSettings _locationStreamSettings() {
    const filter = RuntimePerfFlags.conductorGpsDistanceFilterActive;
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: filter,
      );
    }
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      return AppleSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: filter,
        pauseLocationUpdatesAutomatically: false,
      );
    }
    return LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: filter,
    );
  }

  void _iniciarSeguimientoUbicacion() {
    _detenerSeguimientoUbicacion();

    _locationSubscription = Geolocator.getPositionStream(
      locationSettings: _locationStreamSettings(),
    ).listen(
      _onPositionUpdate,
      onError: _manejarErrorStreamUbicacion,
      onDone: () {
        _streamGpsActivo = false;
        if (!_isDisposed && _debeSeguirGps()) {
          _iniciarPollUbicacionFallback();
        }
      },
    );
    _streamGpsActivo = true;
  }

  void _detenerSeguimientoUbicacion() {
    _locationSubscription?.cancel();
    _locationSubscription = null;
    _streamGpsActivo = false;
  }

  void _onPositionUpdate(Position position) {
    if (_isDisposed) return;
    _currentPosition = position;
    unawaited(_sendMapHeartbeat(position));
    _purgarSolicitudesFueraDeRadio();
    _reintentarOverlaysPendientesRadio();
    _notifyLocationUiIfNeeded(position);
  }

  /// Evita rebuild del home en cada tick GPS; el mapa sigue fluido con intervalo corto.
  void _notifyLocationUiIfNeeded(Position position) {
    final now = DateTime.now();
    final lastAt = _lastLocationUiNotifyAt;
    final lastPos = _lastLocationUiNotifyPosition;

    final enMovimiento = _conductorEnMovimiento(position);
    final minInterval = _enServicio || enMovimiento
        ? RuntimePerfFlags.conductorGpsUiMinIntervalNav
        : RuntimePerfFlags.conductorGpsUiMinIntervalIdle;
    final minMoveMeters = _enServicio || enMovimiento
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

    final rateLimited = ApiRateLimitGuard.instance.isBlocked;

    final now = DateTime.now();
    final lastSentAt = _lastMapHeartbeatAt;
    if (!force && lastSentAt != null) {
      final elapsed = now.difference(lastSentAt);
      final minInterval = _mapHeartbeatIntervalPara(position);
      if (elapsed < minInterval) {
        final lastPos = _lastMapHeartbeatPosition;
        if (lastPos == null) return;
        final moved = Geolocator.distanceBetween(
          lastPos.latitude,
          lastPos.longitude,
          position.latitude,
          position.longitude,
        );
        if (moved < RuntimePerfFlags.mapHeartbeatMinMoveMeters) {
          return;
        }
      }
    }

    _isSendingMapHeartbeat = true;
    try {
      if (rateLimited) {
        await _actualizarZonaActual(position, force: force);
        return;
      }

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
      _lastMapHeartbeatPosition = position;

      if (ubicacion != null && ubicacion.hasZona) {
        _aplicarZonaDesdeServidor(ubicacion.displayZona, position: position);
      } else {
        await _actualizarZonaActual(position, force: force);
      }
      _programarSyncTrasHeartbeatUbicacion();
    } catch (e) {
      ApiRateLimitGuard.instance.recordIfRateLimit(e);
      if (!ApiRateLimitGuard.looksLikeRateLimit(e)) {
        AppLogger.d('⚠️ No se pudo enviar heartbeat de mapa: $e');
      }
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
      _lastVehiculosLoadError = _mensajeParaUsuario(
        e,
        'No pudimos cargar tus vehículos. Revisa tu conexión o intenta más tarde.',
      );
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

  /// Turno abierto en BD con [fechaTurno] distinta a hoy (el API suele filtrar solo hoy).
  bool _turnoEsDeOtroDia(TurnoActivo? turno) {
    if (turno == null) return false;
    final raw = turno.fechaTurno.trim();
    if (raw.isEmpty) return false;
    final parsed = DateTime.tryParse(raw) ??
        DateTime.tryParse('${raw.split(' ').first}T00:00:00');
    if (parsed == null) return false;
    final hoy = DateTime.now();
    return parsed.year != hoy.year ||
        parsed.month != hoy.month ||
        parsed.day != hoy.day;
  }

  /// Carga el turno actual del conductor
  Future<void> cargarTurnoActual({bool restaurarCacheSiFallaRed = true}) async {
    if (ApiRateLimitGuard.instance.isBlocked) {
      AppLogger.d(
        '⏭️ cargarTurnoActual omitido (rate limit ${ApiRateLimitGuard.instance.secondsRemaining}s)',
      );
      if (restaurarCacheSiFallaRed) {
        await _restaurarTurnoTrasFalloDeRed();
      }
      return;
    }
    final token = await AuthService.instance.getToken();
    if (token == null || token.isEmpty) {
      AppLogger.d(
        'ℹ️ cargarTurnoActual: sin access_token en prefs; omitiendo GET turno_actual_conductor',
        tag: 'Turno',
      );
      return;
    }

    final teniaTurnoLocal = _turnoActivo != null;
    try {
      final lookup = await _conductorService.lookupTurnoActivo();
      final turno = lookup.turno;

      AppLogger.d(
        '🔄 cargarTurnoActual: encontrado=${turno?.id ?? 'null'} '
        'sinTurnoServidor=${lookup.servidorConfirmoSinTurno}',
      );
      if (turno != null) {
        await _aplicarTurnoActivoLocal(turno);
        _turnoValidadoConServidorEnSesion = true;
        if (!_isDisposed) notifyListeners();
      } else if (lookup.servidorConfirmoSinTurno) {
        _turnoValidadoConServidorEnSesion = true;
        final prefs = await SharedPreferences.getInstance();
        final cacheId = prefs.getInt('turno_activo_id');
        if (teniaTurnoLocal || _isOnline || (cacheId != null && cacheId > 0)) {
          AppLogger.d(
            'ℹ️ Servidor sin turno activo; limpiando cache local '
            '(memoria=${_turnoActivo?.id}, prefs=$cacheId)',
            tag: 'Turno',
          );
          await _limpiarTurnoActivoLocal(clearSelectedVehicle: false);
        }
      } else if (teniaTurnoLocal || _isOnline) {
        if (_turnoActivo != null &&
            _turnoActivo!.estaActivo &&
            _turnoEsDeOtroDia(_turnoActivo)) {
          AppLogger.w(
            'Turno ACTIVO del ${_turnoActivo!.fechaTurno} no devuelto por API '
            '(turno_actual_conductor filtra solo hoy). Se mantiene en línea.',
            tag: 'Turno',
          );
          _isOnline = true;
          if (!_enDescanso && !_suscritoASocket) {
            unawaited(conectarSocket());
          }
          if (!_isDisposed) notifyListeners();
          return;
        }
        AppLogger.d(
          'ℹ️ Sin turno en servidor; limpiando cache local '
          '(id=${_turnoActivo?.id})',
          tag: 'Turno',
        );
        await _limpiarTurnoActivoLocal(clearSelectedVehicle: false);
      }
    } catch (e) {
      ApiRateLimitGuard.instance.recordIfRateLimit(e);
      if (!ApiRateLimitGuard.looksLikeRateLimit(e)) {
        AppLogger.d(
          '⚠️ cargarTurnoActual falló (red/servidor)'
          '${restaurarCacheSiFallaRed ? ', se conserva turno local' : ''}: '
          '${_mensajeParaUsuario(e, 'Error al consultar turno en el servidor')}',
        );
      }
      if (restaurarCacheSiFallaRed) {
        await _restaurarTurnoTrasFalloDeRed();
      }
    }
  }

  Future<void> _restaurarTurnoTrasFalloDeRed() async {
    if (!_turnoValidadoConServidorEnSesion) {
      AppLogger.d(
        'ℹ️ Turno no validado con servidor en esta sesión; '
        'no se restaura caché tras fallo de red',
        tag: 'Turno',
      );
      return;
    }
    if (_turnoActivo != null) {
      _isOnline = true;
      if (!_enDescanso && !_suscritoASocket) {
        unawaited(conectarSocket());
      }
      _syncGpsConEstadoTurno();
      if (!_isDisposed) notifyListeners();
      return;
    }
    final ok = await restaurarTurnoDesdeCache();
    if (ok && !_enDescanso) {
      unawaited(conectarSocket());
      _syncGpsConEstadoTurno();
    }
  }

  /// Al volver a la app: restaura GPS con última posición conocida para no vaciar el mapa.
  Future<void> refrescarUbicacionEnResume({bool soloGps = false}) async {
    if (_isDisposed) return;
    try {
      final last = await Geolocator.getLastKnownPosition();
      if (last != null) {
        _currentPosition = last;
        _isLoadingLocation = false;
        _locationMessage = 'Ubicación obtenida';
        _syncGpsConEstadoTurno();
        if (!_isDisposed) notifyListeners();
        if (!soloGps && _isOnline && _turnoActivo != null) {
          unawaited(_sendMapHeartbeat(last, force: false));
        }
        return;
      }
    } catch (e) {
      AppLogger.d('⚠️ getLastKnownPosition en resume: $e');
    }

    if (_currentPosition == null) {
      await initializeLocation();
    }
  }

  Future<void> _detenerHeartbeatMapaSegundoPlano() async {
    await BackgroundLocationService.stopMapHeartbeat();
  }

  Future<void> _iniciarHeartbeatMapaSegundoPlano() async {
    if (_isDisposed || !_debeSeguirGps()) return;
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;

    final ids = await ConductorSessionHelper.obtenerIdsConductorSesion();
    final conductorId = ids.isEmpty ? null : ids.first;
    await BackgroundLocationService.startMapHeartbeat(conductorId: conductorId);
    AppLogger.d('📍 [BG] Heartbeat mapa en segundo plano activo');
  }

  /// Al pausar la app: mantener visible al conductor en `conductores-disponibles`.
  Future<void> onAppLifecyclePaused() async {
    if (_isDisposed || !_debeSeguirGps()) return;
    await _iniciarHeartbeatMapaSegundoPlano();
  }

  /// Una sola ráfaga al volver al foreground (evita 429 por llamadas duplicadas).
  Future<void> refrescarEnResume() async {
    if (_isDisposed) return;
    await _detenerHeartbeatMapaSegundoPlano();
    final now = DateTime.now();
    if (_lastResumeRefreshAt != null &&
        now.difference(_lastResumeRefreshAt!) < const Duration(seconds: 5)) {
      AppLogger.d('⏭️ [Resume] refresco omitido (debounce 5s)');
      return;
    }
    if (_resumeRefreshInFlight) return;
    _resumeRefreshInFlight = true;
    _lastResumeRefreshAt = now;
    try {
      if (ApiRateLimitGuard.instance.isBlocked) {
        AppLogger.d(
          '⏭️ [Resume] API en cooldown '
          '(${ApiRateLimitGuard.instance.secondsRemaining}s)',
        );
        return;
      }

      AppLogger.d(
        '🔄 [Resume] isOnline=$_isOnline turno=${_turnoActivo?.id} enServicio=$_enServicio',
      );

      await refrescarUbicacionEnResume(soloGps: _enServicio);

      if (_enServicio) return;

      await cargarTurnoActual(
        restaurarCacheSiFallaRed: _turnoValidadoConServidorEnSesion,
      );

      if (_turnoActivo == null || !_isOnline) return;

      _syncGpsConEstadoTurno();

      await sincronizarSolicitudesPublicadasConductor(forzar: true);
      await sincronizarOfertaActiva();

      final position = _currentPosition;
      if (position != null) {
        await _sendMapHeartbeat(position, force: false);
      }

      if (!_isDisposed) notifyListeners();
    } catch (e) {
      ApiRateLimitGuard.instance.recordIfRateLimit(e);
      if (!ApiRateLimitGuard.looksLikeRateLimit(e)) {
        AppLogger.d('⚠️ [Resume] Error refrescando: $e');
      }
      await _restaurarTurnoTrasFalloDeRed();
    } finally {
      _resumeRefreshInFlight = false;
    }
  }

  /// Re-sincroniza turno y heartbeat al volver al foreground (sin borrar turno si falla la red).
  Future<void> refrescarTurnoYHeartbeatEnResume() async {
    await refrescarEnResume();
  }

  /// Inicia un turno con el vehículo seleccionado
  Future<bool> iniciarTurno(int idVehiculo) async {
    if (_procesandoTurno) return false;
    _procesandoTurno = true;
    if (!_isDisposed) notifyListeners();
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
      _lastTurnoError = _mensajeParaUsuario(
        e,
        'No se pudo iniciar el turno. Intenta de nuevo.',
      );
      AppLogger.d('❌ Error iniciando turno: $e');
      if (!_isDisposed) notifyListeners();
      return false;
    } finally {
      _procesandoTurno = false;
      if (!_isDisposed) notifyListeners();
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
    _turnoValidadoConServidorEnSesion = true;
    _enDescanso = false;
    _recibeServicios = true;
    _visibleEnMapa = true;
    _sincronizarVehiculoSeleccionadoConTurno();
    await conectarSocket();
    _syncGpsConEstadoTurno();
    final pos = _currentPosition;
    if (pos != null) {
      unawaited(_sendMapHeartbeat(pos, force: true));
      unawaited(_actualizarZonaActual(pos, force: true));
    }
    if (!_isDisposed) notifyListeners();
  }

  /// Finaliza el turno actual (`POST /turnos/finalizar-activo`; fallback por id).
  Future<bool> finalizarTurno() async {
    if (_turnoActivo == null) return false;
    if (_procesandoTurno) return false;

    _procesandoTurno = true;
    _lastTurnoError = null;
    if (!_isDisposed) notifyListeners();
    final idTurno = _turnoActivo!.id;

    try {
      await _conductorService.finalizarTurnoActivo();
      await _limpiarTurnoActivoLocal();
      return true;
    } catch (e) {
      AppLogger.d('❌ Error finalizando turno (finalizar-activo): $e');

      try {
        await _conductorService.finalizarTurno(idTurno);
        await _limpiarTurnoActivoLocal();
        AppLogger.d('✅ Turno cerrado vía POST /turnos/$idTurno/finalizar');
        return true;
      } catch (e2) {
        AppLogger.d('❌ Error finalizando turno $idTurno: $e2');

        final activo = await _conductorService.getTurnoActivo();
        if (activo == null) {
          AppLogger.d(
            'ℹ️ Backend sin turno abierto; limpiando estado local obsoleto',
          );
          await _limpiarTurnoActivoLocal();
          return true;
        }
      }

      _lastTurnoError = _mensajeParaUsuario(
        e,
        'No se pudo finalizar el turno. Intenta de nuevo.',
      );
      if (!_isDisposed) notifyListeners();
      return false;
    } finally {
      _procesandoTurno = false;
      if (!_isDisposed) notifyListeners();
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

  /// Rechaza el viaje asignado: libera al conductor; el servicio sigue para otros.
  Future<bool> rechazarServicioActivo({required int servicioId}) async {
    try {
      AppLogger.d('↩️ Rechazo conductor en viaje activo: $servicioId');
      final ok =
          await rechazarSolicitudParaConductor(servicioId.toString());
      if (!ok) return false;
      await marcarDisponible();
      return true;
    } catch (e) {
      AppLogger.d('❌ Error rechazando servicio activo: $e');
      return false;
    }
  }

  /// Cancelar servicio activo (motivo opcional).
  /// Solo debe usarse si el backend exige cancelación total; en viaje activo del
  /// conductor preferir [rechazarServicioActivo].
  Future<bool> cancelarServicio({
    required int servicioId,
    String? motivoCodigo,
    String? motivo,
  }) async {
    try {
      AppLogger.d('🚫 Cancelando servicio: $servicioId');

      await _conductorService.cancelarServicio(
        servicioId: servicioId,
        motivoCodigo: motivoCodigo,
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
    if (_expiracionPorSolicitud.containsKey(solicitudId)) {
      return _segundosRestantesDesdeAncla(solicitudId);
    }

    final solicitud = _solicitudesPorId[solicitudId];
    if (solicitud == null) return 0;

    if (ConductorSolicitudPayloadHelper.usaConductorTabApi(solicitud)) {
      if (ConductorSolicitudPayloadHelper.esTabLlegando(solicitud)) {
        return ConductorSolicitudPayloadHelper.segundosCountdownLlegando(
          solicitud,
        );
      }
      return ConductorSolicitudPayloadHelper.segundosRestantesEspera(solicitud);
    }

    if (!_overlayOcultoPorTtl.contains(solicitudId)) {
      return ConductorSolicitudPayloadHelper.segundosCountdownLlegando(solicitud);
    }
    return ConductorSolicitudPayloadHelper.segundosRestantesEspera(solicitud);
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
    if (_expiracionPorSolicitud.isNotEmpty) {
      final now = DateTime.now();
      final expiradas = _expiracionPorSolicitud.entries
          .where((entry) => !entry.value.isAfter(now))
          .map((entry) => entry.key)
          .toList();

      for (final solicitudId in expiradas) {
        final solicitud = _solicitudesPorId[solicitudId];
        if (solicitud != null &&
            ConductorSolicitudPayloadHelper.usaConductorTabApi(solicitud)) {
          if (obtenerSegundosRestantes(solicitudId) <= 0) {
            if (ConductorSolicitudPayloadHelper.esTabEspera(solicitud)) {
              _sincronizarPestanaOverlayDesdeApi(
                solicitudId,
                solicitud,
                forzarReanclaje: true,
              );
            } else {
              _expirarSolicitud(solicitudId);
            }
          }
          continue;
        }
        _expirarSolicitud(solicitudId);
      }
    }

    final colaExpiradas = <String>[];
    for (final solicitud in _solicitudesPorId.values) {
      final id = ConductorSolicitudPayloadHelper.obtenerSolicitudId(solicitud);
      if (id == null) continue;

      if (ConductorSolicitudPayloadHelper.usaConductorTabApi(solicitud)) {
        if (obtenerSegundosRestantes(id) <= 0) {
          colaExpiradas.add(id);
        }
        continue;
      }

      if (!ServicioEsperaTimer.tieneDatosCola(solicitud)) continue;
      if (!ServicioEsperaTimer.colaExpirada(solicitud)) continue;
      colaExpiradas.add(id);
    }
    for (final solicitudId in colaExpiradas) {
      AppLogger.d('⏱️ Cola expirada (countdown API): $solicitudId');
      _removerSolicitudDelMapa(solicitudId);
    }
  }

  Future<bool> finalizarTurnoActivoAnterior() async {
    try {
      await _conductorService.finalizarTurnoActivo();
      await _limpiarTurnoActivoLocal(clearSelectedVehicle: false);
      return true;
    } catch (e) {
      AppLogger.d('❌ Error finalizando turno anterior: $e');
      final activo = await _conductorService.getTurnoActivo();
      if (activo == null) {
        await _limpiarTurnoActivoLocal(clearSelectedVehicle: false);
        return true;
      }
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

    await desconectarSocket();
    _detenerSeguimientoUbicacion();
    unawaited(_detenerHeartbeatMapaSegundoPlano());
    _limpiarColaSolicitudesLocal();

    _turnoActivo = null;
    _isOnline = false;
    _turnoValidadoConServidorEnSesion = true;
    _enDescanso = false;
    _recibeServicios = true;
    _visibleEnMapa = true;
    if (clearSelectedVehicle) {
      _vehiculoSeleccionado = null;
    }

    unawaited(_actualizarBurbujaSegundoPlano());

    if (!_isDisposed) notifyListeners();
  }

  static String _mensajeParaUsuario(Object error, String fallback) {
    return DioErrorMessage.from(error, fallback: fallback);
  }

  Future<void> _actualizarBurbujaSegundoPlano() async {
    await ConductorOverlayBadgeStore.write(
      llegando: solicitudesOrdenadas.length,
      enEspera: totalSolicitudesEnEspera,
    );
    await DriverOverlayService.instance.showFromBadgeStore(enLinea: _isOnline);
  }
}
