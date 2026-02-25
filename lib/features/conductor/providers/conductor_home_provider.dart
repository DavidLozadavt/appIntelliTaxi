import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:intellitaxi/features/conductor/services/conductor_service.dart';
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

  // Estado online/offline
  bool _isOnline = false;

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

  // Control de dispose
  bool _isDisposed = false;

  // Getters
  Position? get currentPosition => _currentPosition;
  bool get isLoadingLocation => _isLoadingLocation;
  String get locationMessage => _locationMessage;
  bool get isOnline => _isOnline;
  VehiculoConductor? get vehiculoSeleccionado => _vehiculoSeleccionado;
  List<VehiculoConductor> get vehiculosDisponibles => _vehiculosDisponibles;
  TurnoActivo? get turnoActivo => _turnoActivo;
  List<Map<String, dynamic>> get solicitudesActivas => _solicitudesActivas;
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
    desconectarPusher();
    super.dispose();
  }

  // ==================== CONEXIÓN PUSHER ====================

  /// Conecta a Pusher y se suscribe al canal de solicitudes
  Future<void> conectarPusher() async {
    try {
      if (_suscritoAPusher) {
        print('⚠️ Ya está suscrito a solicitudes-servicio');
        return;
      }

      print('🔌 Suscribiéndose al canal de solicitudes...');

      await PusherService.subscribeSecondary('solicitudes-servicio');

      // Registrar el handler para el evento
      PusherService.registerEventHandlerSecondary(
        'solicitudes-servicio:nueva-solicitud',
        (data) {
          print('🔔 Evento recibido: nueva-solicitud');
          if (data != null) {
            _procesarNuevaSolicitud(data);
          }
        },
      );

      _suscritoAPusher = true;
      print('✅ Suscrito correctamente al canal de solicitudes');
    } catch (e) {
      print('❌ Error al conectarse a Pusher: $e');
    }
  }

  /// Desconecta de Pusher
  Future<void> desconectarPusher() async {
    try {
      print('🔌 Desconectándose de Pusher...');
      PusherService.unregisterEventHandlerSecondary(
        'solicitudes-servicio:nueva-solicitud',
      );
      await PusherService.unsubscribeSecondary('solicitudes-servicio');
      _suscritoAPusher = false;
      print('✅ Desconectado de Pusher');
    } catch (e) {
      print('❌ Error al desconectar Pusher: $e');
    }
  }

  /// Procesa una nueva solicitud recibida de Pusher
  void _procesarNuevaSolicitud(String data) {
    try {
      final solicitud = json.decode(data) as Map<String, dynamic>;
      final solicitudId = _obtenerSolicitudId(solicitud);
      print('📩 Solicitud decodificada: $solicitudId');

      // Verificar si ya existe la solicitud
      final yaExiste = _solicitudesActivas.any(
        (s) => _obtenerSolicitudId(s) == solicitudId,
      );
      if (yaExiste) {
        print('⚠️ Solicitud ya existe: $solicitudId');
        return;
      }

      if (solicitudId == null || solicitudId.isEmpty) {
        print('⚠️ Solicitud descartada: no contiene id válido');
        return;
      }

      // Agregar solicitud a la lista
      _solicitudesActivas.add(solicitud);

      // Reproducir sonido de notificación
      _reproducirSonidoNotificacion();

      final ttlSegundos = _resolverTtlSegundos(solicitud);
      _expiracionPorSolicitud[solicitudId] = DateTime.now().add(
        Duration(seconds: ttlSegundos),
      );

      // Configurar timer de expiración
      _configurarTimerExpiracion(solicitudId, ttlSegundos: ttlSegundos);
      _iniciarTickerExpiracionUI();

      if (!_isDisposed) notifyListeners();
    } catch (e) {
      print('❌ Error procesando solicitud: $e');
    }
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
    print('⏱️ Solicitud expirada: $solicitudId');
    _solicitudesActivas.removeWhere(
      (s) => _obtenerSolicitudId(s) == solicitudId,
    );
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
      print('❌ Error reproduciendo sonido: $e');
    }
  }

  // ==================== MANEJO DE SOLICITUDES ====================

  /// Rechaza una solicitud
  void rechazarSolicitud(String solicitudId) {
    print('❌ Rechazando solicitud: $solicitudId');
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
      print('✅ Aceptando solicitud: $solicitudId');

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
      print('❌ Error aceptando solicitud: $e');
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
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      if (_isDisposed) return;

      _currentPosition = position;
      _isLoadingLocation = false;
      _locationMessage = 'Ubicación obtenida';
      if (!_isDisposed) notifyListeners();

      print(
        '📍 Ubicación obtenida: ${position.latitude}, ${position.longitude}',
      );
    } catch (e) {
      print('❌ Error obteniendo ubicación: $e');

      if (_isDisposed) return;

      _isLoadingLocation = false;
      _locationMessage = 'Error obteniendo ubicación: ${e.toString()}';
      if (!_isDisposed) notifyListeners();
    }
  }

  // ==================== VEHÍCULOS ====================

  /// Carga los vehículos disponibles del conductor
  Future<void> cargarVehiculos() async {
    try {
      final vehiculos = await _conductorService.getVehiculosConductor();
      if (_isDisposed) return;
      _vehiculosDisponibles = vehiculos;
      if (!_isDisposed) notifyListeners();
    } catch (e) {
      print('❌ Error cargando vehículos: $e');
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
      print('❌ Error cargando turno: $e');
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
            desiredAccuracy: LocationAccuracy.high,
            timeLimit: const Duration(seconds: 5),
          );
        } catch (e) {
          print('⚠️ Error obteniendo ubicación: $e');
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

      // Conectar a Pusher después de iniciar el turno
      await conectarPusher();

      if (!_isDisposed) notifyListeners();
      return true;
    } catch (e) {
      print('❌ Error iniciando turno: $e');
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
            desiredAccuracy: LocationAccuracy.high,
            timeLimit: const Duration(seconds: 5),
          );
        } catch (e) {
          print('⚠️ Error obteniendo ubicación: $e');
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
      _solicitudesActivas.clear();
      _expiracionPorSolicitud.clear();
      _tickerExpiracionUI?.cancel();
      _tickerExpiracionUI = null;

      if (!_isDisposed) notifyListeners();
      return true;
    } catch (e) {
      print('❌ Error finalizando turno: $e');
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

  /// Verifica documentos del conductor
  Future<Map<String, dynamic>> verificarDocumentos(int userId) async {
    try {
      return await _conductorService.verificarDocumentos(userId);
    } catch (e) {
      print('❌ Error verificando documentos: $e');
      return {'vencidos': [], 'porVencer': []};
    }
  }

  /// Cancelar servicio activo
  Future<bool> cancelarServicio({
    required int servicioId,
    required String motivo,
  }) async {
    try {
      print('🚫 Cancelando servicio: $servicioId');

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
      print('❌ Error cancelando servicio: $e');
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
        solicitud['solicitud_id'] ??
        solicitud['servicio_id'] ??
        solicitud['id'] ??
        solicitud['request_id'];
    return rawId?.toString();
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
}
