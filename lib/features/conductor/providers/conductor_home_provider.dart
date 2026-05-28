import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intellitaxi/features/conductor/services/turno_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:intellitaxi/core/services/app_logger.dart';
import 'package:intellitaxi/core/services/fleet_emergency_alert_service.dart';
import 'package:intellitaxi/core/services/incoming_service_notification_service.dart';
import 'package:intellitaxi/core/services/reverse_geocoding_service.dart';
import 'package:intellitaxi/core/services/voice_alert_service.dart';
import 'package:intellitaxi/features/conductor/utils/solicitud_display_helper.dart';
import 'package:intellitaxi/features/conductor/services/conductor_service.dart';
import 'package:intellitaxi/features/conductor/data/documento_vehiculo_model.dart';
import 'package:intellitaxi/features/conductor/data/vehiculo_conductor_model.dart';
import 'package:intellitaxi/features/conductor/data/turno_model.dart';
import 'package:intellitaxi/features/taxi/data/taxi_radio_accion.dart';
import 'package:intellitaxi/features/taxi/data/taxi_servicio_estado.dart';
import 'package:intellitaxi/features/taxi/exceptions/taxi_en_servicio_exception.dart';
import 'package:intellitaxi/features/taxi/utils/taxi_pusher_channels.dart';
import 'package:intellitaxi/features/taxi/utils/taxi_radio_accion_filter.dart';
import 'package:intellitaxi/config/pusher_config.dart';
import 'package:intellitaxi/core/geo/popayan_urban_area.dart';

import 'package:intellitaxi/features/conductor/conductor_constants.dart';
import 'package:intellitaxi/features/conductor/services/conductor_solicitud_enrichment_service.dart';
import 'package:intellitaxi/features/conductor/utils/conductor_session_helper.dart';
import 'package:intellitaxi/features/conductor/utils/conductor_solicitud_payload_helper.dart';
import 'package:intellitaxi/features/conductor/utils/conductor_solicitud_ranking_helper.dart';
import 'package:intellitaxi/core/utils/app_lifecycle_helper.dart';
import 'package:intellitaxi/core/utils/json_payload_helper.dart';

export 'package:intellitaxi/features/conductor/conductor_constants.dart';

/// Provider para gestionar toda la lógica de la pantalla home del conductor
/// Incluye: ubicación, turnos, vehículos, solicitudes de servicio y conexión a Pusher.

class ConductorHomeProvider extends ChangeNotifier {
  // Servicios
  final ConductorService _conductorService = ConductorService();
  final TurnoService _turnoService = TurnoService();
  final AudioPlayer _audioPlayer = AudioPlayer();

  // Estado de ubicación
  Position? _currentPosition;
  bool _isLoadingLocation = true;
  String _locationMessage =
      'Estableciendo conexión satelital para rastreo en tiempo real...';
  String? _zonaActual;
  StreamSubscription<Position>? _locationSubscription;
  Position? _lastAreaResolvedPosition;
  DateTime? _lastAreaResolvedAt;
  DateTime? _lastMapHeartbeatAt;
  bool _isSendingMapHeartbeat = false;
  final ReverseGeocodingService _reverseGeocodingService =
      ReverseGeocodingService();
  final ConductorSolicitudEnrichmentService _solicitudEnrichment =
      ConductorSolicitudEnrichmentService();

  // Estado online/offline
  bool _isOnline = false;
  bool _notificationPermissionRequestedInSession = false;

  // Vehículos y turnos
  VehiculoConductor? _vehiculoSeleccionado;
  List<VehiculoConductor> _vehiculosDisponibles = [];
  String? _lastVehiculosLoadError;
  TurnoActivo? _turnoActivo;

  // Solicitudes de servicio
  final List<Map<String, dynamic>> _solicitudesActivas = [];
  final Map<String, Timer> _timersExpiracion = {};
  final Map<String, DateTime> _expiracionPorSolicitud = {};
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
  TaxiRadioAccion _radioAccion = TaxiRadioAccion.sinLimitePorDefecto;
  bool _guardandoRadioAccion = false;
  String? _lastRadioAccionError;
  final List<void Function(String servicioId)> _solicitudTomadaListeners = [];
  final List<void Function(Map<String, dynamic> solicitud)>
      _nuevaSolicitudListeners = [];
  final Set<int> _serviciosRechazados = {};

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

