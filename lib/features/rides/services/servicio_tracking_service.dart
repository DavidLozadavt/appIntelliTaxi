import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:dio/dio.dart';
import 'package:intellitaxi/core/dio_client.dart';

/// Servicio para rastrear la ubicación del conductor durante un servicio activo
class ServicioTrackingService {
  final Dio _dio = DioClient.getInstance();

  Timer? _locationTimer;
  int? _servicioId;
  int? _conductorId;
  bool _isTracking = false;
  Position? _lastPosition;

  // Configuración de intervalos (en segundos)
  static const int _intervaloActualizacion = 12; // Cada 12 segundos
  static const double _distanciaMinima = 10.0; // 10 metros mínimo

  /// Iniciar seguimiento del conductor durante servicio
  Future<void> iniciarSeguimiento({
    required int servicioId,
    required int conductorId,
  }) async {
    _servicioId = servicioId;
    _conductorId = conductorId;
    _isTracking = true;

    print('✅ Iniciando seguimiento para servicio $_servicioId');

    // Actualizar ubicación cada 12 segundos (más eficiente)
    _locationTimer?.cancel();
    _locationTimer = Timer.periodic(
      const Duration(seconds: _intervaloActualizacion),
      (_) => _enviarUbicacion(),
    );

    // Enviar ubicación inmediatamente
    await _enviarUbicacion();
  }

  /// Detener seguimiento
  void detenerSeguimiento() {
    _locationTimer?.cancel();
    _isTracking = false;
    _servicioId = null;
    _conductorId = null;
    _lastPosition = null;
    print('🛑 Seguimiento detenido');
  }

  /// Enviar ubicación actual al backend
  Future<void> _enviarUbicacion() async {
    if (!_isTracking || _servicioId == null || _conductorId == null) return;

    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // Optimización: Solo enviar si se movió al menos 10 metros
      if (_lastPosition != null) {
        final distancia = Geolocator.distanceBetween(
          _lastPosition!.latitude,
          _lastPosition!.longitude,
          position.latitude,
          position.longitude,
        );

        // Si no se ha movido lo suficiente y la velocidad es baja, no enviar
        if (distancia < _distanciaMinima && position.speed < 1.0) {
          print('⏭️ Ubicación sin cambios significativos, omitiendo envío');
          return;
        }
      }

      await _dio.post(
        'servicios/actualizar-ubicacion',
        data: {
          'servicio_id': _servicioId,
          'conductor_id': _conductorId,
          'lat': position.latitude,
          'lng': position.longitude,
          'velocidad': position.speed,
          'direccion': position.heading,
        },
      );

      _lastPosition = position;
      print(
        '📍 Ubicación enviada: ${position.latitude}, ${position.longitude} | Velocidad: ${position.speed.toStringAsFixed(1)} m/s',
      );
    } catch (e) {
      print('⚠️ Error enviando ubicación: $e');
    }
  }

  /// Cambiar estado del servicio
  Future<bool> cambiarEstado({
    required int servicioId,
    required int conductorId,
    required String estado,
  }) async {
    try {
      await _dio.post(
        'servicios/cambiar-estado',
        data: {
          'servicio_id': servicioId,
          'conductor_id': conductorId,
          'estado': estado,
        },
      );

      print('✅ Estado cambiado a: $estado');
      return true;
    } catch (e) {
      print('❌ Error cambiando estado: $e');
      return false;
    }
  }

  /// Cambiar estado del servicio (método estático)
  static Future<bool> cambiarEstadoStatic({
    required int servicioId,
    required int conductorId,
    required String estado,
  }) async {
    try {
      final dio = DioClient.getInstance();
      await dio.post(
        'servicios/cambiar-estado',
        data: {
          'servicio_id': servicioId,
          'conductor_id': conductorId,
          'estado': estado,
        },
      );

      print('✅ Estado cambiado a: $estado');
      return true;
    } catch (e) {
      print('❌ Error cambiando estado: $e');
      return false;
    }
  }

  /// Verificar si hay seguimiento activo
  bool get isTracking => _isTracking;

  /// Obtener ID del servicio actual
  int? get servicioIdActual => _servicioId;

  /// Limpiar recursos
  void dispose() {
    detenerSeguimiento();
  }
}
