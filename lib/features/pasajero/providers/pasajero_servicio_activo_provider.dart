import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intellitaxi/core/services/app_logger.dart';
import 'package:intellitaxi/features/rides/services/servicio_pusher_service.dart';
import 'package:intellitaxi/features/pasajero/services/routes_service.dart';
import 'package:intellitaxi/features/pasajero/services/pasajero_servicio_mapper.dart';
import 'package:intellitaxi/features/pasajero/services/servicio_conductor_location_cache_service.dart';
import 'package:intellitaxi/core/dio_client.dart';

/// 🎯 Provider que maneja toda la lógica del servicio activo del pasajero
class PasajeroServicioActivoProvider extends ChangeNotifier {
  // ===== SERVICIOS =====
  final ServicioPusherService _pusherService = ServicioPusherService();
  final RoutesService _routesService = RoutesService();
  final ServicioConductorLocationCacheService _locationCacheService =
      ServicioConductorLocationCacheService();

  // ===== DATOS DEL SERVICIO =====
  final int servicioId;
  final Map<String, dynamic> datosServicio;

  // ===== ESTADO =====
  Map<String, dynamic>? _conductor;
  LatLng? _conductorUbicacion;
  String _estadoServicio = 'buscando';
  Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  BitmapDescriptor? _carIcon;

  // ===== TIMERS =====
  Timer? _timeoutTimer;
  Timer? _countdownTimer;
  static const int _maxWaitingSeconds = 120;
  int _elapsedSeconds = 0;
  Timer? _refreshTimer;
  bool _isFetchingService = false;
  static final Map<int, LatLng> _lastConductorLocationCache = {};

  // ===== GETTERS =====
  Map<String, dynamic>? get conductor => _conductor;
  LatLng? get conductorUbicacion => _conductorUbicacion;
  String get estadoServicio => _estadoServicio;
  Set<Marker> get markers => _markers;
  Set<Polyline> get polylines => _polylines;
  int get elapsedSeconds => _elapsedSeconds;
  int get remainingSeconds => _maxWaitingSeconds - _elapsedSeconds;
  bool get isBuscando =>
      _estadoServicio == 'buscando' || _estadoServicio == 'pendiente';

  PasajeroServicioActivoProvider({
    required this.servicioId,
    required this.datosServicio,
  }) {
    _estadoServicio = PasajeroServicioMapper.estadoInicial(datosServicio);
    _inicializar();
  }

  /// 🚀 Inicializa el provider
  Future<void> _inicializar() async {
    AppLogger.d('\n${'=' * 80}');
    AppLogger.d('🚀 PROVIDER: Iniciando PasajeroServicioActivoProvider');
    AppLogger.d('=' * 80);
    AppLogger.d('   Servicio ID: $servicioId');
    AppLogger.d('   Canal Pusher: servicio.$servicioId');
    AppLogger.d('=' * 80 + '\n');

    await _cargarIconoCarro();
    _crearMarcadores();
    _hidratarConductorDesdePayloadInicial();
    await _restaurarUbicacionConductorPersistida();
    _suscribirEventos();
    if (_estadoServicio == 'buscando') {
      _iniciarTimeout();
    } else {
      _cancelarTimeout();
      if (_conductor == null) {
        _obtenerInfoServicio();
      }
    }

    // Refresco periódico para no perder ubicación del conductor tras hot reload
    _iniciarRefreshUbicacion();

    // Verificar estado después de 3 segundos
    Future.delayed(const Duration(seconds: 3), _verificarEstadoServicio);
  }

  Future<void> _restaurarUbicacionConductorPersistida() async {
    if (_conductorUbicacion != null) return;
    final cached = await _locationCacheService.read(servicioId);
    if (cached != null) {
      _conductorUbicacion = cached;
      _lastConductorLocationCache[servicioId] = cached;
      _actualizarMarcadores();
    }
  }

  void _setConductorUbicacion(LatLng value) {
    _conductorUbicacion = value;
    _lastConductorLocationCache[servicioId] = value;
    // Persistencia best-effort para sobrevivir reconstrucciones/hot reload.
    _locationCacheService.save(servicioId, value);
  }

  void _hidratarConductorDesdePayloadInicial() {
    _conductor = PasajeroServicioMapper.conductorResumen(datosServicio);
    _conductorUbicacion = PasajeroServicioMapper.conductorUbicacion(
      datosServicio,
    );

    if (_conductorUbicacion != null) {
      _setConductorUbicacion(_conductorUbicacion!);
    } else if (_lastConductorLocationCache.containsKey(servicioId)) {
      _conductorUbicacion = _lastConductorLocationCache[servicioId];
    }

    if (_conductorUbicacion != null) {
      _actualizarMarcadores();
    }
  }

