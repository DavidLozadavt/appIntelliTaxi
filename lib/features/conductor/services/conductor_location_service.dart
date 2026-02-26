import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intellitaxi/core/dio_client.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intellitaxi/core/services/app_logger.dart';

/// Estados posibles del conductor
enum EstadoConductor { disponible, ocupado, desconectado }

/// Servicio para enviar la ubicación del conductor en tiempo real
class ConductorLocationService {
  final Dio _dio = DioClient.getInstance();
  static const double _minDistanceMeters = 20;
  static const Duration _minSendInterval = Duration(seconds: 5);
  final _LocationMetrics _metrics = _LocationMetrics();
  Timer? _locationTimer;
  bool _isActive = false;
  Position? _lastPosition;
  Position? _lastSentPosition;
  DateTime? _lastSentAt;
  EstadoConductor _estado = EstadoConductor.disponible;
  int? _conductorId;

  /// Indica si el servicio está activo
  bool get isActive => _isActive;

  /// Última posición registrada
  Position? get lastPosition => _lastPosition;

  /// Estado actual del conductor
  EstadoConductor get estado => _estado;

  /// Inicia el envío periódico de ubicación
  /// [intervalSeconds] - Intervalo en segundos entre cada envío (default: 10)
  Future<void> startSendingLocation({int intervalSeconds = 10}) async {
    if (_isActive) {
      AppLogger.d('⚠️ El servicio de ubicación ya está activo');
      return;
    }

    // Obtener conductor_id de SharedPreferences
    await _loadConductorId();

    if (_conductorId == null) {
      AppLogger.d('❌ No se pudo obtener conductor_id');
      return;
    }

    _isActive = true;
    _estado = EstadoConductor.disponible;

    // Enviar ubicación inmediatamente al iniciar
    await _sendCurrentLocation(force: true);

    // Configurar timer para envío periódico
    _locationTimer = Timer.periodic(Duration(seconds: intervalSeconds), (
      _,
    ) async {
      await _sendCurrentLocation();
    });

    AppLogger.d(
      '✅ Servicio de ubicación iniciado (cada $intervalSeconds segundos)',
    );
    AppLogger.d('   Conductor ID: $_conductorId');
    AppLogger.d('   Estado: disponible');
  }

  /// Carga el conductor_id desde SharedPreferences
  Future<void> _loadConductorId() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Intentar obtener directamente
      _conductorId = prefs.getInt('conductor_id');

      if (_conductorId == null) {
        // Intentar desde user_data JSON
        final userDataStr = prefs.getString('user_data');
        if (userDataStr != null && userDataStr.isNotEmpty) {
          try {
            final userData = jsonDecode(userDataStr);
            _conductorId = userData['user']?['id'] ?? userData['id'];
          } catch (e) {
            AppLogger.d('⚠️ Error parseando user_data: $e');
          }
        }
      }

      _conductorId ??= prefs.getInt('user_id');

