import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intellitaxi/features/rides/services/servicio_pusher_service.dart';
import 'package:intellitaxi/features/rides/services/routes_service.dart';
import 'package:intellitaxi/core/dio_client.dart';

/// 🎯 Provider que maneja toda la lógica del servicio activo del pasajero
class PasajeroServicioActivoProvider extends ChangeNotifier {
  // ===== SERVICIOS =====
  final ServicioPusherService _pusherService = ServicioPusherService();
  final RoutesService _routesService = RoutesService();

  // ===== DATOS DEL SERVICIO =====
  final int servicioId;
  final Map<String, dynamic> datosServicio;

  // ===== ESTADO =====
  Map<String, dynamic>? _conductor;
  LatLng? _conductorUbicacion;
  String _estadoServicio = 'buscando';
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  BitmapDescriptor? _carIcon;

  // ===== TIMERS =====
  Timer? _timeoutTimer;
  Timer? _countdownTimer;
  static const int _maxWaitingSeconds = 120;
  int _elapsedSeconds = 0;

  // ===== GETTERS =====
  Map<String, dynamic>? get conductor => _conductor;
  LatLng? get conductorUbicacion => _conductorUbicacion;
  String get estadoServicio => _estadoServicio;
  Set<Marker> get markers => _markers;
  Set<Polyline> get polylines => _polylines;
  int get elapsedSeconds => _elapsedSeconds;
  int get remainingSeconds => _maxWaitingSeconds - _elapsedSeconds;
  bool get isBuscando => _estadoServicio == 'buscando';

  PasajeroServicioActivoProvider({
    required this.servicioId,
    required this.datosServicio,
  }) {
    _inicializar();
  }

  /// 🚀 Inicializa el provider
  Future<void> _inicializar() async {
    print('\n${'=' * 80}');
    print('🚀 PROVIDER: Iniciando PasajeroServicioActivoProvider');
    print('=' * 80);
    print('   Servicio ID: $servicioId');
    print('   Canal Pusher: servicio.$servicioId');
    print('=' * 80 + '\n');

    await _cargarIconoCarro();
    _crearMarcadores();
    _suscribirEventos();
    _iniciarTimeout();

    // Verificar estado después de 3 segundos
    Future.delayed(const Duration(seconds: 3), _verificarEstadoServicio);
  }

  /// 🎨 Carga el ícono del carro
  Future<void> _cargarIconoCarro() async {
    try {
      _carIcon = await BitmapDescriptor.asset(
        const ImageConfiguration(size: Size(48, 48)),
        'assets/images/marker.png',
      );
      print('✅ PROVIDER: Ícono del carro cargado');
    } catch (e) {
      print('⚠️ Error cargando ícono del carro: $e');
    }
  }

