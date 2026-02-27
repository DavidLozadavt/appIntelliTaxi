import 'package:dio/dio.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intellitaxi/core/dio_client.dart';
import 'package:intellitaxi/core/services/app_logger.dart';

/// Servicio para gestionar los turnos del conductor
class TurnoService {
  final Dio _dio = DioClient.getInstance();

  /// Inicia un turno con la ubicación actual
  Future<TurnoResponse?> iniciarTurno({
    required int idVehiculo,
    required double lat,
    required double lng,
  }) async {
    try {
      AppLogger.d('🚀 Iniciando turno...');
      AppLogger.d('   🚗 Vehículo ID: $idVehiculo');
      AppLogger.d('   📍 Ubicación: ($lat, $lng)');
      AppLogger.d('   🌐 URL: ${_dio.options.baseUrl}turnos');
      AppLogger.d('   🔑 Headers: ${_dio.options.headers}');

      final requestData = {'idVehiculo': idVehiculo, 'lat': lat, 'lng': lng};
      AppLogger.d('   📤 Request Data: $requestData');

      final response = await _dio.post('turnos', data: requestData);

      AppLogger.d('   📥 Response Status: ${response.statusCode}');
      AppLogger.d('   📥 Response Data: ${response.data}');

      // Manejar redirección 302
      if (response.statusCode == 302 || response.statusCode == 301) {
        AppLogger.d('⚠️ Servidor está redirigiendo (302/301)');
        AppLogger.d('   Location: ${response.headers['location']}');
        AppLogger.d('   Esto puede indicar:');
        AppLogger.d('   - Usuario no autenticado correctamente');
        AppLogger.d('   - Usuario no tiene permisos de conductor');
        AppLogger.d('   - Endpoint requiere middleware específico');
        return null;
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = response.data;

        if (data['success'] == true || data['turno'] != null) {
          AppLogger.d('✅ Turno iniciado exitosamente');
          AppLogger.d('   ID Turno: ${data['turno']?['id']}');

          return TurnoResponse.fromJson(data);
        } else {
          AppLogger.d(
            '⚠️ Respuesta inesperada: ${data['message'] ?? "Sin mensaje"}',
          );
          return null;
        }
      }

      AppLogger.d('⚠️ Error al iniciar turno: Status ${response.statusCode}');
      return null;
    } on DioException catch (e) {
      AppLogger.d('❌ Error DioException iniciando turno:');
      AppLogger.d('   Tipo: ${e.type}');
      AppLogger.d('   Mensaje: ${e.message}');
      AppLogger.d('   🔗 Request URL: ${e.requestOptions.uri}');
      AppLogger.d('   🔗 Request Method: ${e.requestOptions.method}');
      AppLogger.d('   📤 Request Data: ${e.requestOptions.data}');
      AppLogger.d('   🔑 Request Headers: ${e.requestOptions.headers}');

      if (e.response != null) {
        AppLogger.d('   📥 Response Status: ${e.response?.statusCode}');
        AppLogger.d('   📥 Response Data: ${e.response?.data}');
        AppLogger.d('   📥 Response Headers: ${e.response?.headers}');

        // Verificar si es redirección
        if (e.response?.statusCode == 302 || e.response?.statusCode == 301) {
          AppLogger.d('   🔄 Redirección detectada');
          final location = e.response?.headers['location'];
          if (location != null) {
            AppLogger.d('   🔄 Redirigiendo a: $location');
          }
        }

        if (e.response?.data is Map) {
          final errorData = e.response?.data as Map;
          if (errorData['message'] != null) {
            AppLogger.d('   💬 Mensaje: ${errorData['message']}');
          }
          if (errorData['error'] != null) {
            AppLogger.d('   ⚠️ Error: ${errorData['error']}');
          }
        }
      } else {
        AppLogger.d(
          '   ⚠️ No hay respuesta del servidor (posible problema de red)',
        );
      }
      return null;
    } catch (e) {
      AppLogger.d('❌ Error iniciando turno: $e');
      return null;
    }
  }

