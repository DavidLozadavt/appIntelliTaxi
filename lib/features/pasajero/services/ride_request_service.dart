import 'dart:convert';
import 'dart:developer' as developer;
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:intellitaxi/core/dio_client.dart';
import 'package:intellitaxi/features/rides/data/trip_location.dart';
import 'package:intellitaxi/core/services/app_logger.dart';

class RideRequestService {
  final Dio _dio = DioClient.getInstance();

  /// 📌 SOLICITAR SERVICIO DE VIAJE
  Future<Map<String, dynamic>> requestRide({
    required TripLocation origin,
    required TripLocation destination,
    required String distance,
    required int distanceValue, // en metros
    required String duration,
    required int durationValue, // en segundos
    double? estimatedPrice, // Opcional porque funciona con taxímetro
    required String serviceType, // 'taxi' o 'domicilio'
  }) async {
    // Preparar los datos según el formato del backend
    final Map<String, dynamic> requestData = {
      // Información del origen
      'origin_lat': origin.lat,
      'origin_lng': origin.lng,
      'origin_address': origin.address,
      'origin_name': origin.name,
      'origin_place_id': origin.placeId,

      // Información del destino
      'destination_lat': destination.lat,
      'destination_lng': destination.lng,
      'destination_address': destination.address,
      'destination_name': destination.name,
      'destination_place_id': destination.placeId,

      // Información de la ruta
      'distance': distance, // Ej: "8,7 km"
      'distance_value': distanceValue, // Ej: 8675 (metros)
      'duration': duration, // Ej: "21 min"
      'duration_value': durationValue, // Ej: 1275 (segundos)
      'estimated_price': estimatedPrice ?? 0, // 0 porque funciona con taxímetro
      // Tipo de servicio
      'service_type': serviceType, // 'taxi' o 'domicilio'
    };

    // 🔍 LOGS EN CONSOLA - Mostrar los datos que se van a enviar
    _logRequestData(requestData);

    try {
      final response = await _dio.post('taxi/solicitud', data: requestData);

      // Log de respuesta exitosa
      _logResponse(response.data);

      return response.data;
    } on DioException catch (e) {
      // Log de error
      _logError(e);

      if (e.response?.data != null && e.response?.data is Map) {
        final errors = e.response?.data['errors'];
        if (errors != null && errors is Map) {
          final firstError = errors.values.first;
          if (firstError is List && firstError.isNotEmpty) {
            throw Exception(firstError[0]);
          }
        }
        throw Exception(
          e.response?.data['message'] ?? 'Error al solicitar el servicio',
        );
      }
      throw Exception('Error de conexión al solicitar el servicio');
    }
  }

  /// 📌 ENVIAR OFERTA DIRECTA (Pasajero -> Conductor específico)
  Future<Map<String, dynamic>> sendDirectOffer({
    required int conductorId,
    required int pasajeroId,
    required TripLocation origin,
    required TripLocation destination,
    double precioOfrecido = 0,
    required String distancia,
    required String duracionEstimada,
    String? mensaje,
  }) async {
    final requestData = <String, dynamic>{
      'conductor_id': conductorId,
      'pasajero_id': pasajeroId,
      'origen': origin.address,
      'destino': destination.address,
      'origen_lat': origin.lat,
      'origen_lng': origin.lng,
      'destino_lat': destination.lat,
      'destino_lng': destination.lng,
      'precio_ofrecido': precioOfrecido,
      'distancia': distancia,
      'duracion_estimada': duracionEstimada,
      if (mensaje != null && mensaje.trim().isNotEmpty) 'mensaje': mensaje,
    };

    if (kDebugMode) {
      AppLogger.d('📤 Enviando oferta directa:');
      AppLogger.d('   conductor_id: $conductorId');
      AppLogger.d('   pasajero_id: $pasajeroId');
      AppLogger.d('   precio_ofrecido (taxímetro): $precioOfrecido');
      AppLogger.d('   origen: ${origin.address}');
      AppLogger.d('   destino: ${destination.address}');
    }

    try {
      final response = await _dio.post(
        'taxi/oferta-directa',
        data: requestData,
      );
      _logResponse(response.data);

      return response.data is Map<String, dynamic>
          ? response.data
          : <String, dynamic>{'success': true, 'data': response.data};
    } on DioException catch (e) {
      _logError(e);

      if (e.response?.data is Map) {
        final payload = e.response!.data as Map;
        throw Exception(payload['message'] ?? 'Error enviando oferta directa');
      }
      throw Exception('Error de conexión enviando oferta directa');
    }
  }

