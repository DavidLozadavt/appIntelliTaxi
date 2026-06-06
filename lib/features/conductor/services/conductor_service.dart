import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:intellitaxi/core/dio_client.dart';
import 'package:intellitaxi/features/conductor/data/documento_conductor_model.dart';
import 'package:intellitaxi/features/conductor/data/documento_vehiculo_model.dart';
import 'package:intellitaxi/features/conductor/data/propietario_vehiculo_model.dart';
import 'package:intellitaxi/features/conductor/data/turno_model.dart';
import 'package:intellitaxi/features/conductor/data/conductor_ubicacion_mapa_result.dart';
import 'package:intellitaxi/features/conductor/data/vehiculo_conductor_model.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:intellitaxi/core/services/app_logger.dart';
import 'package:intellitaxi/core/utils/api_rate_limit_guard.dart';
import 'package:intellitaxi/core/utils/dio_error_message.dart';
import 'package:intellitaxi/features/taxi/data/taxi_servicio_estado.dart';
import 'package:intellitaxi/features/taxi/exceptions/taxi_en_servicio_exception.dart';
import 'package:intellitaxi/features/taxi/services/taxi_servicio_cancelacion_service.dart';

class ConductorService {
  final Dio _dio = DioClient.getInstance();

  Never _failFromDio(DioException e, {required String fallback}) {
    AppLogger.d(
      'API ${e.requestOptions.path} → ${e.response?.statusCode}: '
      '${DioErrorMessage.fromResponseData(e.response?.data, fallback)}',
    );
    throw Exception(DioErrorMessage.from(e, fallback: fallback));
  }

  /// Bootstrap: estado rápido del conductor (`GET /taxi/conductor/estado-actual`).
  Future<TaxiConductorEstadoActual?> getEstadoActualConductor() async {
    try {
      final response = await _dio.get('taxi/conductor/estado-actual');
      final data = response.data;
      if (data is Map && data['success'] == true) {
        return TaxiConductorEstadoActual.fromJson(
          Map<String, dynamic>.from(data),
        );
      }
      return null;
    } catch (e) {
      AppLogger.d('⚠️ Error obteniendo estado-actual conductor: $e');
      return null;
    }
  }

  /// Consulta modo descanso (`GET /taxi/conductor/modo-descanso`).
  Future<TaxiModoDescansoEstado?> getModoDescanso() async {
    try {
      final response = await _dio.get('taxi/conductor/modo-descanso');
      final data = response.data;
      if (data is Map && data['success'] == true) {
        return TaxiModoDescansoEstado.fromJson(
          Map<String, dynamic>.from(data),
        );
      }
      return null;
    } catch (e) {
      AppLogger.d('⚠️ Error consultando modo descanso: $e');
      return null;
    }
  }

  /// Activa o desactiva modo descanso (`POST /taxi/conductor/modo-descanso`).
  Future<TaxiModoDescansoEstado> setModoDescanso({
    required bool descanso,
    required double lat,
    required double lng,
  }) async {
    try {
      final response = await _dio.post(
        'taxi/conductor/modo-descanso',
        data: {
          'descanso': descanso,
          'lat': lat,
          'lng': lng,
        },
      );

      final data = response.data;
      if (data is Map && data['success'] == true) {
        return TaxiModoDescansoEstado.fromJson(
          Map<String, dynamic>.from(data),
        );
      }

      throw Exception(
        data is Map
            ? data['message']?.toString() ?? 'No se pudo cambiar el modo descanso'
            : 'No se pudo cambiar el modo descanso',
      );
    } on DioException catch (e) {
      throw Exception(_extractErrorMessage(e, 'No se pudo cambiar el modo descanso'));
    }
  }

