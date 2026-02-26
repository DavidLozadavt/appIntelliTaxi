import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:intellitaxi/features/auth/services/auth_interceptor.dart';
import 'package:intellitaxi/config/app_config.dart';
import 'package:intellitaxi/core/interceptors/retry_interceptor.dart';

class DioClient {
  static Dio? _dio;

  static Dio getInstance() {
    if (_dio == null) {
      _dio = Dio(
        BaseOptions(
          baseUrl: AppConfig.baseUrl,
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
          followRedirects: false, // No seguir redirecciones automáticamente
          validateStatus: (status) {
            // Aceptar respuestas 200-299
            // Temporalmente también aceptar 302 para ver el contenido de la redirección
            return status != null && status >= 200 && status < 400;
          },
          headers: {
            'Accept': 'application/json',
            'Content-Type': 'application/json',
          },
        ),
      );

      _dio!.interceptors.add(AuthInterceptor());
      _dio!.interceptors.add(RetryInterceptor(dio: _dio!));

      // Log interceptor solo en debug.
      if (kDebugMode) {
        _dio!.interceptors.add(
          LogInterceptor(
            requestBody: true,
            responseBody: true,
            error: true,
            requestHeader: true,
            responseHeader: false,
            request: false,
          ),
        );
      }
    }
    return _dio!;
  }
}
