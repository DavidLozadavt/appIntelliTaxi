import 'package:dio/dio.dart';
import 'package:intellitaxi/core/dio_client.dart';
import 'package:intellitaxi/features/conductor/data/documento_conductor_model.dart';
import 'package:intellitaxi/features/conductor/data/turno_model.dart';
import 'package:intellitaxi/features/conductor/data/vehiculo_conductor_model.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

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
  Future<TurnoActivo> iniciarTurno(
    int idVehiculo, {
    double? lat,
    double? lng,
  }) async {
    try {
      // Preparar datos con ubicación si están disponibles
      final Map<String, dynamic> requestData = {
        'idVehiculo': idVehiculo,
        if (lat != null) 'lat': lat,
        if (lng != null) 'lng': lng,
      };

      print('🚀 Iniciando turno con datos: $requestData');

      final response = await _dio.post('turnos', data: requestData);

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

  /// Acepta una solicitud de servicio
  Future<Map<String, dynamic>> aceptarSolicitud({
    required String servicioId,
    required double precioOfertado,
    String? mensaje,
  }) async {
    try {
      // Obtener conductor_id de la sesión
      final prefs = await SharedPreferences.getInstance();
      final userDataStr = prefs.getString('user_data');
      if (userDataStr == null) {
        throw Exception('No hay sesión activa');
      }

      final userData = json.decode(userDataStr);
      final conductorId = userData['user']?['id'];
      if (conductorId == null) {
        throw Exception('No se pudo obtener el ID del conductor');
      }

      // Extraer el ID numérico si viene con prefijo 'temp_'
      int? servicioIdNumerico;
      if (servicioId.startsWith('temp_')) {
        // Si es temporal, intentar extraer el timestamp o usar null
        print('⚠️ ID temporal detectado: $servicioId');
        // No podemos enviar un ID temporal al backend
        throw Exception('No se puede aceptar una solicitud con ID temporal');
      } else {
        servicioIdNumerico = int.tryParse(servicioId);
        if (servicioIdNumerico == null) {
          throw Exception('ID de servicio inválido: $servicioId');
        }
      }

      print('📤 Enviando aceptación de solicitud:');
      print('   servicio_id: $servicioIdNumerico');
      print('   conductor_id: $conductorId (de sesión)');
      print('   precio_ofertado: $precioOfertado');
      if (mensaje != null) print('   mensaje: $mensaje');

      final response = await _dio.post(
        'taxi/solicitud/aceptar',
        data: {
          'id': servicioIdNumerico,
          'servicio_id': servicioIdNumerico,
          'conductor_id': conductorId,
          'precio_ofertado': precioOfertado,
          if (mensaje != null && mensaje.isNotEmpty) 'mensaje': mensaje,
        },
        options: Options(
          headers: {'Content-Type': 'application/json'},
          followRedirects: false,
          validateStatus: (status) {
            // Considerar exitosos los códigos 200 y 201
            // Rechazar redirecciones (302)
            return status != null && status >= 200 && status < 300;
          },
        ),
      );

      print('✅ Respuesta del servidor: ${response.statusCode}');
      print('📦 Data: ${response.data}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        print('✅ Solicitud aceptada exitosamente');
        return response.data is Map<String, dynamic>
            ? response.data
            : {'success': true, 'data': response.data};
      } else {
        throw Exception('Error al aceptar solicitud: ${response.statusCode}');
      }
    } on DioException catch (e) {
      print('⚠️ DioException al aceptar solicitud:');
      print('   Status: ${e.response?.statusCode}');
      print('   Message: ${e.message}');
      print('   Response: ${e.response?.data}');

      if (e.response?.statusCode == 302) {
        throw Exception(
          'Error de autenticación (302). Verifica que estés autenticado correctamente.',
        );
      }

      if (e.response?.statusCode == 400) {
        // Extraer el mensaje del backend
        final errorMessage = e.response?.data is Map
            ? e.response?.data['message'] ?? 'Error en la solicitud'
            : 'Error en la solicitud';
        throw Exception(errorMessage);
      }

      rethrow;
    } catch (e) {
      print('⚠️ Error aceptando solicitud: $e');
      rethrow;
    }
  }
}
