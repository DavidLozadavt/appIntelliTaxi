import 'package:dio/dio.dart';
import 'package:intellitaxi/core/dio_client.dart';
import 'package:intellitaxi/features/sanciones/data/sancion_model.dart';

class SancionService {
  final Dio _dio = DioClient.getInstance();

  Future<List<Sancion>> getMisSanciones() async {
    try {
      final response = await _dio.get('sanciones/mis-sanciones');

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;

        if (data['success'] == true && data['data'] != null) {
          final sanciones = (data['data'] as List)
              .map((s) => Sancion.fromJson(s))
              .toList();
          return sanciones;
        }
      }

      return [];
    } on DioException catch (e) {
      print('Error al obtener sanciones: ${e.message}');
      if (e.response?.data is Map) {
        final responseData = e.response?.data as Map;
        print('Mensaje del servidor: ${responseData['message']}');
      }
      throw Exception('Error al cargar las sanciones');
    }
  }
}
