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
      if (status == 429) {
        return 'Demasiadas peticiones. Espera un momento e intenta de nuevo.';
      }
      if (status != null && status >= 500 && status < 600) {
        final fromBody = fromResponseData(error.response?.data, '');
        if (fromBody.isNotEmpty) return fromBody;
        return 'El servidor no respondió bien. Intenta de nuevo en unos minutos.';
      }
      if (status == 404) {
        final fromBody = fromResponseData(error.response?.data, '');
        if (fromBody.isNotEmpty) return fromBody;
        return fallback;
      }
      final fromBody = fromResponseData(error.response?.data, '');
      if (fromBody.isNotEmpty) return fromBody;
      if (error.type == DioExceptionType.connectionError ||
          error.type == DioExceptionType.connectionTimeout) {
        return 'Sin conexión. Revisa tu internet e intenta de nuevo.';
      }
      if (error.type == DioExceptionType.receiveTimeout ||
          error.type == DioExceptionType.sendTimeout) {
        return 'La red móvil está lenta. Espera un momento e intenta de nuevo.';
      }
      if (error.type == DioExceptionType.badResponse) {
        return fallback;
      }
      return fallback;
    }

    return _sanitizePlainError(error, fallback);
  }

  static String _sanitizePlainError(Object error, String fallback) {
    var msg = error.toString().replaceFirst('Exception: ', '').trim();
    if (_looksLikeTechnicalDump(msg)) return fallback;
    return msg.isNotEmpty ? msg : fallback;
  }

  static bool _looksLikeTechnicalDump(String msg) {
    final lower = msg.toLowerCase();
    return lower.startsWith('dioexception') ||
        lower.contains('validatestatus') ||
        lower.contains('status code of') ||
        lower.contains('requestoptions') ||
        lower.contains('developer.mozilla.org');
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
