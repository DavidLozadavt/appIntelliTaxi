import 'package:dio/dio.dart';

/// Mensaje legible para el usuario (sin volcar el stack de Dio).
abstract final class DioErrorMessage {
  static String from(Object error, {required String fallback}) {
    if (error is DioException) {
      final status = error.response?.statusCode;
      if (status == 403) {
        return fromResponseData(
          error.response?.data,
          'No tienes permiso para esta acción. Verifica tu turno activo.',
        );
      }
      if (status == 401) {
        return 'Sesión expirada. Vuelve a iniciar sesión.';
      }
      final fromBody = fromResponseData(error.response?.data, '');
      if (fromBody.isNotEmpty) return fromBody;
      if (error.type == DioExceptionType.connectionError ||
          error.type == DioExceptionType.connectionTimeout) {
        return 'Sin conexión. Revisa tu internet e intenta de nuevo.';
      }
      return fallback;
    }

    var msg = error.toString();
    msg = msg.replaceFirst('Exception: ', '');
    if (msg.startsWith('DioException')) return fallback;
    return msg.isNotEmpty ? msg : fallback;
  }

  static String fromResponseData(dynamic data, String fallback) {
    if (data is Map) {
      final map = Map<String, dynamic>.from(data);
      for (final key in const ['message', 'error', 'mensaje']) {
        final v = map[key];
        if (v != null && v.toString().trim().isNotEmpty) {
          return v.toString().trim();
        }
      }
    }
    if (data is String && data.trim().isNotEmpty) {
      return data.trim();
    }
    return fallback;
  }
}