  /// 🎨 Carga el ícono del carro
  Future<void> _cargarIconoCarro() async {
    try {
      _carIcon = await BitmapDescriptor.asset(
        const ImageConfiguration(size: Size(48, 48)),
        'assets/images/marker.png',
      );
      AppLogger.d('✅ PROVIDER: Ícono del carro cargado');
    } catch (e) {
      AppLogger.d('⚠️ Error cargando ícono del carro: $e');
    }
  }

  /// 🗺️ Crea los marcadores iniciales (origen y destino)
  void _crearMarcadores() {
    AppLogger.d('🗺️ PROVIDER: Creando marcadores iniciales...');
    AppLogger.d('   Origen lat: ${datosServicio['origen_lat']}');
    AppLogger.d('   Origen lng: ${datosServicio['origen_lng']}');
    AppLogger.d('   Destino lat: ${datosServicio['destino_lat']}');
    AppLogger.d('   Destino lng: ${datosServicio['destino_lng']}');

    final origen = PasajeroServicioMapper.origen(datosServicio);
    final destino = PasajeroServicioMapper.destino(datosServicio);

    // Validar que las coordenadas sean válidas
    if (origen.latitude == 0.0 || origen.longitude == 0.0) {
      AppLogger.d(
        '⚠️ PROVIDER: Coordenadas de origen inválidas, usando valores por defecto',
      );
    }
    if (destino == null) {
      AppLogger.d('⚠️ PROVIDER: Coordenadas de destino inválidas');
    }

    _markers = {
      // Marcador origen
      Marker(
        markerId: const MarkerId('origen'),
        position: LatLng(
          origen.latitude != 0.0 ? origen.latitude : -12.0464,
          origen.longitude != 0.0 ? origen.longitude : -77.0428,
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        infoWindow: InfoWindow(
          title: 'Punto de Recogida',
          snippet: datosServicio['origen_address'],
        ),
      ),
      // Marcador destino
      if (destino != null)
        Marker(
          markerId: const MarkerId('destino'),
          position: destino,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: InfoWindow(
            title: 'Destino',
            snippet: datosServicio['destino_address'],
          ),
        ),
    };

    AppLogger.d(
      '✅ PROVIDER: Marcadores creados: ${_markers.length} marcadores',
    );
    notifyListeners();
  }

  /// ⏱️ Inicia el temporizador de timeout
  void _iniciarTimeout() {
    _elapsedSeconds = 0;

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (isBuscando) {
        _elapsedSeconds++;
        notifyListeners();
      } else {
        timer.cancel();
      }
    });

    _timeoutTimer = Timer(Duration(seconds: _maxWaitingSeconds), () {
      if (isBuscando) {
        AppLogger.d(
          '⏰ TIMEOUT: No se encontró conductor en $_maxWaitingSeconds segundos',
        );
        // La UI escuchará este cambio y mostrará el diálogo
        _estadoServicio = 'timeout';
        notifyListeners();
      }
    });