  /// Finaliza el turno actual
  Future<bool> finalizarTurno(int idTurno) async {
    try {
      AppLogger.d('🛑 Finalizando turno $idTurno...');

      final response = await _dio.put(
        'turnos/$idTurno',
        data: {'estado': 'FINALIZADO'},
      );

      if (response.statusCode == 200) {
        final data = response.data;

        if (data['success'] == true) {
          AppLogger.d('✅ Turno finalizado exitosamente');
          return true;
        }
      }

      AppLogger.d('⚠️ Error al finalizar turno');
      return false;
    } on DioException catch (e) {
      AppLogger.d('❌ Error DioException finalizando turno:');
      AppLogger.d('   ${e.message}');
      if (e.response != null) {
        AppLogger.d('   Status: ${e.response?.statusCode}');
        AppLogger.d('   Data: ${e.response?.data}');
      }
      return false;
    } catch (e) {
      AppLogger.d('❌ Error finalizando turno: $e');
      return false;
    }
  }

  /// Obtiene el turno activo del conductor
  Future<TurnoResponse?> getTurnoActivo() async {
    try {
      final response = await _dio.get('turnos/activo');

      if (response.statusCode == 200) {
        final data = response.data;

        if (data['success'] == true && data['turno'] != null) {
          return TurnoResponse.fromJson(data);
        }
      }

      return null;
    } catch (e) {
      AppLogger.d('Error obteniendo turno activo: $e');
      return null;
    }
  }

  /// Inicia turno con ubicación GPS automática
  Future<TurnoResponse?> iniciarTurnoConGPS({required int idVehiculo}) async {
    try {
      AppLogger.d('📍 Obteniendo ubicación GPS...');

      // Obtener ubicación actual
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      AppLogger.d('✅ Ubicación obtenida:');
      AppLogger.d('   Lat: ${position.latitude}');
      AppLogger.d('   Lng: ${position.longitude}');

      return await iniciarTurno(
        idVehiculo: idVehiculo,
        lat: position.latitude,
        lng: position.longitude,
      );
    } catch (e) {
      AppLogger.d('❌ Error obteniendo ubicación GPS: $e');
      AppLogger.d('   Tipo de error: ${e.runtimeType}');

      // Si falla el GPS, no podemos iniciar el turno
      return null;
    }
  }

  /// Verifica si hay un token de autenticación válido
  Future<bool> verificarAutenticacion() async {
    try {
      AppLogger.d('🔍 Verificando autenticación...');

      final response = await _dio.get(
        'auth/me',
      ); // O el endpoint que uses para verificar sesión

      if (response.statusCode == 200) {
        AppLogger.d('✅ Autenticación válida');
        AppLogger.d('   Usuario: ${response.data}');
        return true;
      }

      AppLogger.d('⚠️ Autenticación inválida');
      return false;
    } catch (e) {
      AppLogger.d('❌ Error verificando autenticación: $e');
      return false;
    }
  }
}

/// Modelo de respuesta del turno
class TurnoResponse {
  final bool success;
  final Turno? turno;
  final String? message;

  TurnoResponse({required this.success, this.turno, this.message});

  factory TurnoResponse.fromJson(Map<String, dynamic> json) {
    return TurnoResponse(
      success: json['success'] ?? false,
      turno: json['turno'] != null ? Turno.fromJson(json['turno']) : null,
      message: json['message'],
    );
  }
}

/// Modelo del turno
class Turno {
  final int id;
  final int idVehiculo;
  final String estado;
  final DateTime? horaInicio;
  final DateTime? horaFin;
  final double? latInicio;
  final double? lngInicio;

  Turno({
    required this.id,
    required this.idVehiculo,
    required this.estado,
    this.horaInicio,
    this.horaFin,
    this.latInicio,
    this.lngInicio,
  });

  factory Turno.fromJson(Map<String, dynamic> json) {
    return Turno(
      id: json['id'],
      idVehiculo: json['idVehiculo'] ?? json['id_vehiculo'],
      estado: json['estado'] ?? 'ACTIVO',
      horaInicio: json['hora_inicio'] != null
          ? DateTime.parse(json['hora_inicio'])
          : null,
      horaFin: json['hora_fin'] != null
          ? DateTime.parse(json['hora_fin'])
          : null,
      latInicio: json['lat_inicio']?.toDouble(),
      lngInicio: json['lng_inicio']?.toDouble(),
    );
  }
}
