import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:intellitaxi/core/services/app_logger.dart';
import 'package:intellitaxi/core/services/reverse_geocoding_service.dart';
import 'package:intellitaxi/core/services/voice_alert_service.dart';
import 'package:intellitaxi/config/app_config.dart';
import 'package:intellitaxi/features/conductor/services/conductor_service.dart';
import 'package:intellitaxi/features/conductor/data/documento_vehiculo_model.dart';
import 'package:intellitaxi/features/conductor/data/vehiculo_conductor_model.dart';
import 'package:intellitaxi/features/conductor/data/turno_model.dart';
import 'package:intellitaxi/config/pusher_config.dart';

/// Provider para gestionar toda la lógica de la pantalla home del conductor
/// Incluye: ubicación, turnos, vehículos, solicitudes de servicio y conexión a Pusher
class ConductorHomeProvider extends ChangeNotifier {
  // Servicios
  final ConductorService _conductorService = ConductorService();
  final AudioPlayer _audioPlayer = AudioPlayer();

  // Estado de ubicación
  Position? _currentPosition;
  bool _isLoadingLocation = true;
  String _locationMessage =
      'Estableciendo conexión satelital para rastreo en tiempo real...';
  String? _zonaActual;
  Timer? _liveLocationTicker;
  Position? _lastAreaResolvedPosition;
  DateTime? _lastAreaResolvedAt;
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
  bool _suscritoAPusher = false;
  final Set<String> _offerChannels = {};
  final Set<String> _offerHandlerKeys = {};
  String? _lastAcceptError;

  // Control de dispose
  bool _isDisposed = false;

  // Getters
  Position? get currentPosition => _currentPosition;
  bool get isLoadingLocation => _isLoadingLocation;
  String get locationMessage => _locationMessage;
  String? get zonaActual => _zonaActual;
  bool get isOnline => _isOnline;
  VehiculoConductor? get vehiculoSeleccionado => _vehiculoSeleccionado;
  List<VehiculoConductor> get vehiculosDisponibles => _vehiculosDisponibles;
  TurnoActivo? get turnoActivo => _turnoActivo;
  List<Map<String, dynamic>> get solicitudesActivas => _solicitudesActivas;
  String? get lastAcceptError => _lastAcceptError;
  List<Map<String, dynamic>> get solicitudesOrdenadas {
    final solicitudes = List<Map<String, dynamic>>.from(_solicitudesActivas);
    solicitudes.sort((a, b) => _calcularScore(b).compareTo(_calcularScore(a)));
    return solicitudes;
  }

  Map<String, dynamic>? get solicitudPrincipal =>
      solicitudesOrdenadas.isEmpty ? null : solicitudesOrdenadas.first;
  bool get tieneTurnoActivo => _turnoActivo != null;

  /// Inicializar el provider
  Future<void> initialize() async {
    await initializeLocation();
    await cargarVehiculos();
    await cargarTurnoActual();
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
    _liveLocationTicker?.cancel();
    _liveLocationTicker = null;
    VoiceAlertService.dispose();
    desconectarPusher();
    super.dispose();
  }

  // ==================== CONEXIÓN PUSHER ====================

