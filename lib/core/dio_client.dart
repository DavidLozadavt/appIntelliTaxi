import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:intellitaxi/config/app_config.dart';
import 'package:intellitaxi/core/interceptors/retry_interceptor.dart';
import 'package:intellitaxi/core/network/mobile_network_config.dart';
import 'package:intellitaxi/core/perf/runtime_perf_flags.dart';
import 'package:intellitaxi/features/auth/services/auth_interceptor.dart';

class DioClient {
  static Dio? _dio;

  static Dio getInstance() {
    if (_dio == null) {
      _dio = Dio(
        BaseOptions(
          baseUrl: AppConfig.baseUrl,
          connectTimeout: MobileNetworkConfig.httpConnectTimeout,
          receiveTimeout: MobileNetworkConfig.httpReceiveTimeout,
          sendTimeout: MobileNetworkConfig.httpSendTimeout,
          followRedirects: false, // No seguir redirecciones automáticamente
          validateStatus: (status) {
            // 404 en servicio-activo / latestVersion es respuesta de negocio, no error HTTP.
            return status != null && status < 500;
          },
          headers: {
            'Accept': 'application/json',
            'Content-Type': 'application/json',
          },
        ),
      );

      _dio!.interceptors.add(AuthInterceptor());
      _dio!.interceptors.add(
        RetryInterceptor(
          dio: _dio!,
          maxRetries: MobileNetworkConfig.httpMaxRetries,
          baseDelay: MobileNetworkConfig.httpRetryBaseDelay,
        ),
      );

      if (kDebugMode && RuntimePerfFlags.verboseHttpLogs) {
        _dio!.interceptors.add(
          LogInterceptor(
            requestBody: false,
            responseBody: false,
            error: true,
            requestHeader: false,
            responseHeader: false,
            logPrint: _truncatedDioLog,
          ),
        );
      }
    }
    return _dio!;
  }

  static void _truncatedDioLog(Object object) {
    const maxLen = 280;
    final text = object.toString();
    if (text.length <= maxLen) {
      debugPrint(text);
      return;
    }
    debugPrint('${text.substring(0, maxLen)}… [+${text.length - maxLen} chars]');
  }
}