  /// 📌 LOGS DETALLADOS EN CONSOLA
  void _logRequestData(Map<String, dynamic> data) {
    if (kDebugMode) {
      AppLogger.d('\n${'=' * 80}');
      AppLogger.d('🚖 DATOS DE SOLICITUD DE SERVICIO');
      AppLogger.d('=' * 80);

      // IDs del usuario
      AppLogger.d('\n👤 DATOS DEL USUARIO:');
      AppLogger.d('   persona_id: ${data['persona_id']}');
      AppLogger.d('   company_user_id: ${data['company_user_id']}');

      // Origen
      AppLogger.d('\n📍 PUNTO DE ORIGEN:');
      AppLogger.d('   Nombre: ${data['origin_name']}');
      AppLogger.d('   Dirección: ${data['origin_address']}');
      AppLogger.d(
        '   Coordenadas: ${data['origin_lat']}, ${data['origin_lng']}',
      );
      AppLogger.d('   Place ID: ${data['origin_place_id']}');

      // Destino
      AppLogger.d('\n📍 PUNTO DE DESTINO:');
      AppLogger.d('   Nombre: ${data['destination_name']}');
      AppLogger.d('   Dirección: ${data['destination_address']}');
      AppLogger.d(
        '   Coordenadas: ${data['destination_lat']}, ${data['destination_lng']}',
      );
      AppLogger.d('   Place ID: ${data['destination_place_id']}');

      // Información de la ruta
      AppLogger.d('\n🛣️  INFORMACIÓN DE LA RUTA:');
      AppLogger.d(
        '   Distancia: ${data['distance']} (${data['distance_value']} metros)',
      );
      AppLogger.d(
        '   Duración: ${data['duration']} (${data['duration_value']} segundos)',
      );
      AppLogger.d('   Precio estimado: \$${data['estimated_price']}');

      // Tipo de servicio
      AppLogger.d('\n🚗 TIPO DE SERVICIO:');
      AppLogger.d(
        '   ${data['service_type']} (${data['service_type'] == 'taxi' ? 'Transporte de pasajeros' : 'Entrega de domicilio'})',
      );
      AppLogger.d('   Estado: ${data['status']}');

      // Observaciones
      if (data['observations'] != null) {
        AppLogger.d('\n📝 OBSERVACIONES:');
        AppLogger.d('   ${data['observations']}');
      }

      // Timestamp
      AppLogger.d('\n⏰ TIMESTAMP:');
      AppLogger.d('   ${data['requested_at']}');

      // JSON completo
      AppLogger.d('\n📦 JSON COMPLETO:');
      AppLogger.d(JsonEncoder.withIndent('  ').convert(data));

      AppLogger.d('=' * 80 + '\n');

      // También usar el logger de developer para que aparezca en DevTools
      developer.log(
        'Solicitud de servicio',
        name: 'RideRequestService',
        error: JsonEncoder.withIndent('  ').convert(data),
      );
    }
  }

  void _logResponse(dynamic data) {
    if (kDebugMode) {
      AppLogger.d('\n${'=' * 80}');
      AppLogger.d('✅ RESPUESTA DEL SERVIDOR');
      AppLogger.d('=' * 80);
      AppLogger.d(JsonEncoder.withIndent('  ').convert(data));
      AppLogger.d('=' * 80 + '\n');

      developer.log(
        'Respuesta exitosa del servidor',
        name: 'RideRequestService',
        error: JsonEncoder.withIndent('  ').convert(data),
      );
    }
  }

