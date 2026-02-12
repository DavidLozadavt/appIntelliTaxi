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
  bool _suscritoAPusher = false;

  // Getters
  Position? get currentPosition => _currentPosition;
  bool get isLoadingLocation => _isLoadingLocation;
  String get locationMessage => _locationMessage;
  bool get isOnline => _isOnline;
  VehiculoConductor? get vehiculoSeleccionado => _vehiculoSeleccionado;
  List<VehiculoConductor> get vehiculosDisponibles => _vehiculosDisponibles;
  TurnoActivo? get turnoActivo => _turnoActivo;
  List<Map<String, dynamic>> get solicitudesActivas => _solicitudesActivas;
  bool get tieneTurnoActivo => _turnoActivo != null;

  /// Inicializar el provider
  Future<void> initialize() async {
    await initializeLocation();
    await cargarVehiculos();
    await cargarTurnoActual();
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    // Cancelar todos los timers
    for (var timer in _timersExpiracion.values) {
      timer.cancel();
    }
    _timersExpiracion.clear();
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
      print('📩 Solicitud decodificada: ${solicitud['id']}');

      // Verificar si ya existe la solicitud
      final yaExiste = _solicitudesActivas.any(
        (s) => s['id'] == solicitud['id'],
      );
      if (yaExiste) {
        print('⚠️ Solicitud ya existe: ${solicitud['id']}');
        return;
      }

      // Agregar solicitud a la lista
      _solicitudesActivas.add(solicitud);

      // Reproducir sonido de notificación
      _reproducirSonidoNotificacion();

      // Configurar timer de expiración
      _configurarTimerExpiracion(solicitud['id'].toString());

      notifyListeners();
    } catch (e) {
      print('❌ Error procesando solicitud: $e');
    }
  }

  /// Configurar timer de expiración para una solicitud
  void _configurarTimerExpiracion(String solicitudId) {
    _timersExpiracion[solicitudId]?.cancel();

    _timersExpiracion[solicitudId] = Timer(const Duration(seconds: 20), () {
      _expirarSolicitud(solicitudId);
    });
  }

  /// Expira una solicitud después del tiempo límite
  void _expirarSolicitud(String solicitudId) {
    print('⏱️ Solicitud expirada: $solicitudId');
    _solicitudesActivas.removeWhere(
      (s) => s['solicitud_id']?.toString() == solicitudId,
    );
    _timersExpiracion.remove(solicitudId);
    notifyListeners();
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
      (s) => s['solicitud_id']?.toString() == solicitudId,
    );
    _timersExpiracion[solicitudId]?.cancel();
    _timersExpiracion.remove(solicitudId);
    notifyListeners();
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
        (s) => s['solicitud_id']?.toString() == solicitudId,
      );

      notifyListeners();
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
    notifyListeners();

    bool permissionGranted = await _checkAndRequestPermissions();

    if (!permissionGranted) {
      _isLoadingLocation = false;
      _locationMessage = 'Permisos de ubicación denegados';
      notifyListeners();
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
      notifyListeners();
      return false;
    }

    // Verificar permisos
    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _locationMessage = 'Permisos de ubicación denegados';
        notifyListeners();
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      _locationMessage = 'Permisos de ubicación denegados permanentemente';
      notifyListeners();
      return false;
    }

    return true;
  }

  /// Obtiene la ubicación actual del conductor
  Future<void> _getCurrentLocation() async {
    try {
      _locationMessage = 'Obteniendo ubicación GPS...';
      notifyListeners();

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      _currentPosition = position;
      _isLoadingLocation = false;
      _locationMessage = 'Ubicación obtenida';
      notifyListeners();

      print(
        '📍 Ubicación obtenida: ${position.latitude}, ${position.longitude}',
      );
    } catch (e) {
      print('❌ Error obteniendo ubicación: $e');
      _isLoadingLocation = false;
      _locationMessage = 'Error obteniendo ubicación: ${e.toString()}';
      notifyListeners();
    }
  }

  // ==================== VEHÍCULOS ====================

  /// Carga los vehículos disponibles del conductor
  Future<void> cargarVehiculos() async {
    try {
      final vehiculos = await _conductorService.getVehiculosConductor();
      _vehiculosDisponibles = vehiculos;
      notifyListeners();
    } catch (e) {
      print('❌ Error cargando vehículos: $e');
    }
  }

  /// Selecciona un vehículo
  void seleccionarVehiculo(VehiculoConductor vehiculo) {
    _vehiculoSeleccionado = vehiculo;
    notifyListeners();
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

        notifyListeners();
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

      notifyListeners();
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

      notifyListeners();
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
}
