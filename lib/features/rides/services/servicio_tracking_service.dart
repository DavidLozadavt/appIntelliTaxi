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

  /// Iniciar seguimiento del conductor durante servicio
  Future<void> iniciarSeguimiento({
    required int servicioId,
    required int conductorId,
  }) async {
    _servicioId = servicioId;
    _conductorId = conductorId;
    _isTracking = true;

    print('✅ Iniciando seguimiento para servicio $_servicioId');

    // Actualizar ubicación cada 5 segundos
    _locationTimer?.cancel();
    _locationTimer = Timer.periodic(
      const Duration(seconds: 5),
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
    print('🛑 Seguimiento detenido');
  }

  /// Enviar ubicación actual al backend
  Future<void> _enviarUbicacion() async {
    if (!_isTracking || _servicioId == null || _conductorId == null) return;

    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

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

      print(
        '📍 Ubicación enviada: ${position.latitude}, ${position.longitude}',
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
