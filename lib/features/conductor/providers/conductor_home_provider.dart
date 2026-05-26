import 'dart:async';
import 'dart:convert';
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
import 'package:intellitaxi/config/app_config.dart';
import 'package:intellitaxi/features/conductor/services/conductor_service.dart';
import 'package:intellitaxi/features/conductor/data/documento_vehiculo_model.dart';
import 'package:intellitaxi/features/conductor/data/vehiculo_conductor_model.dart';
import 'package:intellitaxi/features/conductor/data/turno_model.dart';
import 'package:intellitaxi/features/taxi/exceptions/taxi_en_servicio_exception.dart';
import 'package:intellitaxi/features/taxi/utils/taxi_pusher_channels.dart';
import 'package:intellitaxi/config/pusher_config.dart';

/// Provider para gestionar toda la lógica de la pantalla home del conductor
/// Incluye: ubicación, turnos, vehículos, solicitudes de servicio y conexión a Pusher.
/// [kOportunidadConductorSegundos]: tiempo máximo y valor por defecto del contador de oportunidad (TTL).
const int kOportunidadConductorSegundos = 60;

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

  // Estado online/offline
  bool _isOnline = false;
  bool _notificationPermissionRequestedInSession = false;

  // Vehículos y turnos
  VehiculoConductor? _vehiculoSeleccionado;
  List<VehiculoConductor> _vehiculosDisponibles = [];
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
  TurnoActivo? get turnoActivo => _turnoActivo;
  bool get enServicio => _enServicio;
  int? get servicioActivoId => _servicioActivoId;
  Map<String, dynamic>? get servicioActivoPendienteNavegacion =>
      _servicioActivoPendienteNavegacion;

  /// Datos listos para navegar a pantalla de viaje tras bootstrap/aceptar.
  void clearServicioActivoPendienteNavegacion() {
    _servicioActivoPendienteNavegacion = null;
  }

  List<Map<String, dynamic>> get solicitudesActivas => _enServicio
      ? const []
      : _solicitudesActivas;
  String? get lastAcceptError => _lastAcceptError;
  String? get lastTurnoError => _lastTurnoError;
  List<Map<String, dynamic>> get solicitudesOrdenadas {
    final solicitudes = List<Map<String, dynamic>>.from(_solicitudesActivas);
    solicitudes.sort((a, b) => _calcularScore(b).compareTo(_calcularScore(a)));
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
      final idStr = _obtenerSolicitudId(s);
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
      final da = _parseDouble(a['distancia_hacia_ruta_km'], fallback: 999);
      final db = _parseDouble(b['distancia_hacia_ruta_km'], fallback: 999);
      return da.compareTo(db);
    });

    return candidatas;
  }

  Map<String, dynamic>? get solicitudPrincipal =>
      solicitudesOrdenadas.isEmpty ? null : solicitudesOrdenadas.first;
  bool get tieneTurnoActivo => _turnoActivo != null;

  /// Inicializar el provider
  Future<void> initialize() async {
    await initializeLocation();
    await cargarVehiculos();
    await bootstrapTaxiConductor();
    if (!_enServicio) {
      await cargarTurnoActual();
    }
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

    if (_isOnline && !_suscritoAPusher) {
      await conectarPusher();
    }

    if (!_isDisposed) notifyListeners();
  }

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

      final ids = await _obtenerIdsConductorSesion();
      if (ids.isNotEmpty) {
        final candidateChannels = <String>{};
        for (final id in ids) {
          // Formato esperado con PrivateChannel('conductor.{id}')
          candidateChannels.add('private-conductor.$id');
          // Fallback si backend emite Channel('conductor.{id}')
          candidateChannels.add('conductor.$id');
        }

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

      _suscritoAPusher = true;
      _iniciarSincronizacionSolicitudes();
      unawaited(sincronizarSolicitudesPublicadasConductor());
      AppLogger.d('✅ Suscrito correctamente al canal de solicitudes');
    } catch (e) {
      AppLogger.d('❌ Error al conectarse a Pusher: $e');
    }
  }

  void _iniciarSincronizacionSolicitudes() {
    if (_enServicio) return;
    _syncSolicitudesTimer?.cancel();
    _syncSolicitudesTimer = Timer.periodic(const Duration(seconds: 50), (_) {
      if (!_isDisposed && _suscritoAPusher && _isOnline) {
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
    if (_isDisposed || !_isOnline || _enServicio) return;
    try {
      final result = await _conductorService
          .listarSolicitudesPublicadasConductor();

      if (result.enServicio) {
        await _activarModoEnServicio(
          servicioActivoId: result.servicioActivoId,
        );
        return;
      }

      final list = result.solicitudes;
      final serverIds = <String>{};
      for (final m in list) {
        final sid = m['servicio_id'] ?? m['solicitud_id'] ?? m['id'];
        if (sid != null) serverIds.add(sid.toString());
      }

      for (final s in List<Map<String, dynamic>>.from(_solicitudesActivas)) {
        final id = _obtenerSolicitudId(s);
        if (id == null || id.isEmpty || id.startsWith('temp_')) continue;
        if (int.tryParse(id) == null) continue;
        if (!serverIds.contains(id)) {
          rechazarSolicitud(id);
        }
      }

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
      _detenerSincronizacionSolicitudes();
      AppLogger.d('🔌 Desconectándose de Pusher...');
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
      await PusherService.unsubscribeSecondary(
        TaxiPusherChannels.solicitudesServicio,
      );

      for (final key in _offerHandlerKeys) {
        PusherService.unregisterEventHandlerSecondary(key);
      }
      _offerHandlerKeys.clear();

      for (final channel in _offerChannels) {
        await PusherService.unsubscribeSecondary(channel);
      }
      _offerChannels.clear();

      await _desuscribirEmergenciasFlota();

      _suscritoAPusher = false;
      AppLogger.d('✅ Desconectado de Pusher');
    } catch (e) {
      AppLogger.d('❌ Error al desconectar Pusher: $e');
    }
  }

  Future<void> _desuscribirCanalSolicitudesServicio() async {
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
    _suscritoAPusher = false;
  }

  void _procesarSolicitudTomada(dynamic data) {
    try {
      final raw = _parsePayload(data);
      final servicioId = raw['servicio_id'] ??
          raw['solicitud_id'] ??
          raw['id'];
      if (servicioId == null) return;
      rechazarSolicitud(servicioId.toString());
    } catch (e) {
      AppLogger.d('⚠️ Error procesando solicitud.tomada: $e');
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

    try {
      final raw = _parsePayload(data);
      final solicitud = _normalizarSolicitud(
        raw,
        isDirectOffer: isDirectOffer,
      );
      var solicitudId = _obtenerSolicitudId(solicitud);
      if (solicitudId == null || solicitudId.isEmpty) {
        solicitudId = _generarSolicitudTemporalId();
        solicitud['temp_id'] = solicitudId;
        solicitud['solicitud_id'] = solicitud['solicitud_id'] ?? solicitudId;
        solicitud['servicio_id'] = solicitud['servicio_id'] ?? solicitudId;
        solicitud['id'] = solicitud['id'] ?? solicitudId;
        AppLogger.d('ℹ️ Solicitud sin id, asignando temporal: $solicitudId');
      }
      solicitud['_local_id'] = solicitudId;
      AppLogger.d('📩 Solicitud decodificada: $solicitudId');

      // Verificar si ya existe la solicitud
      final yaExiste = _solicitudesActivas.any(
        (s) => _obtenerSolicitudId(s) == solicitudId,
      );
      if (yaExiste) {
        AppLogger.d('⚠️ Solicitud ya existe: $solicitudId');
        return;
      }

      // Agregar solicitud a la lista
      _solicitudesActivas.add(solicitud);

      if (!fromSync) {
        _reproducirSonidoNotificacion();
        VoiceAlertService.announceNewService();
        unawaited(_notificarYEnriquecerSolicitud(solicitudId));
      } else {
        unawaited(_enriquecerDireccionesSolicitud(solicitudId));
      }

      final ttlSegundos = _resolverTtlSegundos(solicitud);
      _expiracionPorSolicitud[solicitudId] = DateTime.now().add(
        Duration(seconds: ttlSegundos),
      );

      // Configurar timer de expiración
      _configurarTimerExpiracion(solicitudId, ttlSegundos: ttlSegundos);
      _iniciarTickerExpiracionUI();

      if (!_isDisposed) notifyListeners();
    } catch (e) {
      AppLogger.d('❌ Error procesando solicitud: $e');
    }
  }

  Map<String, dynamic> _parsePayload(dynamic data) {
    Map<String, dynamic> payload;
    if (data is String) {
      payload = json.decode(data) as Map<String, dynamic>;
    } else if (data is Map<String, dynamic>) {
      payload = data;
    } else if (data is Map) {
      payload = Map<String, dynamic>.from(data);
    } else {
      throw Exception('Payload no soportado: ${data.runtimeType}');
    }

    final merged = Map<String, dynamic>.from(payload);
    if (payload['data'] is Map) {
      merged.addAll(Map<String, dynamic>.from(payload['data'] as Map));
    }
    if (payload['solicitud'] is Map) {
      merged.addAll(Map<String, dynamic>.from(payload['solicitud'] as Map));
    }
    if (payload['servicio'] is Map) {
      merged.addAll(Map<String, dynamic>.from(payload['servicio'] as Map));
    }

    return merged;
  }

  Map<String, dynamic> _normalizarSolicitud(
    Map<String, dynamic> raw, {
    bool isDirectOffer = false,
  }) {
    final base = isDirectOffer
        ? _normalizarOfertaDirecta(raw)
        : SolicitudDisplayHelper.normalizeSolicitudMap(raw);
    final barrio = SolicitudDisplayHelper.barrioFromPayload(base);
    if (barrio != null) {
      base['origen_barrio'] = barrio;
    }
    return base;
  }

  Map<String, dynamic> _normalizarOfertaDirecta(Map<String, dynamic> raw) {
    final merged = SolicitudDisplayHelper.normalizeSolicitudMap(raw);
    final solicitudId = merged['solicitud_id'] ?? merged['id'];
    return {
      ...merged,
      'solicitud_id': solicitudId,
      'servicio_id': solicitudId,
      'id': solicitudId,
      'pasajero_id': merged['pasajero_id'],
      'pasajero_nombre': merged['pasajero_nombre'] ?? 'Pasajero',
      'pasajero_foto': _resolverFotoPasajero(merged['pasajero_foto']?.toString()),
      'origen': SolicitudDisplayHelper.pickupName(merged),
      'destino': SolicitudDisplayHelper.destinationName(merged),
      'origen_name': merged['origen_name'],
      'origen_address': merged['origen_address'],
      'destino_name': merged['destino_name'],
      'destino_address': merged['destino_address'],
      'origen_barrio': merged['origen_barrio'] ?? merged['barrio'],
      'origen_lat': merged['origen_lat'],
      'origen_lng': merged['origen_lng'],
      'destino_lat': merged['destino_lat'],
      'destino_lng': merged['destino_lng'],
      'precio_ofertado':
          merged['precio_ofrecido'] ?? merged['precio_ofertado'] ?? 0,
      'distancia': merged['distancia'],
      'duracion_estimada': merged['duracion_estimada'],
      'mensaje': merged['mensaje'],
      'status': 'oferta_directa',
      'clase_vehiculo': 'taxi',
      'timestamp': merged['timestamp'] ?? DateTime.now().toIso8601String(),
      'ttl_segundos': merged['ttl_segundos'] ?? kOportunidadConductorSegundos,
    };
  }

  Future<void> _notificarYEnriquecerSolicitud(String solicitudId) async {
    await _enriquecerDireccionesSolicitud(solicitudId);
    if (_isDisposed) return;
    final index = _solicitudesActivas.indexWhere(
      (s) => _obtenerSolicitudId(s) == solicitudId,
    );
    if (index < 0) return;
    await IncomingServiceNotificationService.instance.showIncomingService(
      _solicitudesActivas[index],
    );
  }

  Future<void> _enriquecerDireccionesSolicitud(String solicitudId) async {
    final index = _solicitudesActivas.indexWhere(
      (s) => _obtenerSolicitudId(s) == solicitudId,
    );
    if (index < 0 || _isDisposed) return;

    final solicitud = _solicitudesActivas[index];
    var changed = false;

    Future<void> enrichPoint({
      required bool isDestino,
      required double lat,
      required double lng,
    }) async {
      final label = await _reverseGeocodingService.resolveCurrentLocationLabel(
        lat: lat,
        lng: lng,
      );

      if (isDestino) {
        final hasName = _hasMeaningfulPlaceName(
          solicitud['destino_name']?.toString(),
        );
        if (!hasName &&
            label.name.trim().isNotEmpty &&
            !SolicitudDisplayHelper.isPlaceholderDestino(label.name)) {
          solicitud['destino_name'] = label.name;
          changed = true;
        }
        final hasAddr = _hasMeaningfulAddress(
          solicitud['destino_address']?.toString(),
        );
        if (!hasAddr &&
            label.address.trim().isNotEmpty &&
            !SolicitudDisplayHelper.isPlaceholderDestino(label.address)) {
          solicitud['destino_address'] = label.address;
          changed = true;
        }
      } else {
        final hasName = _hasMeaningfulPlaceName(
          solicitud['origen_name']?.toString(),
        );
        if (!hasName &&
            label.name.trim().isNotEmpty &&
            !SolicitudDisplayHelper.isPlaceholderPickup(label.name)) {
          solicitud['origen_name'] = label.name;
          changed = true;
        }
        final hasAddr = _hasMeaningfulAddress(
          solicitud['origen_address']?.toString(),
        );
        if (!hasAddr &&
            label.address.trim().isNotEmpty &&
            !SolicitudDisplayHelper.isPlaceholderPickup(label.address)) {
          solicitud['origen_address'] = label.address;
          changed = true;
        }
        if ((solicitud['origen_barrio']?.toString().trim().isEmpty ?? true)) {
          final barrio = await _reverseGeocodingService.resolveAreaName(
            lat: lat,
            lng: lng,
          );
          if (barrio != null && barrio.isNotEmpty) {
            solicitud['origen_barrio'] =
                SolicitudDisplayHelper.compactBarrio(barrio);
            changed = true;
          }
        }
      }
    }

    final oLat = SolicitudDisplayHelper.parseCoordinate(solicitud['origen_lat']);
    final oLng = SolicitudDisplayHelper.parseCoordinate(solicitud['origen_lng']);
    if (oLat != null && oLng != null) {
      await enrichPoint(isDestino: false, lat: oLat, lng: oLng);
    }

    final dLat = SolicitudDisplayHelper.parseCoordinate(solicitud['destino_lat']);
    final dLng = SolicitudDisplayHelper.parseCoordinate(solicitud['destino_lng']);
    if (dLat != null &&
        dLng != null &&
        (dLat.abs() > 0.0001 || dLng.abs() > 0.0001)) {
      await enrichPoint(isDestino: true, lat: dLat, lng: dLng);
    }

    if (changed && !_isDisposed) notifyListeners();
  }

  bool _hasMeaningfulPlaceName(String? value) {
    if (value == null || value.trim().isEmpty) return false;
    return !SolicitudDisplayHelper.isPlaceholderPickup(value) &&
        !SolicitudDisplayHelper.isPlaceholderDestino(value);
  }

  bool _hasMeaningfulAddress(String? value) {
    if (value == null || value.trim().isEmpty) return false;
    if (SolicitudDisplayHelper.isPlaceholderPickup(value)) return false;
    if (SolicitudDisplayHelper.isPlaceholderDestino(value)) return false;
    return true;
  }

  String? _resolverFotoPasajero(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final foto = value.trim();
    if (foto.startsWith('http://') || foto.startsWith('https://')) return foto;

    final base = Uri.parse(AppConfig.baseUrl);
    final origin =
        '${base.scheme}://${base.host}${base.hasPort ? ':${base.port}' : ''}';
    if (foto.startsWith('/')) return '$origin$foto';
    return '$origin/$foto';
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
          (_obtenerSolicitudId(s) == solicitudId),
    );
    if (index != -1) {
      _solicitudesActivas.removeAt(index);
    } else {
      _solicitudesActivas.removeWhere(
        (s) => _obtenerSolicitudId(s) == solicitudId,
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
    _solicitudesActivas.removeWhere(
      (s) => _obtenerSolicitudId(s) == solicitudId,
    );
    _expiracionPorSolicitud.remove(solicitudId);
    _timersExpiracion[solicitudId]?.cancel();
    _timersExpiracion.remove(solicitudId);
    _detenerTickerSiNoHaySolicitudes();
    if (!_isDisposed) notifyListeners();
  }

  /// Acepta una solicitud de servicio
  Future<Map<String, dynamic>?> aceptarSolicitud(
    String solicitudId,
    int idVehiculo,
  ) async {
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

      // Llamar al servicio para aceptar
      final response = await _conductorService.aceptarSolicitud(
        servicioId: solicitudId,
        precioOfertado: 0.0, // Precio a negociar según lógica de negocio
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
        (s) => _obtenerSolicitudId(s) == solicitudId,
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
        estado: 'disponible',
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

    final area = await _reverseGeocodingService.resolveAreaName(
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

  /// Carga los vehículos disponibles del conductor
  Future<void> cargarVehiculos() async {
    try {
      final vehiculos = await _conductorService.getVehiculosConductor();
      if (_isDisposed) return;
      _vehiculosDisponibles = vehiculos;
      _sincronizarVehiculoSeleccionadoConTurno();
      if (!_isDisposed) notifyListeners();
    } catch (e) {
      AppLogger.d('❌ Error cargando vehículos: $e');
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

      if (turno != null) {
        _turnoActivo = turno;
        _isOnline = true;
        _sincronizarVehiculoSeleccionadoConTurno();

        // Conectar a Pusher automáticamente si hay turno activo
        await conectarPusher();

        // Guardar datos del turno en SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt('turno_activo_id', turno.id);
        await prefs.setInt('turno_vehiculo_id', turno.idVehiculo);
        await prefs.setString('turno_fecha', turno.fechaTurno);
        await prefs.setString('turno_hora_inicio', turno.horaInicio);

        if (!_isDisposed) notifyListeners();
      }
    } catch (e) {
      AppLogger.d('❌ Error cargando turno: $e');
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
            _obtenerSolicitudId(s) == servicioId.toString() ||
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

  int _resolverTtlSegundos(Map<String, dynamic> solicitud) {
    final ttlRaw =
        solicitud['ttl_segundos'] ??
        solicitud['ttl'] ??
        solicitud['tiempo_restante'];
    final ttl = int.tryParse(ttlRaw?.toString() ?? '');
    if (ttl == null || ttl <= 0) return kOportunidadConductorSegundos;
    return ttl > kOportunidadConductorSegundos
        ? kOportunidadConductorSegundos
        : ttl;
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

  String? _obtenerSolicitudId(Map<String, dynamic> solicitud) {
    final rawId =
        solicitud['_local_id'] ??
        solicitud['solicitud_id'] ??
        solicitud['solicitudId'] ??
        solicitud['servicio_id'] ??
        solicitud['servicioId'] ??
        solicitud['id'] ??
        solicitud['ride_id'] ??
        solicitud['request_id'] ??
        solicitud['temp_id'];
    return rawId?.toString();
  }

  Future<Set<int>> _obtenerIdsConductorSesion() async {
    final prefs = await SharedPreferences.getInstance();
    final userDataStr = prefs.getString('user_data');
    if (userDataStr == null || userDataStr.isEmpty) return {};

    try {
      final userData = json.decode(userDataStr);
      final ids = <int>{};

      final userId = userData['user']?['id'];
      final personaId = userData['user']?['persona']?['id'];

      final parsedUserId = userId is int
          ? userId
          : int.tryParse(userId?.toString() ?? '');
      final parsedPersonaId = personaId is int
          ? personaId
          : int.tryParse(personaId?.toString() ?? '');

      if (parsedUserId != null && parsedUserId > 0) ids.add(parsedUserId);
      if (parsedPersonaId != null && parsedPersonaId > 0) {
        ids.add(parsedPersonaId);
      }

      return ids;
    } catch (_) {
      return {};
    }
  }

  double _parseDouble(dynamic value, {double fallback = 0.0}) {
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      return double.tryParse(value.replaceAll(',', '.')) ?? fallback;
    }
    return fallback;
  }

  double _calcularScore(Map<String, dynamic> solicitud) {
    // Ranking simple y estable para priorizar: menor distancia + mayor tarifa + reciente
    final distanciaMetros =
        solicitud['distanciaMetros'] ?? solicitud['distancia_metros'];
    final distanciaValor =
        solicitud['distancia_km'] ??
        solicitud['distancia'] ??
        (distanciaMetros != null
            ? (_parseDouble(distanciaMetros) / 1000.0)
            : null);
    final distanciaKm = _parseDouble(distanciaValor, fallback: 999.0);

    final precio = _parseDouble(
      solicitud['precio_estimado'] ??
          solicitud['precioEstimado'] ??
          solicitud['precio'] ??
          solicitud['precio_ofertado'],
    );

    final createdAtRaw =
        solicitud['created_at'] ??
        solicitud['createdAt'] ??
        solicitud['fechaServicio'] ??
        solicitud['timestamp'];
    final createdAt = DateTime.tryParse(createdAtRaw?.toString() ?? '');
    final segundosDesdeCreacion = createdAt == null
        ? 0
        : DateTime.now().difference(createdAt).inSeconds.clamp(0, 300);
    final scoreDistancia = (100 - (distanciaKm * 10)).clamp(0, 100);
    final scorePrecio = (precio / 1000).clamp(0, 100);
    final scoreRecencia = (300 - segundosDesdeCreacion).toDouble() / 10.0;

    return (scoreDistancia * 0.55) +
        (scorePrecio * 0.35) +
        (scoreRecencia * 0.10);
  }

  String _generarSolicitudTemporalId() {
    return 'temp_${DateTime.now().microsecondsSinceEpoch}';
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
