import 'package:dio/dio.dart';
import 'package:intellitaxi/core/dio_client.dart';
import 'package:intellitaxi/features/rides/data/calificacion_model.dart';
import 'package:intellitaxi/core/services/app_logger.dart';

/// Servicio para gestionar calificaciones de servicios de taxi
class CalificacionService {
  final Dio _dio = DioClient.getInstance();

  /// 📌 CREAR NUEVA CALIFICACIÓN
  Future<CalificacionServicio> crearCalificacion({
    required int idServicio,
    required int idUsuarioCalifica,
    required int idUsuarioCalificado,
    required String tipoCalificacion, // 'CONDUCTOR' o 'PASAJERO'
    required int calificacion, // 1 a 5
    String? comentario,
  }) async {
    try {
      AppLogger.d('📤 Enviando calificación:');
      AppLogger.d('   Servicio ID: $idServicio');
      AppLogger.d('   Califica: $idUsuarioCalifica');
      AppLogger.d('   Calificado: $idUsuarioCalificado');
      AppLogger.d('   Tipo: $tipoCalificacion');
      AppLogger.d('   Estrellas: $calificacion');

      final response = await _dio.post(
        'calificacion-servicio',
        data: {
          'idServicio': idServicio,
          'idUsuarioCalifica': idUsuarioCalifica,
          'idUsuarioCalificado': idUsuarioCalificado,
          'tipoCalificacion': tipoCalificacion,
          'calificacion': calificacion,
          if (comentario != null && comentario.isNotEmpty)
            'comentario': comentario,
        },
      );

      AppLogger.d('✅ Calificación creada exitosamente');

      // Extraer data de forma segura
      final responseData = response.data;
      final data = responseData is Map<String, dynamic>
          ? (responseData['data'] ?? responseData)
          : responseData;

      return CalificacionServicio.fromJson(data as Map<String, dynamic>);
    } on DioException catch (e) {
      AppLogger.d('⚠️ Error al crear calificación: ${e.response?.data}');
      throw _handleError(e);
    }
  }

  /// 📌 OBTENER CALIFICACIONES DE UN SERVICIO
  Future<List<CalificacionServicio>> obtenerCalificacionesServicio(
    int idServicio,
  ) async {
    try {
      final response = await _dio.get(
        'calificacion-servicio/servicio/$idServicio',
      );

      final data = response.data['data'] as List? ?? [];
      return data.map((item) => CalificacionServicio.fromJson(item)).toList();
    } on DioException catch (e) {
      AppLogger.d(
        '⚠️ Error al obtener calificaciones del servicio: ${e.message}',
      );
      throw _handleError(e);
    }
  }

  /// 📌 OBTENER CALIFICACIONES DE UN USUARIO
  Future<Map<String, dynamic>> obtenerCalificacionesUsuario({
    required int idUsuario,
    String? tipo, // 'CONDUCTOR' o 'PASAJERO'
    int page = 1,
  }) async {
    try {
      final queryParams = <String, dynamic>{'tipo': ?tipo, 'page': page};

      final response = await _dio.get(
        'calificacion-servicio/usuario/$idUsuario',
        queryParameters: queryParams,
      );

      final data = response.data['data'] ?? {};
      final calificaciones = data['calificaciones'] ?? {};
      final estadisticas = data['estadisticas'] ?? {};

      return {
        'calificaciones': (calificaciones['data'] as List? ?? [])
            .map((item) => CalificacionServicio.fromJson(item))
            .toList(),
        'total': calificaciones['total'] ?? 0,
        'current_page': calificaciones['current_page'] ?? 1,
        'estadisticas': EstadisticasCalificacion.fromJson({
          'estadisticas': estadisticas,
        }),
      };
    } on DioException catch (e) {
      AppLogger.d(
        '⚠️ Error al obtener calificaciones del usuario: ${e.message}',
      );
      throw _handleError(e);
    }
  }

  /// 📌 OBTENER PROMEDIO DE CALIFICACIÓN DE UN USUARIO
  Future<PromedioCalificacion> obtenerPromedioUsuario({
    required int idUsuario,
    String? tipo, // 'CONDUCTOR' o 'PASAJERO'
  }) async {
    try {
      final queryParams = tipo != null ? {'tipo': tipo} : null;

      final response = await _dio.get(
        'calificacion-servicio/usuario/$idUsuario/promedio',
        queryParameters: queryParams,
      );

      return PromedioCalificacion.fromJson(response.data);
    } on DioException catch (e) {
      AppLogger.d('⚠️ Error al obtener promedio: ${e.message}');
      throw _handleError(e);
    }
  }

  /// 📌 VERIFICAR SI PUEDE CALIFICAR
  Future<PuedeCalificar> verificarPuedeCalificar({
    required int idServicio,
    required int idUsuario,
  }) async {
    try {
      final response = await _dio.get(
        'calificacion-servicio/puede-calificar/$idServicio/$idUsuario',
      );

      return PuedeCalificar.fromJson(response.data);
    } on DioException catch (e) {
      AppLogger.d('⚠️ Error al verificar si puede calificar: ${e.message}');
      throw _handleError(e);
    }
  }

  /// 📌 OBTENER RANKING DE MEJORES CONDUCTORES
  Future<List<Map<String, dynamic>>> obtenerRankingConductores({
    int limit = 10,
  }) async {
    try {
      final response = await _dio.get(
        'calificacion-servicio/ranking/conductores',
        queryParameters: {'limit': limit},
      );

      final data = response.data['data'] as List? ?? [];
      return data.map((item) => item as Map<String, dynamic>).toList();
    } on DioException catch (e) {
      AppLogger.d('⚠️ Error al obtener ranking: ${e.message}');
      throw _handleError(e);
    }
  }

  /// 📌 OBTENER ESTADÍSTICAS GENERALES
  Future<Map<String, dynamic>> obtenerEstadisticasGenerales() async {
    try {
      final response = await _dio.get('calificacion-servicio/estadisticas');

      return response.data['data'] ?? {};
    } on DioException catch (e) {
      AppLogger.d('⚠️ Error al obtener estadísticas: ${e.message}');
      throw _handleError(e);
    }
  }

  /// Manejo de errores
  Exception _handleError(DioException e) {
    if (e.response?.data != null && e.response?.data is Map) {
      final message = e.response?.data['message'];
      if (message != null) {
        return Exception(message);
      }

      final errors = e.response?.data['errors'];
      if (errors != null && errors is Map) {
        final firstError = errors.values.first;
        if (firstError is List && firstError.isNotEmpty) {
          return Exception(firstError[0]);
        }
      }
    }

    return Exception('Error al procesar la solicitud');
  }
}
