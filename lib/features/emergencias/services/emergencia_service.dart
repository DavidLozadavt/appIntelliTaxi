import 'package:dio/dio.dart';
import 'package:intellitaxi/core/dio_client.dart';

import '../data/emergencia_model.dart';

class EmergenciaService {
  final Dio _dio = DioClient.getInstance();

  /// `POST /api/emergencias` — GPS al pulsar, sin `tipo` (backend → EMERGENCIA).
  Future<EmergenciaModel> crearEmergencia({
    required int idVehiculo,
    required int idTurno,
    required double lat,
    required double lng,
    String? mensaje,
  }) async {
    try {
      final response = await _dio.post(
        'emergencias',
        data: {
          'lat': lat,
          'lng': lng,
          'idVehiculo': idVehiculo,
          'idTurno': idTurno,
          if (mensaje != null && mensaje.trim().isNotEmpty)
            'mensaje': mensaje.trim(),
        },
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final raw = response.data;
        if (raw is Map && raw['data'] is Map) {
          return EmergenciaModel.fromJson(
            Map<String, dynamic>.from(raw['data'] as Map),
          );
        }
        if (raw is Map) {
          return EmergenciaModel.fromJson(Map<String, dynamic>.from(raw));
        }
        throw Exception('Respuesta inválida al crear emergencia');
      }
      throw Exception('Error al crear emergencia');
    } on DioException catch (e) {
      final msg = e.response?.data is Map
          ? (e.response?.data as Map)['message']?.toString()
          : null;
      throw Exception(msg ?? e.message ?? 'Error en la petición');
    }
  }

  /// `GET /api/emergencias/activas` — pins al abrir mapa.
  Future<List<EmergenciaModel>> listarActivas() async {
    try {
      final response = await _dio.get('emergencias/activas');
      if (response.statusCode != 200 || response.data == null) return [];

      final raw = response.data;
      List<dynamic> list;
      if (raw is Map && raw['data'] is List) {
        list = raw['data'] as List;
      } else if (raw is List) {
        list = raw;
      } else {
        return [];
      }

      return list
          .whereType<Map>()
          .map((e) => EmergenciaModel.fromJson(Map<String, dynamic>.from(e)))
          .where((e) => e.isActiva && e.id > 0)
          .toList();
    } on DioException {
      return [];
    }
  }

  /// `PUT /api/emergencias/finalizar/{id}`
  Future<bool> finalizarEmergencia(int idEmergencia) async {
    try {
      final response = await _dio.put('emergencias/finalizar/$idEmergencia');

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
      throw Exception(
        e.response?.data is Map
            ? (e.response?.data as Map)['message']?.toString() ??
                  'Error al finalizar emergencia'
            : e.message ?? 'Error al finalizar emergencia',
      );
    }
  }
}
