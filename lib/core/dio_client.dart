import 'package:dio/dio.dart';
import 'package:intellitaxi/features/auth/services/auth_interceptor.dart';
import 'package:intellitaxi/config/app_config.dart';

class DioClient {
  static Dio? _dio;

  static Dio getInstance() {
    if (_dio == null) {
      _dio = Dio(
        BaseOptions(
          baseUrl: AppConfig.baseUrl,
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
        ),
      );

      _dio!.interceptors.add(AuthInterceptor());
    }
    return _dio!;
  }
}