  /// 🗺️ Crea los marcadores iniciales (origen y destino)
  void _crearMarcadores() {
    print('🗺️ PROVIDER: Creando marcadores iniciales...');
    print('   Origen lat: ${datosServicio['origen_lat']}');
    print('   Origen lng: ${datosServicio['origen_lng']}');
    print('   Destino lat: ${datosServicio['destino_lat']}');
    print('   Destino lng: ${datosServicio['destino_lng']}');

    final origenLat = _parseDouble(datosServicio['origen_lat']);
    final origenLng = _parseDouble(datosServicio['origen_lng']);
    final destinoLat = _parseDouble(datosServicio['destino_lat']);
    final destinoLng = _parseDouble(datosServicio['destino_lng']);

    // Validar que las coordenadas sean válidas
    if (origenLat == 0.0 || origenLng == 0.0) {
      print(
        '⚠️ PROVIDER: Coordenadas de origen inválidas, usando valores por defecto',
      );
    }
    if (destinoLat == 0.0 || destinoLng == 0.0) {
      print('⚠️ PROVIDER: Coordenadas de destino inválidas');
    }

    _markers = {
      // Marcador origen
      Marker(
        markerId: const MarkerId('origen'),
        position: LatLng(
          origenLat != 0.0 ? origenLat : -12.0464,
          origenLng != 0.0 ? origenLng : -77.0428,
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        infoWindow: InfoWindow(
          title: 'Punto de Recogida',
          snippet: datosServicio['origen_address'],
        ),
      ),
      // Marcador destino
      if (destinoLat != 0.0 && destinoLng != 0.0)
        Marker(
          markerId: const MarkerId('destino'),
          position: LatLng(destinoLat, destinoLng),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: InfoWindow(
            title: 'Destino',
            snippet: datosServicio['destino_address'],
          ),
        ),
    };

    print('✅ PROVIDER: Marcadores creados: ${_markers.length} marcadores');
    notifyListeners();
  }

  /// ⏱️ Inicia el temporizador de timeout
  void _iniciarTimeout() {
    _elapsedSeconds = 0;

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_estadoServicio == 'buscando') {
        _elapsedSeconds++;
        notifyListeners();
      } else {
        timer.cancel();
      }
    });

    _timeoutTimer = Timer(Duration(seconds: _maxWaitingSeconds), () {
      if (_estadoServicio == 'buscando') {
        print(
          '⏰ TIMEOUT: No se encontró conductor en $_maxWaitingSeconds segundos',
        );
        // La UI escuchará este cambio y mostrará el diálogo
        _estadoServicio = 'timeout';
        notifyListeners();
      }
    });

    print('⏱️ Timer de timeout iniciado ($_maxWaitingSeconds segundos)');
  }

  /// 🚫 Cancela los timers de timeout
  void _cancelarTimeout() {
    _timeoutTimer?.cancel();
    _countdownTimer?.cancel();
    _timeoutTimer = null;
    _countdownTimer = null;
    print('✅ Timers de timeout cancelados');
  }

  /// 🔌 Suscribe a eventos de Pusher
  Future<void> _suscribirEventos() async {
    print('🔌 PROVIDER: Suscribiendo a eventos Pusher...');

    _pusherService.suscribirServicio(
      servicioId: servicioId,
      onServicioAceptado: (data) {
        print('🎉 Servicio aceptado - Data: ${data.keys}');
        _cancelarTimeout();

        _conductor = data;
        if (data['conductor_lat'] != null && data['conductor_lng'] != null) {
          _conductorUbicacion = LatLng(
            _parseDouble(data['conductor_lat']),
            _parseDouble(data['conductor_lng']),
          );
        }
        _estadoServicio = 'aceptado';
        _actualizarMarcadores();
        notifyListeners();
      },
      onUbicacionActualizada: (data) {
        print('📍 Ubicación actualizada: $data');
        final lat = data['conductor_lat'] ?? data['lat'];
        final lng = data['conductor_lng'] ?? data['lng'];

        if (lat != null && lng != null) {
          _conductorUbicacion = LatLng(_parseDouble(lat), _parseDouble(lng));

          if (_estadoServicio == 'buscando') {
            print('✅ PROVIDER: Conductor ubicado, cambiando estado a aceptado');
            _estadoServicio = 'aceptado';
            if (_conductor == null) {
              _obtenerInfoServicio();
            }
          }
          _actualizarMarcadores();
          notifyListeners();
        }
      },
      onEstadoCambiado: (data) {
        print('🔄 Estado cambiado: ${data['estado']}');
        _estadoServicio = data['estado'] as String;
        _dibujarRuta();
        notifyListeners();
      },
    );
  }

  /// 🔍 Verifica el estado del servicio en la API
  Future<void> _verificarEstadoServicio() async {
    if (_conductor == null && _estadoServicio == 'buscando') {
      print('⚠️ PROVIDER: No se recibió evento, consultando API...');
      await _obtenerInfoServicio();
    }
  }

  /// 📡 Obtiene información del servicio desde la API
  Future<void> _obtenerInfoServicio() async {
    try {
      final dio = DioClient.getInstance();
      print('🔍 PROVIDER: Consultando servicio en /servicios/$servicioId');

      final response = await dio.get('/servicios/taxi/$servicioId');

      if (response.statusCode == 200) {
        final data = response.data;
        final servicio =
            data is Map<String, dynamic> && data.containsKey('servicio')
            ? data['servicio'] as Map<String, dynamic>
            : data as Map<String, dynamic>;

        if (servicio['conductor_id'] != null && servicio['conductor'] != null) {
          print('✅ PROVIDER: Info del servicio obtenida desde API');
          final conductor = servicio['conductor'] as Map<String, dynamic>;
          final vehiculo = conductor['vehiculo'] as Map<String, dynamic>?;

          final calificacion = conductor['calificacion_promedio'];
          final calificacionDouble = calificacion is String
              ? double.tryParse(calificacion) ?? 5.0
              : (calificacion as num?)?.toDouble() ?? 5.0;

          _conductor = {
            'conductor_id': conductor['id'] ?? conductor['conductor_id'],
            'conductor_nombre': conductor['nombre'] ?? 'Conductor',
            'conductor_telefono': conductor['telefono'] ?? '',
            'conductor_foto': conductor['foto_perfil'],
            'vehiculo_placa': vehiculo?['placa'] ?? '',
            'vehiculo_marca': vehiculo?['marca'] ?? '',
            'vehiculo_modelo': vehiculo?['modelo'] ?? '',
            'vehiculo_color': vehiculo?['color'] ?? '',
            'conductor_calificacion': calificacionDouble,
          };
          _estadoServicio = 'aceptado';

          if (servicio['conductor_lat'] != null &&
              servicio['conductor_lng'] != null) {
            _conductorUbicacion = LatLng(
              _parseDouble(servicio['conductor_lat']),
              _parseDouble(servicio['conductor_lng']),
            );
            _actualizarMarcadores();
          }

          notifyListeners();
        }
      }
    } catch (e) {
      print('❌ Error obteniendo info del servicio: $e');
    }
  }

  /// 🗺️ Actualiza los marcadores en el mapa
  void _actualizarMarcadores() {
    if (_conductorUbicacion == null) return;

    print('🗺️ PROVIDER: Actualizando marcadores');

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
    final origenLat = _parseDouble(datosServicio['origen_lat']);
    final origenLng = _parseDouble(datosServicio['origen_lng']);
    final destinoLat = _parseDouble(datosServicio['destino_lat']);
    final destinoLng = _parseDouble(datosServicio['destino_lng']);

    try {
      _polylines.clear();

      // Ruta conductor → origen (solo si está yendo a recoger)
      if (_conductorUbicacion != null &&
          (_estadoServicio == 'aceptado' || _estadoServicio == 'en_camino')) {
        final rutaConductorOrigen = await _routesService.getRoute(
          origin: _conductorUbicacion!,
          destination: LatLng(origenLat, origenLng),
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
        origin: LatLng(origenLat, origenLng),
        destination: LatLng(destinoLat, destinoLng),
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
      print('✅ PROVIDER: Polylines dibujadas');
    } catch (e) {
      print('❌ Error dibujando rutas: $e');
    }
  }

  /// 📏 Calcula los límites del mapa para centrar
  LatLngBounds calcularBounds() {
    final origenLat = _parseDouble(datosServicio['origen_lat']);
    final origenLng = _parseDouble(datosServicio['origen_lng']);

    final lats = [_conductorUbicacion?.latitude ?? origenLat, origenLat];
    final lngs = [_conductorUbicacion?.longitude ?? origenLng, origenLng];

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

  /// 🚫 Cancela el servicio
  Future<void> cancelarServicio({required String motivo}) async {
    try {
      final dio = DioClient.getInstance();
      await dio.post(
        '/servicios/taxi/$servicioId/cancelar',
        data: {'motivo': motivo},
      );
      print('✅ PROVIDER: Servicio cancelado');
    } catch (e) {
      print('❌ Error cancelando servicio: $e');
      rethrow;
    }
  }

  /// 🔧 Helper para parsear doubles
  double _parseDouble(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  /// 🧹 Limpieza de recursos
  @override
  void dispose() {
    _cancelarTimeout();
    _pusherService.desconectar();
    super.dispose();
  }
}