  void _logError(DioException e) {
    if (kDebugMode) {
      AppLogger.d('\n${'=' * 80}');
      AppLogger.d('❌ ERROR EN LA SOLICITUD');
      AppLogger.d('=' * 80);
      AppLogger.d('Tipo de error: ${e.type}');
      AppLogger.d('Mensaje: ${e.message}');
      if (e.response != null) {
        AppLogger.d('Status Code: ${e.response?.statusCode}');
        AppLogger.d('Datos de respuesta:');
        AppLogger.d(JsonEncoder.withIndent('  ').convert(e.response?.data));
      }
      AppLogger.d('=' * 80 + '\n');

      developer.log(
        'Error en solicitud de servicio',
        name: 'RideRequestService',
        error: e.toString(),
        stackTrace: e.stackTrace,
      );
    }
  }

  /// 📌 CANCELAR SOLICITUD DE SERVICIO
  Future<Map<String, dynamic>> cancelRideRequest({
    required int rideId,
    required String reason,
    String? token,
  }) async {
    final Map<String, dynamic> requestData = {
      'ride_id': rideId,
      'cancellation_reason': reason,
      'cancelled_at': DateTime.now().toIso8601String(),
    };

    if (kDebugMode) {
      AppLogger.d('\n🚫 CANCELANDO SOLICITUD:');
      AppLogger.d('   Ride ID: $rideId');
      AppLogger.d('   Razón: $reason\n');
    }

    try {
      final response = await _dio.post(
        'rides/$rideId/cancel',
        data: requestData,
        options: Options(
          headers: {if (token != null) "Authorization": "Bearer $token"},
        ),
      );

      return response.data;
    } on DioException catch (e) {
      _logError(e);
      throw Exception('Error al cancelar la solicitud');
    }
  }

  /// 📌 OBTENER HISTORIAL DE VIAJES
  Future<List<dynamic>> getRideHistory({
    required int personaId,
    String? token,
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final response = await _dio.get(
        'rides/history',
        queryParameters: {
          'persona_id': personaId,
          'page': page,
          'limit': limit,
        },
        options: Options(
          headers: {if (token != null) "Authorization": "Bearer $token"},
        ),
      );

      return response.data['rides'] ?? [];
    } on DioException catch (e) {
      _logError(e);
      throw Exception('Error al obtener el historial');
    }
  }

  /// 📌 OBTENER ESTADO DEL VIAJE
  Future<Map<String, dynamic>> getRideStatus({
    required int rideId,
    String? token,
  }) async {
    try {
      final response = await _dio.get(
        'rides/$rideId/status',
        options: Options(
          headers: {if (token != null) "Authorization": "Bearer $token"},
        ),
      );

      return response.data;
    } on DioException catch (e) {
      _logError(e);
      throw Exception('Error al obtener el estado del viaje');
    }
  }

  /// 📌 CANCELAR SERVICIO ACTIVO (para pasajeros)
  Future<Map<String, dynamic>> cancelarServicio({
    required int servicioId,
    required String motivo,
  }) async {
    try {
      AppLogger.d('📤 Cancelando servicio (pasajero):');
      AppLogger.d('   servicio_id: $servicioId');
      AppLogger.d('   motivo: $motivo');

      final response = await _dio.post(
        'taxi/servicio/cancelar',
        data: {'servicio_id': servicioId, 'motivo': motivo},
      );

      AppLogger.d('✅ Servicio cancelado exitosamente');
      return response.data is Map<String, dynamic>
          ? response.data
          : {'success': true};
    } catch (e) {
      AppLogger.d('❌ Error cancelando servicio: $e');
      rethrow;
    }
  }
}
