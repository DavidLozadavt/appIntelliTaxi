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
        },
      );

      if (response.statusCode == 200 ||
          response.statusCode == 201) {

        return EmergenciaModel.fromJson(
          response.data['data'],
        );

      } else {

        throw Exception(
          "Error al crear emergencia",
        );
      }

    } on DioException catch (e) {

      throw Exception(
        "Error en la petición: ${e.message}",
      );
    }
  }
}