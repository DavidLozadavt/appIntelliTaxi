import 'dart:convert';
import 'dart:developer' as developer;
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:intellitaxi/core/dio_client.dart';
import 'package:intellitaxi/features/rides/data/trip_location.dart';

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

  /// 📌 LOGS DETALLADOS EN CONSOLA
  void _logRequestData(Map<String, dynamic> data) {
    if (kDebugMode) {
      print('\n${'=' * 80}');
      print('🚖 DATOS DE SOLICITUD DE SERVICIO');
      print('=' * 80);

      // IDs del usuario
      print('\n👤 DATOS DEL USUARIO:');
      print('   persona_id: ${data['persona_id']}');
      print('   company_user_id: ${data['company_user_id']}');

      // Origen
      print('\n📍 PUNTO DE ORIGEN:');
      print('   Nombre: ${data['origin_name']}');
      print('   Dirección: ${data['origin_address']}');
      print('   Coordenadas: ${data['origin_lat']}, ${data['origin_lng']}');
      print('   Place ID: ${data['origin_place_id']}');

      // Destino
      print('\n📍 PUNTO DE DESTINO:');
      print('   Nombre: ${data['destination_name']}');
      print('   Dirección: ${data['destination_address']}');
      print(
        '   Coordenadas: ${data['destination_lat']}, ${data['destination_lng']}',
      );
      print('   Place ID: ${data['destination_place_id']}');

      // Información de la ruta
      print('\n🛣️  INFORMACIÓN DE LA RUTA:');
      print(
        '   Distancia: ${data['distance']} (${data['distance_value']} metros)',
      );
      print(
        '   Duración: ${data['duration']} (${data['duration_value']} segundos)',
      );
      print('   Precio estimado: \$${data['estimated_price']}');

      // Tipo de servicio
      print('\n🚗 TIPO DE SERVICIO:');
      print(
        '   ${data['service_type']} (${data['service_type'] == 'taxi' ? 'Transporte de pasajeros' : 'Entrega de domicilio'})',
      );
      print('   Estado: ${data['status']}');

      // Observaciones
      if (data['observations'] != null) {
        print('\n📝 OBSERVACIONES:');
        print('   ${data['observations']}');
      }

      // Timestamp
      print('\n⏰ TIMESTAMP:');
      print('   ${data['requested_at']}');

      // JSON completo
      print('\n📦 JSON COMPLETO:');
      print(JsonEncoder.withIndent('  ').convert(data));

      print('=' * 80 + '\n');

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
      print('\n${'=' * 80}');
      print('✅ RESPUESTA DEL SERVIDOR');
      print('=' * 80);
      print(JsonEncoder.withIndent('  ').convert(data));
      print('=' * 80 + '\n');

      developer.log(
        'Respuesta exitosa del servidor',
        name: 'RideRequestService',
        error: JsonEncoder.withIndent('  ').convert(data),
      );
    }
  }

  void _logError(DioException e) {
    if (kDebugMode) {
      print('\n${'=' * 80}');
      print('❌ ERROR EN LA SOLICITUD');
      print('=' * 80);
      print('Tipo de error: ${e.type}');
      print('Mensaje: ${e.message}');
      if (e.response != null) {
        print('Status Code: ${e.response?.statusCode}');
        print('Datos de respuesta:');
        print(JsonEncoder.withIndent('  ').convert(e.response?.data));
      }
      print('=' * 80 + '\n');

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
      print('\n🚫 CANCELANDO SOLICITUD:');
      print('   Ride ID: $rideId');
      print('   Razón: $reason\n');
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
}
