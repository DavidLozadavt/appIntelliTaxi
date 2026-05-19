import 'package:dio/dio.dart';
import 'package:intellitaxi/core/dio_client.dart';

import '../data/emergencia_model.dart';

class EmergenciaService {
  final Dio _dio = DioClient.getInstance();

  Future<EmergenciaModel> crearEmergencia({
    required int idConductor,
    required int idVehiculo,
    required int idTurno,
    required double lat,
    required double lng,
    required String tipo,
    String? descripcion,
    bool silenciosa = true,
  }) async {
    try {
      final response = await _dio.post(
        "emergencias",
        data: {
          "idConductor": idConductor,
          "idVehiculo": idVehiculo,
          "idTurno": idTurno,
          "lat": lat,
          "lng": lng,
          "tipo": tipo,
          "descripcion": descripcion,
          "silenciosa": silenciosa ? 1 : 0,
        },
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data =
            response.data is Map && (response.data as Map).containsKey('data')
            ? response.data['data']
            : response.data;

        return EmergenciaModel.fromJson(Map<String, dynamic>.from(data as Map));
      } else {
        throw Exception("Error al crear emergencia");
      }
    } on DioException catch (e) {
      throw Exception("Error en la petición: ${e.message}");
    }
  }

  Future<bool> finalizarEmergencia(int idEmergencia) async {
    try {
      final response = await _dio.put("emergencias/finalizar/$idEmergencia");

      if (response.statusCode == null ||
          response.statusCode! < 200 ||
          response.statusCode! >= 300) {
        return false;
      }

      final data = response.data;
      if (data is Map && data['success'] == false) {
        return false;
      }

      return true;
    } on DioException catch (e) {
      throw Exception("Error al finalizar emergencia: ${e.message}");
    }
  }
}