      if (_conductorId != null) {
        AppLogger.d('✅ Conductor ID cargado: $_conductorId');
      } else {
        AppLogger.d('⚠️ No se pudo obtener conductor_id');
      }
    } catch (e) {
      AppLogger.d('❌ Error cargando conductor_id: $e');
    }
  }

  /// Envía la ubicación actual al backend
  Future<bool> _sendCurrentLocation({bool force = false}) async {
    try {
      if (_conductorId == null) {
        AppLogger.d('⚠️ No hay conductor_id, no se puede enviar ubicación');
        return false;
      }

      // Obtener ubicación actual con alta precisión
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );

      _lastPosition = position;

      if (!force && _shouldSkipLocationUpdate(position)) {
        _metrics.skippedByThrottle++;
        _metrics.logIfNeeded();
        return true;
      }

      // Convertir estado a string
      final estadoString = _estado == EstadoConductor.disponible
          ? 'disponible'
          : _estado == EstadoConductor.ocupado
          ? 'ocupado'
          : 'desconectado';

      AppLogger.d('📍 Enviando ubicación...');
      AppLogger.d('   Conductor ID: $_conductorId');
      AppLogger.d('   Lat: ${position.latitude}');
      AppLogger.d('   Lng: ${position.longitude}');
      AppLogger.d('   Estado: $estadoString');

      final response = await _dio.post(
        'conductor/estado-disponible',
        data: {
          'conductor_id': _conductorId,
          'lat': position.latitude,
          'lng': position.longitude,
          'estado': estadoString,
        },
      );

      if (response.statusCode == 200) {
        final data = response.data;
        if (data['success'] == true) {
          _metrics.sentToServer++;
          _metrics.logIfNeeded();
          _lastSentAt = DateTime.now();
          _lastSentPosition = position;
          AppLogger.d('✅ Ubicación enviada exitosamente');
          return true;
        } else {
          AppLogger.d(
            '⚠️ Respuesta del servidor: ${data['message'] ?? "Sin mensaje"}',
          );
          return false;
        }
      } else {
        AppLogger.d(
          '⚠️ Código de respuesta inesperado: ${response.statusCode}',
        );
        return false;
      }
    } on DioException catch (e) {
      AppLogger.d('❌ Error DioException enviando ubicación:');
      AppLogger.d('   ${e.message}');
      if (e.response != null) {
        AppLogger.d('   Status: ${e.response?.statusCode}');
        AppLogger.d('   Data: ${e.response?.data}');
      }
      return false;
    } catch (e) {
      AppLogger.d('❌ Error obteniendo/enviando ubicación: $e');
      return false;
    }
  }

  /// Cambia el estado del conductor
  void cambiarEstado(EstadoConductor nuevoEstado) {
    if (_estado != nuevoEstado) {
      _estado = nuevoEstado;
      AppLogger.d('🔄 Estado cambiado a: $nuevoEstado');

      // Enviar actualización inmediata
      if (_isActive) {
        _sendCurrentLocation(force: true);
      }
    }
  }

  /// Marca al conductor como disponible
  void marcarDisponible() => cambiarEstado(EstadoConductor.disponible);

  /// Marca al conductor como ocupado
  void marcarOcupado() => cambiarEstado(EstadoConductor.ocupado);

  /// Envía la ubicación manualmente (sin timer)
  Future<bool> sendLocationNow() async {
    if (!_isActive) {
      AppLogger.d('⚠️ El servicio no está activo. Enviando ubicación única...');
    }
    return await _sendCurrentLocation(force: true);
  }

  /// Detiene el envío periódico de ubicación y notifica desconexión
  Future<void> stopSendingLocation() async {
    if (!_isActive) {
      AppLogger.d('⚠️ El servicio de ubicación ya está detenido');
      return;
    }

    // Cambiar estado a desconectado y enviar última actualización
    _estado = EstadoConductor.desconectado;
    await _sendCurrentLocation(force: true);

    _locationTimer?.cancel();
    _locationTimer = null;
    _isActive = false;

    AppLogger.d('🛑 Servicio de ubicación detenido');
    AppLogger.d('   Estado: desconectado');
  }

  /// Actualiza el intervalo de envío (reinicia el timer)
  Future<void> updateInterval(int intervalSeconds) async {
    if (!_isActive) {
      AppLogger.d('⚠️ El servicio no está activo');
      return;
    }

    await stopSendingLocation();
    await startSendingLocation(intervalSeconds: intervalSeconds);
    AppLogger.d('🔄 Intervalo actualizado a $intervalSeconds segundos');
  }

  /// Limpia recursos
  Future<void> dispose() async {
    await stopSendingLocation();
  }

  bool _shouldSkipLocationUpdate(Position position) {
    final now = DateTime.now();
    final lastSentAt = _lastSentAt;
    final lastSentPosition = _lastSentPosition;

    if (lastSentAt == null || lastSentPosition == null) {
      return false;
    }

    final elapsed = now.difference(lastSentAt);
    if (elapsed >= _minSendInterval) {
      return false;
    }

    final movedMeters = Geolocator.distanceBetween(
      lastSentPosition.latitude,
      lastSentPosition.longitude,
      position.latitude,
      position.longitude,
    );

    final shouldSkip = movedMeters < _minDistanceMeters;
    if (shouldSkip) {
      AppLogger.d(
        '⏭️ Ubicación omitida para ahorrar red (distancia ${movedMeters.toStringAsFixed(1)}m, intervalo ${elapsed.inSeconds}s)',
      );
    }
    return shouldSkip;
  }
}

class _LocationMetrics {
  int sentToServer = 0;
  int skippedByThrottle = 0;
  int _lastLoggedTotal = 0;

  void logIfNeeded() {
    final total = sentToServer + skippedByThrottle;
    if (total - _lastLoggedTotal < 10) return;
    _lastLoggedTotal = total;
    AppLogger.i(
      '📊 ConductorLocation ahorro | enviados=$sentToServer omitidos=$skippedByThrottle ahorro=${skipRate.toStringAsFixed(1)}%',
      tag: 'MapsMetrics',
    );
  }

  double get skipRate {
    final denominator = sentToServer + skippedByThrottle;
    if (denominator == 0) return 0;
    return (skippedByThrottle / denominator) * 100;
  }
}