  /// Conecta a Pusher y se suscribe al canal de solicitudes
  Future<void> conectarPusher() async {
    try {
      if (_suscritoAPusher) {
        AppLogger.d('⚠️ Ya está suscrito a solicitudes-servicio');
        return;
      }

      AppLogger.d('🔌 Suscribiéndose al canal de solicitudes...');

      await PusherService.subscribeSecondary('solicitudes-servicio');

      // Registrar handlers para variantes del evento de nuevas solicitudes
      for (final eventName in const [
        'nueva-solicitud',
        'nueva_solicitud',
        'nueva-oferta',
        'nueva_oferta',
      ]) {
        PusherService.registerEventHandlerSecondary(
          'solicitudes-servicio:$eventName',
          (data) {
            AppLogger.d('🔔 Evento recibido: $eventName');
            if (data != null) {
              _procesarNuevaSolicitud(data);
            }
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

      _suscritoAPusher = true;
      AppLogger.d('✅ Suscrito correctamente al canal de solicitudes');
    } catch (e) {
      AppLogger.d('❌ Error al conectarse a Pusher: $e');
    }
  }

  /// Desconecta de Pusher
  Future<void> desconectarPusher() async {
    try {
      AppLogger.d('🔌 Desconectándose de Pusher...');
      for (final eventName in const [
        'nueva-solicitud',
        'nueva_solicitud',
        'nueva-oferta',
        'nueva_oferta',
      ]) {
        PusherService.unregisterEventHandlerSecondary(
          'solicitudes-servicio:$eventName',
        );
      }
      await PusherService.unsubscribeSecondary('solicitudes-servicio');

      for (final key in _offerHandlerKeys) {
        PusherService.unregisterEventHandlerSecondary(key);
      }
      _offerHandlerKeys.clear();

      for (final channel in _offerChannels) {
        await PusherService.unsubscribeSecondary(channel);
      }
      _offerChannels.clear();

      _suscritoAPusher = false;
      AppLogger.d('✅ Desconectado de Pusher');
    } catch (e) {
      AppLogger.d('❌ Error al desconectar Pusher: $e');
    }
  }

  /// Procesa una nueva solicitud recibida de Pusher
  void _procesarNuevaSolicitud(dynamic data, {bool isDirectOffer = false}) {
    try {
      final raw = _parsePayload(data);
      final solicitud = isDirectOffer ? _normalizarOfertaDirecta(raw) : raw;
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

      // Reproducir sonido de notificación
      _reproducirSonidoNotificacion();
      VoiceAlertService.announceNewService();

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

    if (payload['data'] is Map) {
      return Map<String, dynamic>.from(payload['data'] as Map);
    }
    if (payload['solicitud'] is Map) {
      return Map<String, dynamic>.from(payload['solicitud'] as Map);
    }
    if (payload['servicio'] is Map) {
      return Map<String, dynamic>.from(payload['servicio'] as Map);
    }

    return payload;
  }

  Map<String, dynamic> _normalizarOfertaDirecta(Map<String, dynamic> raw) {
    final solicitudId = raw['solicitud_id'] ?? raw['id'];
    return {
      'solicitud_id': solicitudId,
      'servicio_id': solicitudId,
      'id': solicitudId,
      'pasajero_id': raw['pasajero_id'],
      'pasajero_nombre': raw['pasajero_nombre'] ?? 'Pasajero',
      'pasajero_foto': _resolverFotoPasajero(raw['pasajero_foto']?.toString()),
      'origen': raw['origen'] ?? 'Origen no especificado',
      'destino': raw['destino'] ?? 'Destino no especificado',
      'origen_lat': raw['origen_lat'],
      'origen_lng': raw['origen_lng'],
      'destino_lat': raw['destino_lat'],
      'destino_lng': raw['destino_lng'],
      'precio_ofertado': raw['precio_ofrecido'] ?? raw['precio_ofertado'] ?? 0,
      'distancia': raw['distancia'],
      'duracion_estimada': raw['duracion_estimada'],
      'mensaje': raw['mensaje'],
      'status': 'oferta_directa',
      'clase_vehiculo': 'taxi',
      'timestamp': raw['timestamp'] ?? DateTime.now().toIso8601String(),
      'ttl_segundos': raw['ttl_segundos'] ?? 25,
    };
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
  void _configurarTimerExpiracion(String solicitudId, {int ttlSegundos = 20}) {
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

      // Remover de la lista de solicitudes activas
      _solicitudesActivas.removeWhere(
        (s) => _obtenerSolicitudId(s) == solicitudId,
      );
      _expiracionPorSolicitud.remove(solicitudId);
      _detenerTickerSiNoHaySolicitudes();

      if (!_isDisposed) notifyListeners();
      return response;
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
    _liveLocationTicker?.cancel();
    _liveLocationTicker = Timer.periodic(const Duration(seconds: 15), (_) {
      _refrescarUbicacion();
    });
  }

  Future<void> _refrescarUbicacion() async {
    if (_isDisposed) return;
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 8),
        ),
      );
      _currentPosition = position;
      _actualizarZonaActual(position);
      if (!_isDisposed) notifyListeners();
    } catch (_) {
      // Silencioso: no interrumpir la experiencia por fallos intermitentes GPS.
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

      // Conectar a Pusher después de iniciar el turno
      await conectarPusher();

      if (!_isDisposed) notifyListeners();
      return true;
    } catch (e) {
      AppLogger.d('❌ Error iniciando turno: $e');
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

      // Limpiar SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('turno_activo_id');
      await prefs.remove('turno_vehiculo_id');
      await prefs.remove('turno_fecha');
      await prefs.remove('turno_hora_inicio');

      // Desconectar de Pusher
      await desconectarPusher();

      _turnoActivo = null;
      _isOnline = false;
      _vehiculoSeleccionado = null;
      _solicitudesActivas.clear();
      _expiracionPorSolicitud.clear();
      _tickerExpiracionUI?.cancel();
      _tickerExpiracionUI = null;

      if (!_isDisposed) notifyListeners();
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
    if (ttl == null || ttl <= 0) return 20;
    return ttl > 90 ? 90 : ttl;
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
}