  /// Detalle del viaje activo (`GET /taxi/servicio-activo-conductor`). 404 → null.
  Future<Map<String, dynamic>?> getServicioActivoConductor() async {
    try {
      final response = await _dio.get('taxi/servicio-activo-conductor');
      if (response.statusCode != 200 || response.data == null) return null;

      final data = response.data;
      if (data is! Map || data['success'] != true || data['data'] == null) {
        return null;
      }

      final payload = Map<String, dynamic>.from(data['data'] as Map);
      return {
        'en_servicio': data['en_servicio'] ?? true,
        'servicio': payload['servicio'],
        'pasajero': payload['pasajero'],
        'vehiculo': payload['vehiculo'],
        'conductor': payload['conductor'],
      };
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      AppLogger.d('⚠️ Error obteniendo servicio activo conductor: ${e.message}');
      return null;
    } catch (e) {
      AppLogger.d('⚠️ Error obteniendo servicio activo conductor: $e');
      return null;
    }
  }

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
        final rawList = _extractJsonList(response.data);
        final vehiculos = <VehiculoConductor>[];
        for (final item in rawList) {
          if (item is! Map) continue;
          try {
            vehiculos.add(
              VehiculoConductor.fromJson(
                Map<String, dynamic>.from(item),
              ),
            );
          } catch (e) {
            AppLogger.w('⚠️ Vehículo omitido por error de parseo: $e');
          }
        }
        AppLogger.d('✅ ${vehiculos.length} vehículo(s) cargados');
        return vehiculos;
      } else {
        throw Exception('Error al obtener vehículos: ${response.statusCode}');
      }
    } catch (e) {
      AppLogger.d('⚠️ Error obteniendo vehículos del conductor: $e');
      rethrow;
    }
  }

  /// Normaliza respuestas del API: lista directa o envuelta en `data` / `vehiculos`.
  static List<dynamic> _extractJsonList(dynamic data) {
    if (data is List) return data;
    if (data is Map) {
      for (final key in const [
        'data',
        'vehiculos',
        'vehículos',
        'items',
        'results',
      ]) {
        final value = data[key];
        if (value is List) return value;
      }
    }
    return const [];
  }

  /// Obtiene los documentos de un vehículo
  Future<List<DocumentoVehiculo>> getDocumentosVehiculo(int idVehiculo) async {
    try {
      final response = await _dio.get('get_documents_by_vehiculo/$idVehiculo');
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        return data.map((json) => DocumentoVehiculo.fromJson(json)).toList();
      }
      throw Exception(
        'Error al obtener documentos del vehículo: ${response.statusCode}',
      );
    } catch (e) {
      AppLogger.d(
        '⚠️ Error obteniendo documentos del vehículo $idVehiculo: $e',
      );
      rethrow;
    }
  }

  /// Obtiene propietarios asociados a la afiliación del vehículo
  Future<List<AfiliacionPropietariosVehiculo>> getPropietariosByAfiliacion(
    int idAfiliacion,
  ) async {
    try {
      final response = await _dio.get('get_propietarios_by_id/$idAfiliacion');
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        return data
            .whereType<Map>()
            .map(
              (json) => AfiliacionPropietariosVehiculo.fromJson(
                Map<String, dynamic>.from(json),
              ),
            )
            .toList();
      }
      throw Exception('Error al obtener propietarios: ${response.statusCode}');
    } catch (e) {
      AppLogger.d(
        '⚠️ Error obteniendo propietarios de afiliación $idAfiliacion: $e',
      );
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
      final requestData = <String, dynamic>{
        'idVehiculo': idVehiculo,
        'id_vehiculo': idVehiculo,
        'estado': 'ACTIVO',
      };
      if (lat != null) {
        requestData['lat'] = lat;
        requestData['latitude'] = lat;
      }
      if (lng != null) {
        requestData['lng'] = lng;
        requestData['longitude'] = lng;
      }

      AppLogger.d('🚀 Iniciando turno con datos: $requestData');

      final response = await _dio.post('turnos', data: requestData);
      final status = response.statusCode ?? 0;

      if (status == 200 || status == 201) {
        final turnoData = _unwrapTurnoPayload(response.data);
        if (turnoData == null) {
          throw Exception('Respuesta de turno inválida del servidor');
        }
        return TurnoActivo.fromJson(turnoData);
      }

      final message = _messageFromResponseData(
        response.data,
        'No se pudo iniciar el turno (código $status)',
      );
      AppLogger.d('⚠️ Error iniciando turno: $status → $message');
      if (kDebugMode) {
        AppLogger.d('   body: ${response.data}');
      }
      throw Exception(message);
    } on DioException catch (e) {
      AppLogger.d('⚠️ Error iniciando turno: $e');
      throw Exception(_extractErrorMessage(e, 'No se pudo iniciar el turno'));
    } catch (e) {
      AppLogger.d('⚠️ Error iniciando turno: $e');
      rethrow;
    }
  }

  Map<String, dynamic>? _unwrapTurnoPayload(dynamic data) {
    if (data is! Map) return null;
    final map = Map<String, dynamic>.from(data);
    if (map['success'] == false) return null;

    final turno = map['turno'];
    if (turno is Map) {
      return Map<String, dynamic>.from(turno);
    }

    final nested = map['data'];
    if (nested is Map) {
      final nestedMap = Map<String, dynamic>.from(nested);
      final inner = nestedMap['turno'];
      if (inner is Map) {
        return Map<String, dynamic>.from(inner);
      }
      if (nestedMap.containsKey('id')) {
        return nestedMap;
      }
    }

    if (map.containsKey('id')) {
      return map;
    }
    return null;
  }

  /// Finaliza un turno por id (`POST /turnos/{id}/finalizar`).
  Future<void> finalizarTurno(int idTurno) async {
    try {
      final response = await _dio.post('turnos/$idTurno/finalizar');

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception('Error al finalizar turno: ${response.statusCode}');
      }
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status == 404 || status == 422) {
        AppLogger.d(
          'ℹ️ finalizar turno $idTurno → $status (ya cerrado en servidor)',
        );
        return;
      }
      AppLogger.d('⚠️ Error finalizando turno: $e');
      throw Exception(_extractErrorMessage(e, 'No se pudo finalizar el turno'));
    } catch (e) {
      AppLogger.d('⚠️ Error finalizando turno: $e');
      rethrow;
    }
  }

  /// Cierra el turno activo del conductor autenticado (`POST /turnos/finalizar-activo`).
  Future<void> finalizarTurnoActivo() async {
    try {
      final response = await _dio.post('turnos/finalizar-activo');
      final data = response.data;
      if (data is Map && data['success'] == false) {
        throw Exception(
          data['message']?.toString() ?? 'No se pudo finalizar el turno activo',
        );
      }
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status == 404 || status == 422) {
        AppLogger.d(
          'ℹ️ finalizar-activo → $status (sin turno activo o ya cerrado)',
        );
        return;
      }
      throw Exception(
        _extractErrorMessage(e, 'No se pudo finalizar el turno activo'),
      );
    }
  }

  /// Mantiene actualizada la ubicación usada por el mapa del pasajero.
  /// Si el backend incluye `zona` / `barrio` en la respuesta, la app la muestra sin geocode en el móvil.
  Future<ConductorUbicacionMapaResult?> actualizarUbicacionMapa({
    required double lat,
    required double lng,
    double? velocidad,
    double? direccion,
    String estado = 'disponible',
  }) async {
    late final DioException primaryError;
    final conductorId = await _getSessionConductorId();
    final requestData = <String, dynamic>{
      'conductor_id': ?conductorId,
      'idConductor': ?conductorId,
      'lat': lat,
      'lng': lng,
      'velocidad': velocidad ?? 0,
      'direccion': direccion ?? 0,
      'estado': estado,
    };

    try {
      final response = await _dio.post(
        'taxi/conductor/ubicacion-mapa',
        data: requestData,
      );

      if ((response.statusCode != 200 && response.statusCode != 201) ||
          response.data is Map && response.data['success'] == false) {
        throw Exception(
          response.data is Map
              ? response.data['message'] ?? 'Error actualizando ubicación'
              : 'Error actualizando ubicación de mapa: ${response.statusCode}',
        );
      }
      return ConductorUbicacionMapaResult.tryFromResponse(response.data);
    } on DioException catch (e) {
      primaryError = e;
      AppLogger.d(
        '⚠️ Endpoint taxi/conductor/ubicacion-mapa falló; probando compatibilidad anterior',
      );
    } catch (e) {
      AppLogger.d('⚠️ Error actualizando ubicación de mapa: $e');
      rethrow;
    }

    try {
      if (conductorId == null) {
        throw Exception('No se pudo obtener el ID del conductor');
      }

      final response = await _dio.post(
        'conductor/estado-disponible',
        data: {
          'conductor_id': conductorId,
          'lat': lat,
          'lng': lng,
          'estado': estado,
        },
      );

      if ((response.statusCode != 200 && response.statusCode != 201) ||
          response.data is Map && response.data['success'] == false) {
        throw Exception(
          response.data is Map
              ? response.data['message'] ?? 'Error actualizando ubicación'
              : 'Error actualizando ubicación anterior: ${response.statusCode}',
        );
      }
      return ConductorUbicacionMapaResult.tryFromResponse(response.data);
    } catch (fallbackError) {
      AppLogger.d('⚠️ Error actualizando ubicación de mapa: $fallbackError');
      throw primaryError;
    }
  }

  Future<int?> _getSessionConductorId() async {
    final prefs = await SharedPreferences.getInstance();
    final directId = prefs.getInt('conductor_id') ?? prefs.getInt('user_id');
    if (directId != null) return directId;

    final userDataStr = prefs.getString('user_data');
    if (userDataStr == null || userDataStr.isEmpty) return null;

    try {
      final userData = json.decode(userDataStr);
      final id = userData['user']?['id'] ?? userData['id'];
      if (id is int) return id;
      if (id is num) return id.toInt();
      return int.tryParse(id?.toString() ?? '');
    } catch (_) {
      return null;
    }
  }

  /// Obtiene el turno activo del conductor
  Future<TurnoActivo?> getTurnoActivo() async {
    try {
      final response = await _dio.get('turno_actual_conductor');
      if (response.statusCode != 200 || response.data == null) {
        return null;
      }

      final turnoData = _unwrapTurnoPayload(response.data);
      if (turnoData == null) return null;

      final turno = TurnoActivo.fromJson(turnoData);
      return turno.estaActivo ? turno : null;
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status == 429) {
        ApiRateLimitGuard.instance.recordHit();
      }
      if (status == 404) return null;
      AppLogger.d(
        '⚠️ GET turno_actual_conductor → $status '
        '(Authorization va por AuthInterceptor): '
        '${DioErrorMessage.fromResponseData(e.response?.data, e.message ?? '')}',
      );
      rethrow;
    } catch (e) {
      AppLogger.d('⚠️ Error obteniendo turno activo: $e');
      rethrow;
    }
  }

  /// Actualiza un documento del conductor
  Future<void> actualizarDocumento({
    required int idDocumento,
    required String filePath,
    String? fechaVigencia,
    int? idTipoDocumento,
    int? idConductor,
  }) async {
    try {
      final formData = FormData.fromMap({
        'idDocumento': idDocumento,
        'idTipoDocumento': ?idTipoDocumento,
        'idConductor': ?idConductor,
        'rutaFile': await MultipartFile.fromFile(filePath),
        'fecha_vigencia': ?fechaVigencia,
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
    double? lat,
    double? lng,
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
          if (lat != null) ...{
            'lat': lat,
            'latitude': lat,
          },
          if (lng != null) ...{
            'lng': lng,
            'longitude': lng,
          },
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
      if (e.response?.statusCode == 302) {
        throw Exception(
          'Error de autenticación (302). Verifica que estés autenticado correctamente.',
        );
      }

      if (e.response?.statusCode == 409) {
        final enServicio = TaxiEnServicioException.fromResponseBody(
          e.response?.data,
        );
        if (enServicio != null) throw enServicio;
      }

      _failFromDio(
        e,
        fallback: 'No se pudo aceptar el servicio. Intenta de nuevo.',
      );
    } catch (e) {
      if (e is Exception && e is! DioException) rethrow;
      AppLogger.d('⚠️ Error aceptando solicitud: $e');
      rethrow;
    }
  }

  /// Rechaza un servicio para este conductor (`POST /taxi/solicitud/rechazar`).
  Future<Map<String, dynamic>> rechazarSolicitud({
    required int servicioId,
  }) async {
    try {
      final response = await _dio.post(
        'taxi/solicitud/rechazar',
        data: {'servicio_id': servicioId},
      );

      final data = response.data;
      if (data is Map && data['success'] == true) {
        return Map<String, dynamic>.from(data);
      }

      throw Exception(
        data is Map
            ? data['message']?.toString() ?? 'No se pudo rechazar el servicio'
            : 'No se pudo rechazar el servicio',
      );
    } on DioException catch (e) {
      throw Exception(
        _extractErrorMessage(e, 'No se pudo rechazar el servicio'),
      );
    }
  }

  /// Oferta exclusiva inDrive activa para este conductor (`GET /taxi/oferta-activa`).
  Future<({bool tieneOferta, Map<String, dynamic>? oferta})> getOfertaActiva() async {
    try {
      final response = await _dio.get('taxi/oferta-activa');
      final data = response.data;
      if (data is! Map || data['success'] != true) {
        return (tieneOferta: false, oferta: null);
      }
      if (data['tiene_oferta'] != true) {
        return (tieneOferta: false, oferta: null);
      }
      final oferta = data['oferta'];
      if (oferta is! Map) {
        return (tieneOferta: false, oferta: null);
      }
      return (
        tieneOferta: true,
        oferta: Map<String, dynamic>.from(oferta),
      );
    } on DioException catch (e) {
      AppLogger.d('⚠️ GET oferta-activa: ${e.message}');
      return (tieneOferta: false, oferta: null);
    }
  }

  /// IDs de servicios rechazados por el conductor (`GET /taxi/conductor/solicitudes-rechazadas`).
  Future<TaxiSolicitudesRechazadasResult> getSolicitudesRechazadas() async {
    try {
      final response = await _dio.get('taxi/conductor/solicitudes-rechazadas');
      final data = response.data;
      if (data is! Map || data['success'] != true) {
        return TaxiSolicitudesRechazadasResult.empty();
      }

      final raw = data['servicio_ids'] ?? data['servicioIds'];
      final ids = <int>{};
      if (raw is List) {
        for (final item in raw) {
          final id = int.tryParse(item.toString());
          if (id != null && id > 0) ids.add(id);
        }
      }

      final total =
          int.tryParse((data['total'] ?? ids.length).toString()) ?? ids.length;

      return TaxiSolicitudesRechazadasResult(total: total, servicioIds: ids);
    } catch (e) {
      AppLogger.d('⚠️ Error obteniendo solicitudes rechazadas: $e');
      return TaxiSolicitudesRechazadasResult.empty();
    }
  }

  /// Marca que el conductor vio la solicitud (`POST /taxi/solicitud/vista`).
  Future<void> marcarSolicitudVista({required int servicioId}) async {
    try {
      await _dio.post(
        'taxi/solicitud/vista',
        data: {'servicio_id': servicioId},
      );
    } catch (e) {
      AppLogger.d('⚠️ Error marcando solicitud vista: $e');
    }
  }

  /// Servicios pendientes sin conductor (`GET /taxi/solicitudes-pendientes`).
  Future<TaxiSolicitudesPendientesResult> getSolicitudesPendientes({
    double? lat,
    double? lng,
    int limit = 50,
  }) async {
    const fallback = 'No se pudieron cargar las solicitudes en espera';
    try {
      final query = <String, dynamic>{'limit': limit.clamp(1, 100)};
      if (lat != null && lng != null) {
        query['lat'] = lat;
        query['lng'] = lng;
      }

      final response = await _dio.get(
        'taxi/solicitudes-pendientes',
        queryParameters: query,
      );

      final status = response.statusCode ?? 0;
      if (status == 403) {
        throw Exception(
          _messageFromResponseData(
            response.data,
            'No tienes permiso para ver solicitudes en espera. '
                'Verifica que tu turno esté activo.',
          ),
        );
      }
      if (status == 429) {
        ApiRateLimitGuard.instance.recordHit();
        throw Exception(
          _messageFromResponseData(
            response.data,
            'Demasiadas peticiones. Espera un momento.',
          ),
        );
      }
      if (status >= 400) {
        throw Exception(_messageFromResponseData(response.data, fallback));
      }

      return _parseSolicitudesPendientesResponse(response.data);
    } on DioException catch (e) {
      ApiRateLimitGuard.instance.recordIfRateLimit(e);
      AppLogger.d('⚠️ Error listando solicitudes pendientes: $e');
      throw Exception(_extractErrorMessage(e, fallback));
    } catch (e) {
      AppLogger.d('⚠️ Error listando solicitudes pendientes: $e');
      rethrow;
    }
  }

  /// Solicitudes publicadas — alias de pendientes (compatibilidad).
  Future<TaxiSolicitudesPublicadasResult>
  listarSolicitudesPublicadasConductor({
    double? lat,
    double? lng,
    int limit = 50,
  }) async {
    try {
      final pendientes = await getSolicitudesPendientes(
        lat: lat,
        lng: lng,
        limit: limit,
      );

      return TaxiSolicitudesPublicadasResult(
        enServicio: pendientes.enServicio,
        enDescanso: pendientes.enDescanso,
        solicitudes: pendientes.pendientes,
      );
    } catch (e) {
      AppLogger.d('⚠️ Error listando solicitudes publicadas: $e');
      rethrow;
    }
  }

  TaxiSolicitudesPendientesResult _parseSolicitudesPendientesResponse(
    dynamic data,
  ) {
    if (data is! Map) {
      return TaxiSolicitudesPendientesResult.empty();
    }

    final enServicio = data['en_servicio'] == true;
    final enDescanso = data['en_descanso'] == true;
    final servicioActivoId = int.tryParse(
      (data['servicio_activo_id'] ?? data['servicioActivoId'] ?? '').toString(),
    );

    if (enServicio || enDescanso) {
      return TaxiSolicitudesPendientesResult(
        enServicio: enServicio,
        enDescanso: enDescanso,
        servicioActivoId: servicioActivoId,
        total: 0,
        pendientes: const [],
      );
    }

    final raw = data['pendientes'] ?? data['solicitudes'];
    final list = raw is List
        ? raw
            .map((e) => Map<String, dynamic>.from(e as Map<dynamic, dynamic>))
            .toList()
        : <Map<String, dynamic>>[];

    final assignmentMethod = data['assignment_method']?.toString().trim();
    final driverSearchRadiusKm = _parseDriverSearchRadiusKm(data);
    final listaGlobal = _parseListaGlobal(data, assignmentMethod);

    return TaxiSolicitudesPendientesResult(
      enServicio: false,
      enDescanso: false,
      idEmpresa: int.tryParse((data['id_empresa'] ?? '').toString()),
      total: int.tryParse((data['total'] ?? list.length).toString()) ??
          list.length,
      pendientes: list,
      actualizadoEn: data['actualizado_en']?.toString(),
      pendientesMaxEdadMinutos: int.tryParse(
        (data['pendientes_max_edad_minutos'] ??
                data['pendientesMaxEdadMinutos'] ??
                '')
            .toString(),
      ),
      listaGlobal: listaGlobal,
      assignmentMethod: assignmentMethod,
      driverSearchRadiusKm: driverSearchRadiusKm,
      queueMaxMinutes: _parseDoubleMeta(data['queue_max_minutes']),
      queueAbiertaMaxMinutes:
          _parseDoubleMeta(data['queue_abierta_max_minutes']),
      ventanaListaMinutos: _parseDoubleMeta(data['ventana_lista_minutos']),
      ofertaExclusivaSegundos: _parseIntMeta(
        data['oferta_exclusiva_segundos'],
      ),
      ofertaMaxIntentos: _parseIntMeta(data['oferta_max_intentos']),
    );
  }

  static int? _parseIntMeta(dynamic raw) {
    if (raw == null) return null;
    if (raw is int) return raw > 0 ? raw : null;
    return int.tryParse(raw.toString());
  }

  static double? _parseDoubleMeta(dynamic raw) {
    if (raw == null) return null;
    if (raw is num) return raw.toDouble();
    return double.tryParse(raw.toString());
  }

  double? _parseDriverSearchRadiusKm(Map data) {
    for (final key in const [
      'driver_search_radius_km',
      'driverSearchRadiusKm',
      'radio_km',
      'radioKm',
    ]) {
      final raw = data[key];
      if (raw == null) continue;
      final km = double.tryParse(raw.toString());
      if (km != null && km > 0) return km;
    }
    return null;
  }

  bool _parseListaGlobal(Map data, String? assignmentMethod) {
    if (data.containsKey('lista_global')) {
      return data['lista_global'] == true;
    }
    final method = assignmentMethod?.toUpperCase().trim();
    if (method == 'NEAREST_OFFER_THEN_BROADCAST') return true;
    if (method == 'BROADCAST_NEARBY_DRIVERS') return false;
    return true;
  }

  /// Cancelar servicio activo (`POST taxi/servicio/cancelar`, motivo opcional).
  Future<Map<String, dynamic>> cancelarServicio({
    required int servicioId,
    String? motivoCodigo,
    String? motivo,
  }) async {
    try {
      return await TaxiServicioCancelacionService(_dio).cancelar(
        servicioId: servicioId,
        motivoCodigo: motivoCodigo,
        motivo: motivo,
      );
    } catch (e) {
      AppLogger.d('❌ Error cancelando servicio: $e');
      rethrow;
    }
  }

  String _extractErrorMessage(DioException e, String fallback) {
    return _messageFromResponseData(e.response?.data, fallback);
  }

  String _messageFromResponseData(dynamic data, String fallback) {
    if (data is Map) {
      final map = Map<String, dynamic>.from(data);
      final message = map['message'] ?? map['error'] ?? map['mensaje'];
      if (message != null && message.toString().trim().isNotEmpty) {
        return message.toString().trim();
      }

      final errors = map['errors'];
      if (errors is Map && errors.isNotEmpty) {
        for (final entry in errors.entries) {
          final value = entry.value;
          if (value is List && value.isNotEmpty) {
            return value.first.toString();
          }
          if (value != null && value.toString().trim().isNotEmpty) {
            return value.toString();
          }
        }
      }
    }

    if (data is String && data.trim().isNotEmpty) {
      return data.trim();
    }

    return fallback;
  }
}
