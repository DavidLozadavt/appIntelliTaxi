import 'package:dio/dio.dart';
import 'package:intellitaxi/core/dio_client.dart';
import 'package:intellitaxi/features/rides/data/conductor_model.dart';

class ConductoresService {
  final Dio _dio = DioClient.getInstance();

  /// Obtiene los conductores disponibles cerca de una ubicación
  Future<List<Conductor>> getConductoresDisponibles({
    required double lat,
    required double lng,
    double radioKm = 10,
  }) async {
    try {
      print('🔍 Buscando conductores disponibles...');
      print('   📍 Ubicación: ($lat, $lng)');
      print('   📏 Radio: $radioKm km');

      final queryParams = {'lat': lat, 'lng': lng, 'radio_km': radioKm};
      print('   📤 Query Parameters: $queryParams');
      print('   🌐 URL: ${_dio.options.baseUrl}/taxi/conductores-disponibles');

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

          print('✅ ${conductores.length} conductores encontrados');
          return conductores;
        } else {
          print('⚠️ Respuesta del servidor: success = false');
          print('   Mensaje: ${data['message'] ?? "Sin mensaje"}');
        }
      }

      print('⚠️ No se encontraron conductores');
      return [];
    } on DioException catch (e) {
      print('❌ Error DioException: ${e.message}');
      print('   🔗 Request URL: ${e.requestOptions.uri}');
      print('   � Request Method: ${e.requestOptions.method}');
      print('   📤 Request Data: ${e.requestOptions.data}');
      print('   🔑 Headers: ${e.requestOptions.headers}');

      if (e.response != null) {
        print('   📥 Status Code: ${e.response?.statusCode}');
        print('   📥 Response Data: ${e.response?.data}');

        // Si el servidor devuelve un mensaje de error específico
        if (e.response?.data is Map) {
          final responseData = e.response?.data as Map;
          if (responseData['message'] != null) {
            print('   💬 Mensaje del servidor: ${responseData['message']}');
          }
          if (responseData['error'] != null) {
            print('   ⚠️ Error del servidor: ${responseData['error']}');
          }
          if (responseData['errors'] != null) {
            print('   📋 Errores: ${responseData['errors']}');
          }
        }
      } else {
        print('   ⚠️ No hay respuesta del servidor');
      }
      return [];
    } catch (e) {
      print('❌ Error getConductoresDisponibles: $e');
      return [];
    }
  }
}
