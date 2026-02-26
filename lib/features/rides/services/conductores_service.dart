import 'package:dio/dio.dart';
import 'package:intellitaxi/core/dio_client.dart';
import 'package:intellitaxi/features/rides/data/conductor_model.dart';
import 'package:intellitaxi/core/services/app_logger.dart';

class ConductoresService {
  final Dio _dio = DioClient.getInstance();

  /// Obtiene los conductores disponibles cerca de una ubicación
  Future<List<Conductor>> getConductoresDisponibles({
    required double lat,
    required double lng,
    double radioKm = 10,
  }) async {
    try {
      AppLogger.d('🔍 Buscando conductores disponibles...');
      AppLogger.d('   📍 Ubicación: ($lat, $lng)');
      AppLogger.d('   📏 Radio: $radioKm km');

      final queryParams = {'lat': lat, 'lng': lng, 'radio_km': radioKm};
      AppLogger.d('   📤 Query Parameters: $queryParams');
      AppLogger.d(
        '   🌐 URL: ${_dio.options.baseUrl}/taxi/conductores-disponibles',
      );

      final response = await _dio.get(
        'taxi/conductores-disponibles',
        queryParameters: queryParams,
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;

        if (data['success'] == true) {
          final conductores = (data['conductores'] as List)
              .map((c) => Conductor.fromJson(c))
              .toList();

          AppLogger.d('✅ ${conductores.length} conductores encontrados');
          return conductores;
        } else {
          AppLogger.d('⚠️ Respuesta del servidor: success = false');
          AppLogger.d('   Mensaje: ${data['message'] ?? "Sin mensaje"}');
        }
      }

      AppLogger.d('⚠️ No se encontraron conductores');
      return [];
    } on DioException catch (e) {
      AppLogger.d('❌ Error DioException: ${e.message}');
      AppLogger.d('   🔗 Request URL: ${e.requestOptions.uri}');
      AppLogger.d('   � Request Method: ${e.requestOptions.method}');
      AppLogger.d('   📤 Request Data: ${e.requestOptions.data}');
      AppLogger.d('   🔑 Headers: ${e.requestOptions.headers}');

      if (e.response != null) {
        AppLogger.d('   📥 Status Code: ${e.response?.statusCode}');
        AppLogger.d('   📥 Response Data: ${e.response?.data}');

        // Si el servidor devuelve un mensaje de error específico
        if (e.response?.data is Map) {
          final responseData = e.response?.data as Map;
          if (responseData['message'] != null) {
            AppLogger.d(
              '   💬 Mensaje del servidor: ${responseData['message']}',
            );
          }
          if (responseData['error'] != null) {
            AppLogger.d('   ⚠️ Error del servidor: ${responseData['error']}');
          }
          if (responseData['errors'] != null) {
            AppLogger.d('   📋 Errores: ${responseData['errors']}');
          }
        }
      } else {
        AppLogger.d('   ⚠️ No hay respuesta del servidor');
      }
      return [];
    } catch (e) {
      AppLogger.d('❌ Error getConductoresDisponibles: $e');
      return [];
    }
  }
}
