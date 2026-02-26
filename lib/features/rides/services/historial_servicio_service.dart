import 'package:dio/dio.dart';
import 'package:intellitaxi/core/dio_client.dart';
import 'package:intellitaxi/features/rides/data/historial_servicio_model.dart';
import 'package:intellitaxi/core/services/app_logger.dart';

/// Servicio para gestionar el historial de servicios de taxi
class HistorialServicioService {
  final Dio _dio = DioClient.getInstance();

  /// 📌 OBTENER HISTORIAL DE SERVICIOS DEL CONDUCTOR
  Future<HistorialResponse> obtenerHistorialConductor({
    required int conductorId,
    int page = 1,
  }) async {
    try {
      AppLogger.d(
        '📤 Obteniendo historial del conductor $conductorId (página $page)',
      );

      final response = await _dio.get(
        'historial-servicios/conductor/$conductorId',
        queryParameters: {'page': page},
      );

      AppLogger.d(
        '✅ Historial del conductor obtenido: ${response.data['pagination']['total']} servicios',
      );
      return HistorialResponse.fromJson(response.data);
    } on DioException catch (e) {
      AppLogger.d(
        '⚠️ Error al obtener historial del conductor: ${e.response?.data}',
      );
      throw _handleError(e);
    }
  }

  /// 📌 OBTENER HISTORIAL DE SERVICIOS DEL PASAJERO
  Future<HistorialResponse> obtenerHistorialPasajero({
    required int pasajeroId,
    int page = 1,
  }) async {
    try {
      AppLogger.d(
        '📤 Obteniendo historial del pasajero $pasajeroId (página $page)',
      );

      final response = await _dio.get(
        'historial-servicios/pasajero/$pasajeroId',
        queryParameters: {'page': page},
      );

      AppLogger.d(
        '✅ Historial del pasajero obtenido: ${response.data['pagination']['total']} servicios',
      );
      return HistorialResponse.fromJson(response.data);
    } on DioException catch (e) {
      AppLogger.d(
        '⚠️ Error al obtener historial del pasajero: ${e.response?.data}',
      );
      throw _handleError(e);
    }
  }

  /// 📌 OBTENER ESTADÍSTICAS DEL CONDUCTOR
  ///
  /// [filtro] puede ser: 'hoy', 'semana', 'mes', 'ano', 'personalizado' o null (todas)
  /// Si [filtro] es 'personalizado', se requieren [fechaInicio] y [fechaFin]
  Future<EstadisticasServicios> obtenerEstadisticasConductor({
    required int conductorId,
    String? filtro,
    String? fechaInicio,
    String? fechaFin,
  }) async {
    try {
      AppLogger.d(
        '📤 Obteniendo estadísticas del conductor $conductorId (filtro: $filtro)',
      );

      final queryParams = <String, dynamic>{};
      if (filtro != null) {
        queryParams['filtro'] = filtro;
        if (filtro == 'personalizado') {
          if (fechaInicio != null) queryParams['fecha_inicio'] = fechaInicio;
          if (fechaFin != null) queryParams['fecha_fin'] = fechaFin;
        }
      }

      final response = await _dio.get(
        'historial-servicios/conductor/$conductorId/estadisticas',
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );

      AppLogger.d('✅ Estadísticas del conductor obtenidas');
      return EstadisticasServicios.fromJson(response.data);
    } on DioException catch (e) {
      AppLogger.d(
        '⚠️ Error al obtener estadísticas del conductor: ${e.response?.data}',
      );
      throw _handleError(e);
    }
  }

  /// 📌 OBTENER ESTADÍSTICAS DEL PASAJERO
  ///
  /// [filtro] puede ser: 'hoy', 'semana', 'mes', 'ano', 'personalizado' o null (todas)
  /// Si [filtro] es 'personalizado', se requieren [fechaInicio] y [fechaFin]
  Future<EstadisticasServicios> obtenerEstadisticasPasajero({
    required int pasajeroId,
    String? filtro,
    String? fechaInicio,
    String? fechaFin,
  }) async {
    try {
      AppLogger.d(
        '📤 Obteniendo estadísticas del pasajero $pasajeroId (filtro: $filtro)',
      );

      final queryParams = <String, dynamic>{};
      if (filtro != null) {
        queryParams['filtro'] = filtro;
        if (filtro == 'personalizado') {
          if (fechaInicio != null) queryParams['fecha_inicio'] = fechaInicio;
          if (fechaFin != null) queryParams['fecha_fin'] = fechaFin;
        }
      }

      final response = await _dio.get(
        'historial-servicios/pasajero/$pasajeroId/estadisticas',
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );

      AppLogger.d('✅ Estadísticas del pasajero obtenidas');
      return EstadisticasServicios.fromJson(response.data);
    } on DioException catch (e) {
      AppLogger.d(
        '⚠️ Error al obtener estadísticas del pasajero: ${e.response?.data}',
      );
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
