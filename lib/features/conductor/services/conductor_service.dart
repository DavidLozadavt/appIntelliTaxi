import 'package:dio/dio.dart';
import 'package:intellitaxi/core/dio_client.dart';
import 'package:intellitaxi/features/conductor/data/documento_conductor_model.dart';
import 'package:intellitaxi/features/conductor/data/documento_vehiculo_model.dart';
import 'package:intellitaxi/features/conductor/data/turno_model.dart';
import 'package:intellitaxi/features/conductor/data/vehiculo_conductor_model.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:intellitaxi/core/services/app_logger.dart';

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
      AppLogger.d('⚠️ Error obteniendo documentos del conductor: $e');
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
      AppLogger.d('⚠️ Error obteniendo vehículos del conductor: $e');
      rethrow;
    }
  }

  /// Obtiene los documentos de un vehículo
  Future<List<DocumentoVehiculo>> getDocumentosVehiculo(int idVehiculo) async {
    try {
      final response = await _dio.get('get_documents_by_vehiculo/$idVehiculo');
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        return data
            .map((json) => DocumentoVehiculo.fromJson(json))
            .toList();
      }
      throw Exception(
        'Error al obtener documentos del vehículo: ${response.statusCode}',
      );
    } catch (e) {
      AppLogger.d('⚠️ Error obteniendo documentos del vehículo $idVehiculo: $e');
      rethrow;
    }
  }

  /// Verifica si un vehículo tiene documentos vencidos y debe bloquearse
  Future<Map<String, dynamic>> verificarBloqueoVehiculo(int idVehiculo) async {
    try {
      final docs = await getDocumentosVehiculo(idVehiculo);
      final vencidos = docs.where((d) => d.estaVencido).toList();
      final porVencer = docs.where((d) => d.estaPorVencer).toList();
      return {
        'bloqueado': vencidos.isNotEmpty,
        'vencidos': vencidos,
        'porVencer': porVencer,
        'documentos': docs,
      };
    } catch (e) {
      return {
        'bloqueado': false,
        'vencidos': <DocumentoVehiculo>[],
        'porVencer': <DocumentoVehiculo>[],
        'documentos': <DocumentoVehiculo>[],
      };
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
      AppLogger.d('⚠️ Error verificando documentos: $e');
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
        'lat': ?lat,
        'lng': ?lng,
      };

      AppLogger.d('🚀 Iniciando turno con datos: $requestData');

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
      AppLogger.d('⚠️ Error iniciando turno: $e');
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
      AppLogger.d('⚠️ Error finalizando turno: $e');
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
      AppLogger.d('⚠️ Error obteniendo turno activo: $e');
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
      AppLogger.d('⚠️ Error actualizando documento: $e');
      rethrow;
    }
  }

  /// Actualiza un documento de vehículo
  Future<void> actualizarDocumentoVehiculo({
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
        'update_documento_vehiculo',
        data: formData,
      );

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception(
          'Error al actualizar documento de vehículo: ${response.statusCode}',
        );
      }
    } catch (e) {
      AppLogger.d('⚠️ Error actualizando documento de vehículo: $e');
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
        AppLogger.d('⚠️ ID temporal detectado: $servicioId');
        // No podemos enviar un ID temporal al backend
        throw Exception('No se puede aceptar una solicitud con ID temporal');
      } else {
        servicioIdNumerico = int.tryParse(servicioId);
        if (servicioIdNumerico == null) {
          throw Exception('ID de servicio inválido: $servicioId');
        }
      }

      AppLogger.d('📤 Enviando aceptación de solicitud:');
      AppLogger.d('   servicio_id: $servicioIdNumerico');
      AppLogger.d('   conductor_id: $conductorId (de sesión)');
      AppLogger.d('   precio_ofertado: $precioOfertado');
      if (mensaje != null) AppLogger.d('   mensaje: $mensaje');

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

      AppLogger.d('✅ Respuesta del servidor: ${response.statusCode}');
      AppLogger.d('📦 Data: ${response.data}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        AppLogger.d('✅ Solicitud aceptada exitosamente');
        return response.data is Map<String, dynamic>
            ? response.data
            : {'success': true, 'data': response.data};
      } else {
        throw Exception('Error al aceptar solicitud: ${response.statusCode}');
      }
    } on DioException catch (e) {
      AppLogger.d('⚠️ DioException al aceptar solicitud:');
      AppLogger.d('   Status: ${e.response?.statusCode}');
      AppLogger.d('   Message: ${e.message}');
      AppLogger.d('   Response: ${e.response?.data}');

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

      if (e.response?.statusCode == 409) {
        final errorMessage = e.response?.data is Map
            ? e.response?.data['message'] ??
                  'Este servicio ya fue aceptado por otro conductor'
            : 'Este servicio ya fue aceptado por otro conductor';
        throw Exception(errorMessage);
      }

      rethrow;
    } catch (e) {
      AppLogger.d('⚠️ Error aceptando solicitud: $e');
      rethrow;
    }
  }

  /// Solicitudes publicadas (estado 4) de la empresa del conductor — sincronización con backend.
  Future<List<Map<String, dynamic>>> listarSolicitudesPublicadasConductor() async {
    try {
      final response = await _dio.get('taxi/solicitudes-publicadas-conductor');
      if (response.statusCode != 200 || response.data == null) {
        return [];
      }
      final data = response.data;
      if (data is! Map) return [];
      final raw = data['solicitudes'];
      if (raw is! List) return [];
      return raw
          .map((e) => Map<String, dynamic>.from(e as Map<dynamic, dynamic>))
          .toList();
    } catch (e) {
      AppLogger.d('⚠️ Error listando solicitudes publicadas: $e');
      rethrow;
    }
  }

  /// Cancelar servicio activo
  Future<Map<String, dynamic>> cancelarServicio({
    required int servicioId,
    required String motivo,
  }) async {
    try {
      AppLogger.d('📤 Cancelando servicio:');
      AppLogger.d('   servicio_id: $servicioId');
      AppLogger.d('   motivo: $motivo');

      final response = await _dio.post(
        'taxi/servicio/cancelar',
        data: {'servicio_id': servicioId, 'motivo': motivo},
      );

      AppLogger.d('✅ Servicio cancelado exitosamente');
      final body = response.data;
      if (body is Map) {
        return Map<String, dynamic>.from(body);
      }
      return {'success': true};
    } catch (e) {
      AppLogger.d('❌ Error cancelando servicio: $e');
      rethrow;
    }
  }
}