  /// Datos listos para navegar a pantalla de viaje tras bootstrap/aceptar.
  void clearServicioActivoPendienteNavegacion() {
    _servicioActivoPendienteNavegacion = null;
  }

  List<Map<String, dynamic>> get solicitudesActivas =>
      (_enServicio || _enDescanso) ? const [] : _solicitudesActivas;
  String? get lastAcceptError => _lastAcceptError;
  String? get lastTurnoError => _lastTurnoError;
  bool get enDescanso => _enDescanso;
  bool get visibleEnMapa => _visibleEnMapa;
  bool get recibeServicios => _recibeServicios && !_enDescanso;
  bool get cambiandoDescanso => _cambiandoDescanso;
  String? get lastDescansoError => _lastDescansoError;
  TaxiRadioAccion get radioAccion => _radioAccion;
  bool get guardandoRadioAccion => _guardandoRadioAccion;
  String? get lastRadioAccionError => _lastRadioAccionError;
  bool get puedeUsarModoDescanso =>
      _isOnline && !_enServicio && _turnoActivo != null;
  List<Map<String, dynamic>> get solicitudesOrdenadas {
    final solicitudes = List<Map<String, dynamic>>.from(_solicitudesActivas);
    solicitudes.sort(
      (a, b) => ConductorSolicitudRankingHelper.calcularScore(b)
          .compareTo(ConductorSolicitudRankingHelper.calcularScore(a)),
    );
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
    final candidatas = solicitudesOrdenadas.where((s) {
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
    unawaited(cargarRadioAccion());
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

    // Quitar de cola local cualquier id ya rechazado.
    _solicitudesActivas.removeWhere((s) {
      final id = ConductorSolicitudPayloadHelper.obtenerSolicitudId(s);
      return id != null && esServicioRechazado(id);
    });

    if (!_isDisposed) notifyListeners();
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
    _solicitudesActivas.clear();
    _detenerTickerSiNoHaySolicitudes();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _audioPlayer.dispose();
    // Cancelar todos los timers
    for (var timer in _timersExpiracion.values) {
      timer.cancel();
    }
    _timersExpiracion.clear();
    _tickerExpiracionUI?.cancel();
    _tickerExpiracionUI = null;
    _detenerSincronizacionSolicitudes();
    _detenerSeguimientoUbicacion();
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

      final ids = await ConductorSessionHelper.obtenerIdsConductorSesion();
      final candidateChannels = ConductorSessionHelper.canalesOfertaDirecta(ids);
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

      unawaited(cargarRadioAccion());

      _suscritoAPusher = true;
      _iniciarSincronizacionSolicitudes();
      unawaited(sincronizarSolicitudesPublicadasConductor());
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
      final serverIds = <String>{};
      for (final m in list) {
        final sid = m['servicio_id'] ?? m['solicitud_id'] ?? m['id'];
        if (sid != null) serverIds.add(sid.toString());
      }

      for (final s in List<Map<String, dynamic>>.from(_solicitudesActivas)) {
        final id = ConductorSolicitudPayloadHelper.obtenerSolicitudId(s);
        if (id == null || id.isEmpty || id.startsWith('temp_')) continue;
        if (int.tryParse(id) == null) continue;
        if (!serverIds.contains(id)) {
          rechazarSolicitud(id);
        }
      }

      // Fallback: si se perdió realtime pero el backend aún reporta pendientes,
      // sembramos la cola "llegando" desde sync (sin sonido ni heads-up).
      for (final m in list) {
        _procesarNuevaSolicitud(m, fromSync: true);
      }

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

  void _procesarSolicitudTomada(dynamic data) {
    try {
      final raw = ConductorSolicitudPayloadHelper.parsePayload(data);
      final servicioId =
          ConductorSolicitudPayloadHelper.servicioIdFromTomadaPayload(raw);
      if (servicioId == null) return;
      rechazarSolicitud(servicioId);
      for (final listener in List.of(_solicitudTomadaListeners)) {
        listener(servicioId);
      }
    } catch (e) {
      AppLogger.d('⚠️ Error procesando solicitud.tomada: $e');
    }
  }

  static double get _radioAccionMaxUrbanoKm => PopayanUrbanArea.maxRadiusKm;

  TaxiRadioAccion _aplicarLimiteUrbanoPopayan(TaxiRadioAccion config) {
    final maxUrbano = _radioAccionMaxUrbanoKm;
    final maxKm = config.maxKm > maxUrbano ? maxUrbano : config.maxKm;
    final radioKm = config.radioKm;
    final efectivo = config.radioEfectivoKm > maxUrbano
        ? maxUrbano
        : config.radioEfectivoKm;
    return TaxiRadioAccion(
      activo: config.activo,
      radioKm: radioKm != null && radioKm > maxUrbano ? maxUrbano : radioKm,
      radioEfectivoKm: efectivo,
      sinLimite: config.sinLimite,
      minKm: config.minKm,
      maxKm: maxKm,
      defaultKm: config.defaultKm > maxUrbano ? maxUrbano : config.defaultKm,
    );
  }

  Future<void> cargarRadioAccion() async {
    try {
      _radioAccion = _aplicarLimiteUrbanoPopayan(
        await _conductorService.getRadioAccion(),
      );
      _lastRadioAccionError = null;
    } catch (e) {
      _lastRadioAccionError = e.toString().replaceAll('Exception: ', '');
      AppLogger.d('⚠️ Error cargando radio-accion: $e');
    }
    if (!_isDisposed) notifyListeners();
  }

  void aplicarRadioAccion(TaxiRadioAccion config) {
    _radioAccion = _aplicarLimiteUrbanoPopayan(config);
    if (!_isDisposed) notifyListeners();
  }

  Future<String?> guardarRadioAccion({
    required bool activo,
    double? radioKm,
  }) async {
    _guardandoRadioAccion = true;
    _lastRadioAccionError = null;
    if (!_isDisposed) notifyListeners();

    try {
      double? kmGuardar = radioKm;
      if (activo && kmGuardar != null) {
        kmGuardar = kmGuardar.clamp(
          _radioAccion.minKm,
          _radioAccionMaxUrbanoKm,
        );
      }
      _radioAccion = await _conductorService.setRadioAccion(
        activo: activo,
        radioKm: kmGuardar,
      );
      _radioAccion = _aplicarLimiteUrbanoPopayan(_radioAccion);
      return null;
    } catch (e) {
      _lastRadioAccionError = e.toString().replaceAll('Exception: ', '');
      return _lastRadioAccionError;
    } finally {
      _guardandoRadioAccion = false;
      if (!_isDisposed) notifyListeners();
    }
  }

  bool _pasaFiltroRadioAccion(Map<String, dynamic> raw) {
    return TaxiRadioAccionFilter.matches(
      raw,
      _currentPosition?.latitude,
      _currentPosition?.longitude,
      _radioAccion,
      limitarAUrbanoPopayan: true,
    );
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

  /// Procesa una nueva solicitud recibida de Pusher
  void _procesarNuevaSolicitud(
    dynamic data, {
    bool isDirectOffer = false,
    bool fromSync = false,
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
      if (_esServicioRechazadoEnPayload(raw)) {
        AppLogger.d('ℹ️ Ignorando solicitud: rechazada por este conductor');
        return;
      }
      if (!fromSync && !_pasaFiltroRadioAccion(raw)) {
        AppLogger.d('ℹ️ Solicitud fuera del radio de acción');
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
      AppLogger.d('📩 Solicitud decodificada: $solicitudId');

      if (esServicioRechazado(solicitudId)) {
        AppLogger.d('ℹ️ Ignorando solicitud rechazada: $solicitudId');
        return;
      }

      // Verificar si ya existe la solicitud
      final yaExiste = _solicitudesActivas.any(
        (s) => ConductorSolicitudPayloadHelper.obtenerSolicitudId(s) == solicitudId,
      );
      if (yaExiste) {
        AppLogger.d('⚠️ Solicitud ya existe: $solicitudId');
        return;
      }

      // Agregar solicitud a la lista
      _solicitudesActivas.add(solicitud);

      if (!fromSync) {
        unawaited(_reproducirSonidoNotificacion());
        unawaited(VoiceAlertService.announceNewService());
        unawaited(_notificarYEnriquecerSolicitud(solicitudId));
      } else {
        unawaited(_enriquecerDireccionesSolicitud(solicitudId));
      }

      final ttlSegundos =
          ConductorSolicitudPayloadHelper.resolverTtlSegundos(solicitud);
      _expiracionPorSolicitud[solicitudId] = DateTime.now().add(
        Duration(seconds: ttlSegundos),
      );

      // Configurar timer de expiración
      _configurarTimerExpiracion(solicitudId, ttlSegundos: ttlSegundos);
      _iniciarTickerExpiracionUI();

      if (!fromSync) {
        _notificarNuevaSolicitudExterna(solicitud);
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

  Future<void> _notificarYEnriquecerSolicitud(String solicitudId) async {
    try {
      await _enriquecerDireccionesSolicitud(solicitudId);
      if (_isDisposed) return;
      final index = _solicitudesActivas.indexWhere(
        (s) =>
            ConductorSolicitudPayloadHelper.obtenerSolicitudId(s) == solicitudId,
      );
      if (index < 0) return;

      // Full-screen / heads-up solo si la app no está visible (otra app encima).
      if (!_isAppInForeground()) {
        await IncomingServiceNotificationService.instance.showIncomingService(
          _solicitudesActivas[index],
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

  bool _isAppInForeground() => AppLifecycleHelper.isInForeground();

  Future<void> _enriquecerDireccionesSolicitud(String solicitudId) async {
    final index = _solicitudesActivas.indexWhere(
      (s) => ConductorSolicitudPayloadHelper.obtenerSolicitudId(s) == solicitudId,
    );
    if (index < 0 || _isDisposed) return;

    final changed = await _solicitudEnrichment.enrich(_solicitudesActivas[index]);
    if (changed && !_isDisposed) notifyListeners();
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

  /// Expira una solicitud después del tiempo límite
  void _expirarSolicitud(String solicitudId) {
    AppLogger.d('⏱️ Solicitud expirada: $solicitudId');
    final index = _solicitudesActivas.indexWhere(
      (s) =>
          (s['_local_id']?.toString() == solicitudId) ||
          (ConductorSolicitudPayloadHelper.obtenerSolicitudId(s) == solicitudId),
    );
    if (index != -1) {
      _solicitudesActivas.removeAt(index);
    } else {
      _solicitudesActivas.removeWhere(
        (s) => ConductorSolicitudPayloadHelper.obtenerSolicitudId(s) == solicitudId,
      );
    }
    _expiracionPorSolicitud.remove(solicitudId);
    _timersExpiracion.remove(solicitudId);
    _detenerTickerSiNoHaySolicitudes();
    if (!_isDisposed) notifyListeners();
  }

  /// Reproduce el sonido de notificación
  Future<void> _reproducirSonidoNotificacion() async {
    try {
      await _audioPlayer.play(AssetSource('sound/nuevaoferta.mp3'));
    } catch (e) {
      AppLogger.d('❌ Error reproduciendo sonido: $e');
    }
  }

  // ==================== MANEJO DE SOLICITUDES ====================

  /// Rechaza una solicitud
  void rechazarSolicitud(String solicitudId) {
    AppLogger.d('❌ Rechazando solicitud: $solicitudId');

    bool coincideId(Map<String, dynamic> s, String id) {
      final obtenido = ConductorSolicitudPayloadHelper.obtenerSolicitudId(s);
      if (obtenido != null && obtenido == id) return true;

      // Algunas respuestas (GET vs Pusher) pueden traer IDs en campos distintos.
      final candidatos = <String>{
        s['_local_id']?.toString() ?? '',
        s['solicitud_id']?.toString() ?? '',
        s['solicitudId']?.toString() ?? '',
        s['servicio_id']?.toString() ?? '',
        s['servicioId']?.toString() ?? '',
        s['id']?.toString() ?? '',
        s['ride_id']?.toString() ?? '',
        s['request_id']?.toString() ?? '',
        s['temp_id']?.toString() ?? '',
      };
      candidatos.removeWhere((v) => v.isEmpty);
      return candidatos.contains(id);
    }

    // Recolectamos IDs para poder cancelar timers por cualquiera de las claves.
    final idsAEliminar = <String>{};
    _solicitudesActivas.removeWhere((s) {
      final match = coincideId(s, solicitudId);
      if (match) {
        final obtenido = ConductorSolicitudPayloadHelper.obtenerSolicitudId(s);
        if (obtenido != null && obtenido.isNotEmpty) idsAEliminar.add(obtenido);
        for (final k in const [
          '_local_id',
          'solicitud_id',
          'solicitudId',
          'servicio_id',
          'servicioId',
          'id',
          'ride_id',
          'request_id',
          'temp_id',
        ]) {
          final v = s[k]?.toString();
          if (v != null && v.isNotEmpty) idsAEliminar.add(v);
        }
      }
      return match;
    });

    for (final id in idsAEliminar) {
      _expiracionPorSolicitud.remove(id);
      _timersExpiracion[id]?.cancel();
      _timersExpiracion.remove(id);
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
        for (final s in _solicitudesActivas) {
          if (ConductorSolicitudPayloadHelper.obtenerSolicitudId(s) ==
              solicitudId) {
            precio = JsonPayloadHelper.parseDouble(
              s['precio_ofertado'],
              fallback: 0,
            );
            break;
          }
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

      // Remover de la lista de solicitudes activas
      _solicitudesActivas.removeWhere(
        (s) => ConductorSolicitudPayloadHelper.obtenerSolicitudId(s) == solicitudId,
      );
      _expiracionPorSolicitud.remove(solicitudId);
      _detenerTickerSiNoHaySolicitudes();

      if (!_isDisposed) notifyListeners();
      return response;
    } on TaxiEnServicioException catch (e) {
      _lastAcceptError = e.message;
      if (e.servicioActivoId != null) {
        await marcarEnServicio(servicioId: e.servicioActivoId!);
      }
      return null;
    } catch (e) {
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
      _locationMessage = 'Obteniendo ubicación GPS...';
      if (!_isDisposed) notifyListeners();

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
      _actualizarZonaActual(position, force: true);
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

  void _iniciarSeguimientoUbicacion() {
    _detenerSeguimientoUbicacion();

    _locationSubscription =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.bestForNavigation,
            distanceFilter: 3,
          ),
        ).listen(
          _onPositionUpdate,
          onError: (Object e) {
            AppLogger.d('⚠️ Error en stream de ubicación (home): $e');
          },
        );
  }

  void _detenerSeguimientoUbicacion() {
    _locationSubscription?.cancel();
    _locationSubscription = null;
  }

  void _onPositionUpdate(Position position) {
    if (_isDisposed) return;
    _currentPosition = position;
    unawaited(_actualizarZonaActual(position));
    unawaited(_sendMapHeartbeat(position));
    notifyListeners();
  }

  Future<void> _sendMapHeartbeat(
    Position position, {
    bool force = false,
  }) async {
    if (_isDisposed || !_isOnline || _turnoActivo == null) return;
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
      await _conductorService.actualizarUbicacionMapa(
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
    } catch (e) {
      AppLogger.d('⚠️ No se pudo enviar heartbeat de mapa: $e');
    } finally {
      _isSendingMapHeartbeat = false;
    }
  }

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
      if (movedMeters < 180 && elapsed < const Duration(seconds: 40)) {
        return;
      }
    }

    _lastAreaResolvedPosition = position;
    _lastAreaResolvedAt = DateTime.now();

    final area = await _reverseGeocodingService.resolveZonaConductor(
      lat: position.latitude,
      lng: position.longitude,
    );
    if (area == null || area.isEmpty) return;
    if (_zonaActual == area) return;
    _zonaActual = area;
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
    try {
      final turno = await _conductorService.getTurnoActivo();

      AppLogger.d(
        '🔄 cargarTurnoActual: encontrado=${turno?.id ?? 'null'}',
      );
      if (turno != null) {
        _turnoActivo = turno;
        _isOnline = true;
        _sincronizarVehiculoSeleccionadoConTurno();

        // Guardar datos del turno en SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt('turno_activo_id', turno.id);
        await prefs.setInt('turno_vehiculo_id', turno.idVehiculo);
        await prefs.setString('turno_fecha', turno.fechaTurno);
        await prefs.setString('turno_hora_inicio', turno.horaInicio);

        await _sincronizarModoDescansoDesdeBackend();
        if (_enDescanso) {
          await _desuscribirRecepcionServicios();
          await _suscribirEmergenciasFlota();
          _limpiarColaSolicitudesLocal();
        } else {
          await conectarPusher();
        }

        if (!_isDisposed) notifyListeners();
      }
    } catch (e) {
      AppLogger.d('❌ Error cargando turno: $e');
    }
  }

  /// Re-sincroniza estado de turno y manda un heartbeat inmediato al volver
  /// al foreground. Esto ayuda a detectar si el backend cierra el turno
  /// mientras la app estuvo en background.
  Future<void> refrescarTurnoYHeartbeatEnResume() async {
    if (_isDisposed) return;
    if (_enServicio) return;

    try {
      AppLogger.d(
        '🔄 [Resume] estado antes: isOnline=$_isOnline turno=${_turnoActivo?.id} enDescanso=$_enDescanso',
      );

      await cargarTurnoActual();

      if (_turnoActivo == null || !_isOnline) {
        // No hay turno activo; nada que hacer.
        return;
      }

      // En caso de que el stream de ubicación haya pausado, pedimos una
      // posición puntual para enviar el heartbeat.
      Position? position = _currentPosition;
      if (position == null) {
        position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 6),
          ),
        );
        _currentPosition = position;
      }

      await _sendMapHeartbeat(position, force: true);

      if (!_isDisposed) notifyListeners();

      AppLogger.d(
        '✅ [Resume] estado después: isOnline=$_isOnline turno=${_turnoActivo?.id} enDescanso=$_enDescanso',
      );
    } catch (e) {
      AppLogger.d('⚠️ [Resume] Error refrescando turno/heartbeat: $e');
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

      // Guardar datos del turno
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
      unawaited(_sendMapHeartbeat(position, force: true));

      // Conectar a Pusher después de iniciar el turno
      await conectarPusher();

      if (!_isDisposed) notifyListeners();
      return true;
    } catch (e) {
      _lastTurnoError = e.toString().replaceAll('Exception: ', '').trim();
      AppLogger.d('❌ Error iniciando turno: $e');
      if (!_isDisposed) notifyListeners();
      return false;
    }
  }

  /// Finaliza el turno actual
  Future<bool> finalizarTurno() async {
    try {
      if (_turnoActivo == null) return false;

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
        }
      }

      // Llamar al servicio para finalizar turno
      await _conductorService.finalizarTurno(_turnoActivo!.id);

      await _limpiarTurnoActivoLocal();
      return true;
    } catch (e) {
      AppLogger.d('❌ Error finalizando turno: $e');
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

      // Limpiar solicitudes activas si es necesario
      _solicitudesActivas.removeWhere(
        (s) =>
            ConductorSolicitudPayloadHelper.obtenerSolicitudId(s) ==
                servicioId.toString() ||
            s['servicio_id']?.toString() == servicioId.toString(),
      );
      _expiracionPorSolicitud.remove(servicioId.toString());
      _detenerTickerSiNoHaySolicitudes();

      if (!_isDisposed) notifyListeners();
      return true;
    } catch (e) {
      AppLogger.d('❌ Error cancelando servicio: $e');
      return false;
    }
  }

  int obtenerSegundosRestantes(String solicitudId) {
    final expiracion = _expiracionPorSolicitud[solicitudId];
    if (expiracion == null) return 0;
    final restantes = expiracion.difference(DateTime.now()).inSeconds;
    return restantes < 0 ? 0 : restantes;
  }

  void _iniciarTickerExpiracionUI() {
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

  void _detenerTickerSiNoHaySolicitudes() {
    if (_solicitudesActivas.isEmpty && _tickerExpiracionUI != null) {
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
    _solicitudesActivas.clear();
    _expiracionPorSolicitud.clear();
    _tickerExpiracionUI?.cancel();
    _tickerExpiracionUI = null;

    if (!_isDisposed) notifyListeners();
  }
}
