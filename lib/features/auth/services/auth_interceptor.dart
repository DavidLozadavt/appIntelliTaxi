import 'package:dio/dio.dart';
import 'package:intellitaxi/core/services/app_logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthInterceptor extends Interceptor {
  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token != null && token.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $token';
        AppLogger.d('Token agregado a la solicitud', tag: 'AuthInterceptor');
      } else {
        AppLogger.w(
          'No se encontró token de autenticación',
          tag: 'AuthInterceptor',
        );
      }
    } catch (e) {
      AppLogger.e('Error en AuthInterceptor', tag: 'AuthInterceptor', error: e);
    }

    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    // Si es un error 302 (redirección), podría ser problema de autenticación
    if (err.response?.statusCode == 302) {
      AppLogger.w(
        'Error 302: Posible problema de autenticación o sesión expirada',
        tag: 'AuthInterceptor',
      );
    }

    handler.next(err);
  }
}
