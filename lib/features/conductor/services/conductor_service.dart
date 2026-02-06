import 'package:dio/dio.dart';
import 'package:intellitaxi/core/dio_client.dart';
import 'package:intellitaxi/features/conductor/data/documento_conductor_model.dart';
import 'package:intellitaxi/features/conductor/data/turno_model.dart';
import 'package:intellitaxi/features/conductor/data/vehiculo_conductor_model.dart';

class ConductorService {
  final Dio _dio = DioClient.getInstance();

  /// Obtiene los documentos del conductor
  Future<List<DocumentoConductor>> getDocumentosConductor(
    int conductorId,
  ) async {
    try {
      final response = await _dio.get(
        'get_documents_by_conductor/$conductorId',
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        return data.map((json) => DocumentoConductor.fromJson(json)).toList();
      } else {
        throw Exception('Error al obtener documentos: ${response.statusCode}');
      }
    } catch (e) {
      print('⚠️ Error obteniendo documentos del conductor: $e');
      rethrow;
    }
  }

  /// Obtiene los vehículos asignados al conductor
  Future<List<VehiculoConductor>> getVehiculosConductor() async {
    try {
      final response = await _dio.get('get_vehiculos_conductores');

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        return data.map((json) => VehiculoConductor.fromJson(json)).toList();
      } else {
        throw Exception('Error al obtener vehículos: ${response.statusCode}');
      }
    } catch (e) {
      print('⚠️ Error obteniendo vehículos del conductor: $e');
      rethrow;
    }
  }

  /// Verifica si hay documentos próximos a vencer o vencidos usando el endpoint de alertas
  Future<Map<String, List<DocumentoConductor>>> verificarDocumentos(
    int conductorId,
  ) async {
    try {
      final response = await _dio.get('get_documents_alert_driver');

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        final documentos = data
            .map((json) => DocumentoConductor.fromJson(json))
            .toList();

        final vencidos = <DocumentoConductor>[];
        final porVencer = <DocumentoConductor>[];

        for (final doc in documentos) {
          if (doc.estaVencido) {
            vencidos.add(doc);
          } else if (doc.estaPorVencer) {
            porVencer.add(doc);
          }
        }

        return {'vencidos': vencidos, 'porVencer': porVencer};
      } else {
        throw Exception('Error al obtener alertas: ${response.statusCode}');
      }
    } catch (e) {
      print('⚠️ Error verificando documentos: $e');
      return {'vencidos': [], 'porVencer': []};
    }
  }

  /// Inicia un turno con el vehículo seleccionado
  Future<TurnoActivo> iniciarTurno(int idVehiculo) async {
    try {
      final response = await _dio.post(
        'turnos',
        data: {'idVehiculo': idVehiculo},
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        // La respuesta puede venir en response.data directamente o en response.data['data']
        final turnoData =
            response.data is Map && response.data.containsKey('data')
            ? response.data['data']
            : response.data;
        return TurnoActivo.fromJson(turnoData);
      } else {
        throw Exception('Error al iniciar turno: ${response.statusCode}');
      }
    } catch (e) {
      print('⚠️ Error iniciando turno: $e');
      rethrow;
    }
  }

  /// Finaliza el turno activo
  Future<void> finalizarTurno(int idTurno) async {
    try {
      final response = await _dio.post('turnos/$idTurno/finalizar');

      if (response.statusCode != 200) {
        throw Exception('Error al finalizar turno: ${response.statusCode}');
      }
    } catch (e) {
      print('⚠️ Error finalizando turno: $e');
      rethrow;
    }
  }

  /// Obtiene el turno activo del conductor
  Future<TurnoActivo?> getTurnoActivo() async {
    try {
      final response = await _dio.get('turno_actual_conductor');

      if (response.statusCode == 200 && response.data != null) {
        return TurnoActivo.fromJson(response.data);
      }
      return null;
    } catch (e) {
      print('⚠️ Error obteniendo turno activo: $e');
      return null;
    }
  }

  /// Actualiza un documento del conductor
  Future<void> actualizarDocumento({
    required int idDocumento,
    required String filePath,
    required String fechaVigencia,
  }) async {
    try {
      final formData = FormData.fromMap({
        'idDocumento': idDocumento,
        'rutaFile': await MultipartFile.fromFile(filePath),
        'fecha_vigencia': fechaVigencia,
      });

      final response = await _dio.post(
        'update_documento_conductor',
        data: formData,
      );

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception(
          'Error al actualizar documento: ${response.statusCode}',
        );
      }
    } catch (e) {
      print('⚠️ Error actualizando documento: $e');
      rethrow;
    }
  }
}
