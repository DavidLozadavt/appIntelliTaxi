import 'package:dio/dio.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intellitaxi/core/dio_client.dart';

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
      print('🚀 Iniciando turno...');
      print('   🚗 Vehículo ID: $idVehiculo');
      print('   📍 Ubicación: ($lat, $lng)');
      print('   🌐 URL: ${_dio.options.baseUrl}/turnos');
      print('   🔑 Headers: ${_dio.options.headers}');

      final requestData = {'idVehiculo': idVehiculo, 'lat': lat, 'lng': lng};
      print('   📤 Request Data: $requestData');

      final response = await _dio.post('turnos', data: requestData);

      print('   📥 Response Status: ${response.statusCode}');
      print('   📥 Response Data: ${response.data}');

      // Manejar redirección 302
      if (response.statusCode == 302 || response.statusCode == 301) {
        print('⚠️ Servidor está redirigiendo (302/301)');
        print('   Location: ${response.headers['location']}');
        print('   Esto puede indicar:');
        print('   - Usuario no autenticado correctamente');
        print('   - Usuario no tiene permisos de conductor');
        print('   - Endpoint requiere middleware específico');
        return null;
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = response.data;

        if (data['success'] == true || data['turno'] != null) {
          print('✅ Turno iniciado exitosamente');
          print('   ID Turno: ${data['turno']?['id']}');

          return TurnoResponse.fromJson(data);
        } else {
          print('⚠️ Respuesta inesperada: ${data['message'] ?? "Sin mensaje"}');
          return null;
        }
      }

      print('⚠️ Error al iniciar turno: Status ${response.statusCode}');
      return null;
    } on DioException catch (e) {
      print('❌ Error DioException iniciando turno:');
      print('   Tipo: ${e.type}');
      print('   Mensaje: ${e.message}');
      print('   🔗 Request URL: ${e.requestOptions.uri}');
      print('   🔗 Request Method: ${e.requestOptions.method}');
      print('   📤 Request Data: ${e.requestOptions.data}');
      print('   🔑 Request Headers: ${e.requestOptions.headers}');

      if (e.response != null) {
        print('   📥 Response Status: ${e.response?.statusCode}');
        print('   📥 Response Data: ${e.response?.data}');
        print('   📥 Response Headers: ${e.response?.headers}');

        // Verificar si es redirección
        if (e.response?.statusCode == 302 || e.response?.statusCode == 301) {
          print('   🔄 Redirección detectada');
          final location = e.response?.headers['location'];
          if (location != null) {
            print('   🔄 Redirigiendo a: $location');
          }
        }

        if (e.response?.data is Map) {
          final errorData = e.response?.data as Map;
          if (errorData['message'] != null) {
            print('   💬 Mensaje: ${errorData['message']}');
          }
          if (errorData['error'] != null) {
            print('   ⚠️ Error: ${errorData['error']}');
          }
        }
      } else {
        print('   ⚠️ No hay respuesta del servidor (posible problema de red)');
      }
      return null;
    } catch (e) {
      print('❌ Error iniciando turno: $e');
      return null;
    }
  }

  /// Finaliza el turno actual
  Future<bool> finalizarTurno(int idTurno) async {
    try {
      print('🛑 Finalizando turno $idTurno...');

      final response = await _dio.put(
        'turnos/$idTurno',
        data: {'estado': 'FINALIZADO'},
      );

      if (response.statusCode == 200) {
        final data = response.data;

        if (data['success'] == true) {
          print('✅ Turno finalizado exitosamente');
          return true;
        }
      }

      print('⚠️ Error al finalizar turno');
      return false;
    } on DioException catch (e) {
      print('❌ Error DioException finalizando turno:');
      print('   ${e.message}');
      if (e.response != null) {
        print('   Status: ${e.response?.statusCode}');
        print('   Data: ${e.response?.data}');
      }
      return false;
    } catch (e) {
      print('❌ Error finalizando turno: $e');
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
      print('Error obteniendo turno activo: $e');
      return null;
    }
  }

  /// Inicia turno con ubicación GPS automática
  Future<TurnoResponse?> iniciarTurnoConGPS({required int idVehiculo}) async {
    try {
      print('📍 Obteniendo ubicación GPS...');

      // Obtener ubicación actual
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      print('✅ Ubicación obtenida:');
      print('   Lat: ${position.latitude}');
      print('   Lng: ${position.longitude}');

      return await iniciarTurno(
        idVehiculo: idVehiculo,
        lat: position.latitude,
        lng: position.longitude,
      );
    } catch (e) {
      print('❌ Error obteniendo ubicación GPS: $e');
      print('   Tipo de error: ${e.runtimeType}');

      // Si falla el GPS, no podemos iniciar el turno
      return null;
    }
  }

  /// Verifica si hay un token de autenticación válido
  Future<bool> verificarAutenticacion() async {
    try {
      print('🔍 Verificando autenticación...');

      final response = await _dio.get(
        'auth/me',
      ); // O el endpoint que uses para verificar sesión

      if (response.statusCode == 200) {
        print('✅ Autenticación válida');
        print('   Usuario: ${response.data}');
        return true;
      }

      print('⚠️ Autenticación inválida');
      return false;
    } catch (e) {
      print('❌ Error verificando autenticación: $e');
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
