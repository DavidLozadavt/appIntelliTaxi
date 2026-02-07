import 'package:dio/dio.dart';
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
        print('🔑 Token agregado a la solicitud');
      } else {
        print('⚠️ No se encontró token de autenticación');
      }
    } catch (e) {
      print('❌ Error en AuthInterceptor: $e');
    }

    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    // Si es un error 302 (redirección), podría ser problema de autenticación
    if (err.response?.statusCode == 302) {
      print(
        '🔄 Error 302: Posible problema de autenticación o sesión expirada',
      );
    }

    handler.next(err);
  }
}
