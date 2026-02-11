import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intellitaxi/core/dio_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Estados posibles del conductor
enum EstadoConductor { disponible, ocupado, desconectado }

/// Servicio para enviar la ubicación del conductor en tiempo real
class ConductorLocationService {
  final Dio _dio = DioClient.getInstance();
  Timer? _locationTimer;
  bool _isActive = false;
  Position? _lastPosition;
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
      print('⚠️ El servicio de ubicación ya está activo');
      return;
    }

    // Obtener conductor_id de SharedPreferences
    await _loadConductorId();

    if (_conductorId == null) {
      print('❌ No se pudo obtener conductor_id');
      return;
    }

    _isActive = true;
    _estado = EstadoConductor.disponible;

    // Enviar ubicación inmediatamente al iniciar
    await _sendCurrentLocation();

    // Configurar timer para envío periódico
    _locationTimer = Timer.periodic(Duration(seconds: intervalSeconds), (
      _,
    ) async {
      await _sendCurrentLocation();
    });

    print('✅ Servicio de ubicación iniciado (cada $intervalSeconds segundos)');
    print('   Conductor ID: $_conductorId');
    print('   Estado: disponible');
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
            print('⚠️ Error parseando user_data: $e');
          }
        }
      }

      _conductorId ??= prefs.getInt('user_id');

      if (_conductorId != null) {
        print('✅ Conductor ID cargado: $_conductorId');
      } else {
        print('⚠️ No se pudo obtener conductor_id');
      }
    } catch (e) {
      print('❌ Error cargando conductor_id: $e');
    }
  }

  /// Envía la ubicación actual al backend
  Future<bool> _sendCurrentLocation() async {
    try {
      if (_conductorId == null) {
        print('⚠️ No hay conductor_id, no se puede enviar ubicación');
        return false;
      }

      // Obtener ubicación actual con alta precisión
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      _lastPosition = position;

      // Convertir estado a string
      final estadoString = _estado == EstadoConductor.disponible
          ? 'disponible'
          : _estado == EstadoConductor.ocupado
          ? 'ocupado'
          : 'desconectado';

      print('📍 Enviando ubicación...');
      print('   Conductor ID: $_conductorId');
      print('   Lat: ${position.latitude}');
      print('   Lng: ${position.longitude}');
      print('   Estado: $estadoString');

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
          print('✅ Ubicación enviada exitosamente');
          return true;
        } else {
          print(
            '⚠️ Respuesta del servidor: ${data['message'] ?? "Sin mensaje"}',
          );
          return false;
        }
      } else {
        print('⚠️ Código de respuesta inesperado: ${response.statusCode}');
        return false;
      }
    } on DioException catch (e) {
      print('❌ Error DioException enviando ubicación:');
      print('   ${e.message}');
      if (e.response != null) {
        print('   Status: ${e.response?.statusCode}');
        print('   Data: ${e.response?.data}');
      }
      return false;
    } catch (e) {
      print('❌ Error obteniendo/enviando ubicación: $e');
      return false;
    }
  }

  /// Cambia el estado del conductor
  void cambiarEstado(EstadoConductor nuevoEstado) {
    if (_estado != nuevoEstado) {
      _estado = nuevoEstado;
      print('🔄 Estado cambiado a: $nuevoEstado');

      // Enviar actualización inmediata
      if (_isActive) {
        _sendCurrentLocation();
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
      print('⚠️ El servicio no está activo. Enviando ubicación única...');
    }
    return await _sendCurrentLocation();
  }

  /// Detiene el envío periódico de ubicación y notifica desconexión
  Future<void> stopSendingLocation() async {
    if (!_isActive) {
      print('⚠️ El servicio de ubicación ya está detenido');
      return;
    }

    // Cambiar estado a desconectado y enviar última actualización
    _estado = EstadoConductor.desconectado;
    await _sendCurrentLocation();

    _locationTimer?.cancel();
    _locationTimer = null;
    _isActive = false;

    print('🛑 Servicio de ubicación detenido');
    print('   Estado: desconectado');
  }

  /// Actualiza el intervalo de envío (reinicia el timer)
  Future<void> updateInterval(int intervalSeconds) async {
    if (!_isActive) {
      print('⚠️ El servicio no está activo');
      return;
    }

    await stopSendingLocation();
    await startSendingLocation(intervalSeconds: intervalSeconds);
    print('🔄 Intervalo actualizado a $intervalSeconds segundos');
  }

  /// Limpia recursos
  Future<void> dispose() async {
    await stopSendingLocation();
  }
}