    AppLogger.d('⏱️ Timer de timeout iniciado ($_maxWaitingSeconds segundos)');
  }

  /// 🚫 Cancela los timers de timeout
  void _cancelarTimeout() {
    _timeoutTimer?.cancel();
    _countdownTimer?.cancel();
    _timeoutTimer = null;
    _countdownTimer = null;
    AppLogger.d('✅ Timers de timeout cancelados');
  }

  void _iniciarRefreshUbicacion() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      if (_estadoServicio == 'finalizado' || _estadoServicio == 'cancelado') {
        return;
      }
      _obtenerInfoServicio();
    });
  }

  /// 🔌 Suscribe a eventos de Pusher
  Future<void> _suscribirEventos() async {
    AppLogger.d('🔌 PROVIDER: Suscribiendo a eventos Pusher...');

    _pusherService.suscribirServicio(
      servicioId: servicioId,
      onServicioAceptado: (data) {
        AppLogger.d('🎉 Servicio aceptado - Data: ${data.keys}');
        _cancelarTimeout();

        _conductor = data;
        if (data['conductor_lat'] != null && data['conductor_lng'] != null) {
          _setConductorUbicacion(
            LatLng(
              PasajeroServicioMapper.parseDouble(data['conductor_lat']),
              PasajeroServicioMapper.parseDouble(data['conductor_lng']),
            ),
          );
        }
        _estadoServicio = 'aceptado';
        _actualizarMarcadores();
        notifyListeners();
      },
      onUbicacionActualizada: (data) {
        AppLogger.d('📍 Ubicación actualizada: $data');
        final lat = data['conductor_lat'] ?? data['lat'];
        final lng = data['conductor_lng'] ?? data['lng'];

        if (lat != null && lng != null) {
          _setConductorUbicacion(
            LatLng(
              PasajeroServicioMapper.parseDouble(lat),
              PasajeroServicioMapper.parseDouble(lng),
            ),
          );

          if (_conductor == null) {
            _obtenerInfoServicio();
          }
          _actualizarMarcadores();
          notifyListeners();
        }
      },
      onEstadoCambiado: (data) {
        AppLogger.d('🔄 Estado cambiado: ${data['estado']}');
        _estadoServicio = PasajeroServicioMapper.normalizeEstado(
          data['estado'],
        );
        _dibujarRuta();
        notifyListeners();
      },
    );
  }

  /// 🔍 Verifica el estado del servicio en la API
  Future<void> _verificarEstadoServicio() async {
    if (_conductor == null && _estadoServicio == 'buscando') {
      AppLogger.d('⚠️ PROVIDER: No se recibió evento, consultando API...');
      await _obtenerInfoServicio();
    }
  }

  /// 📡 Obtiene información del servicio desde la API
  Future<void> _obtenerInfoServicio() async {
    if (_isFetchingService) return;
    _isFetchingService = true;
    try {
      final dio = DioClient.getInstance();
      AppLogger.d(
        '🔍 PROVIDER: Consultando servicio en /servicios/$servicioId',
      );

      final response = await dio.get('/servicios/taxi/$servicioId');

      if (response.statusCode == 200) {
        final data = response.data;
        final root = data is Map<String, dynamic> ? data : <String, dynamic>{};
        final servicio = root.containsKey('servicio')
            ? root['servicio'] as Map<String, dynamic>
            : root;

        final conductorId =
            servicio['conductor_id'] ??
            servicio['idConductor'] ??
            servicio['conductorId'];
        final conductorData =
            (servicio['conductor'] as Map<String, dynamic>?) ??
            root['conductor'] as Map<String, dynamic>?;
        final vehiculoData =
            (servicio['vehiculo'] as Map<String, dynamic>?) ??
            root['vehiculo'] as Map<String, dynamic>?;

        final estadoObj = servicio['estado'];
        final idEstadoRaw =
            servicio['idEstado'] ??
            servicio['id_estado'] ??
            (estadoObj is Map ? estadoObj['id'] : null);
        final estadoRaw =
            estadoObj is Map
                ? estadoObj['estado']
                : estadoObj ??
                    root['estado']?['estado'] ??
                    root['estado'];
        var estadoNormalizado = PasajeroServicioMapper.normalizeEstado(
          estadoRaw,
        );
        final idEstado = idEstadoRaw is int
            ? idEstadoRaw
            : int.tryParse(idEstadoRaw?.toString() ?? '');
        if (idEstado == 6) {
          estadoNormalizado = 'cancelado';
        } else if (idEstado == 5 ||
            idEstado == 7 ||
            idEstado == 22 ||
            idEstado == 23) {
          estadoNormalizado = 'finalizado';
        }
        _estadoServicio = estadoNormalizado;

        if (conductorId != null && conductorData != null) {
          AppLogger.d('✅ PROVIDER: Info del servicio obtenida desde API');
          _conductor = PasajeroServicioMapper.conductorResumen(
            servicio,
            conductor: conductorData,
            vehiculo: vehiculoData,
          );

          if ((servicio['conductor_lat'] ?? servicio['conductorLat']) != null &&
              (servicio['conductor_lng'] ?? servicio['conductorLng']) != null) {
            _setConductorUbicacion(
              LatLng(
                PasajeroServicioMapper.parseDouble(
                  servicio['conductor_lat'] ?? servicio['conductorLat'],
                ),
                PasajeroServicioMapper.parseDouble(
                  servicio['conductor_lng'] ?? servicio['conductorLng'],
                ),
              ),
            );
            _actualizarMarcadores();
          } else if (_lastConductorLocationCache.containsKey(servicioId)) {
            _conductorUbicacion = _lastConductorLocationCache[servicioId];
            _actualizarMarcadores();
          } else {
            await _restaurarUbicacionConductorPersistida();
          }

          notifyListeners();
        } else {
          // Sin conductor pero el estado pudo pasar a cancelado/finalizado (p. ej. tras cancelar en otro cliente).
          notifyListeners();
        }
      }
    } catch (e) {
      AppLogger.d('❌ Error obteniendo info del servicio: $e');
    } finally {
      _isFetchingService = false;
    }
  }

  /// 🗺️ Actualiza los marcadores en el mapa
  void _actualizarMarcadores() {
    if (_conductorUbicacion == null) return;

    AppLogger.d('🗺️ PROVIDER: Actualizando marcadores');

    _markers.removeWhere((m) => m.markerId.value == 'conductor');
    _markers.add(
      Marker(
        markerId: const MarkerId('conductor'),
        position: _conductorUbicacion!,
        icon:
            _carIcon ??
            BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        infoWindow: InfoWindow(
          title: _conductor?['conductor_nombre'] ?? 'Conductor',
          snippet: '${_conductor?['vehiculo_placa'] ?? ''}',
        ),
        rotation: 0.0,
        anchor: const Offset(0.5, 0.5),
      ),
    );

    _dibujarRuta();
    notifyListeners();
  }

  /// 🛣️ Dibuja la ruta en el mapa
  Future<void> _dibujarRuta() async {
    final origen = PasajeroServicioMapper.origen(datosServicio);
    final destino = PasajeroServicioMapper.destino(datosServicio);
    if (destino == null) return;

    try {
      _polylines.clear();

      // Ruta conductor → origen (solo si está yendo a recoger)
      if (_conductorUbicacion != null &&
          (_estadoServicio == 'aceptado' || _estadoServicio == 'en_camino')) {
        final rutaConductorOrigen = await _routesService.getRoute(
          origin: _conductorUbicacion!,
          destination: origen,
        );

        if (rutaConductorOrigen != null) {
          _polylines.add(
            Polyline(
              polylineId: const PolylineId('conductor_origen'),
              points: rutaConductorOrigen.polylinePoints,
              color: Colors.blue,
              width: 4,
            ),
          );
        }
      }

      // Ruta origen → destino
      final rutaOrigenDestino = await _routesService.getRoute(
        origin: origen,
        destination: destino,
      );

      if (rutaOrigenDestino != null) {
        _polylines.add(
          Polyline(
            polylineId: const PolylineId('origen_destino'),
            points: rutaOrigenDestino.polylinePoints,
            color: Colors.orange,
            width: 3,
            patterns: [PatternItem.dash(15), PatternItem.gap(10)],
          ),
        );
      }

      notifyListeners();
      AppLogger.d('✅ PROVIDER: Polylines dibujadas');
    } catch (e) {
      AppLogger.d('❌ Error dibujando rutas: $e');
    }
  }

  /// 📏 Calcula los límites del mapa para centrar
  LatLngBounds calcularBounds() {
    final origen = PasajeroServicioMapper.origen(datosServicio);

    final lats = [
      _conductorUbicacion?.latitude ?? origen.latitude,
      origen.latitude,
    ];
    final lngs = [
      _conductorUbicacion?.longitude ?? origen.longitude,
      origen.longitude,
    ];

    return LatLngBounds(
      southwest: LatLng(
        lats.reduce((a, b) => a < b ? a : b),
        lngs.reduce((a, b) => a < b ? a : b),
      ),
      northeast: LatLng(
        lats.reduce((a, b) => a > b ? a : b),
        lngs.reduce((a, b) => a > b ? a : b),
      ),
    );
  }

  /// 🔄 Reinicia la búsqueda de conductor
  void reintentar() {
    _estadoServicio = 'buscando';
    _iniciarTimeout();
    notifyListeners();
  }

  /// 🚫 Cancela el servicio. Devuelve `true` si el servidor confirmó; si falla la red o el API (p. ej. 500), devuelve `false` sin lanzar para que la UI pueda volver al inicio de forma segura.
  Future<bool> cancelarServicio({required String motivo}) async {
    try {
      final dio = DioClient.getInstance();
      await dio.post(
        'taxi/servicio/cancelar',
        data: {'servicio_id': servicioId, 'motivo': motivo},
      );
      AppLogger.d('✅ PROVIDER: Servicio cancelado');
      // Evita que el refresh/Pusher sigan en "buscando" y disparen otra salida mientras la UI navega.
      _cancelarTimeout();
      _refreshTimer?.cancel();
      _refreshTimer = null;
      _estadoServicio = 'cancelado';
      notifyListeners();
      return true;
    } catch (e) {
      AppLogger.d('❌ Error cancelando servicio: $e');
      return false;
    }
  }

  /// 🧹 Limpieza de recursos
  @override
  void dispose() {
    _cancelarTimeout();
    _refreshTimer?.cancel();
    if (_estadoServicio == 'finalizado' || _estadoServicio == 'cancelado') {
      _locationCacheService.clear(servicioId);
      _lastConductorLocationCache.remove(servicioId);
    }
    _pusherService.desconectar();
    super.dispose();
  }
}
