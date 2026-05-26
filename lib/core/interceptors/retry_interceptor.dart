import 'dart:math';

import 'package:dio/dio.dart';

class RetryInterceptor extends Interceptor {
  RetryInterceptor({
    required Dio dio,
    this.maxRetries = 2,
    this.baseDelay = const Duration(milliseconds: 350),
  }) : _dio = dio;

  final Dio _dio;
  final int maxRetries;
  final Duration baseDelay;

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final options = err.requestOptions;
    final retries = (options.extra['retry_attempt'] as int?) ?? 0;

    if (!_shouldRetry(err) || retries >= maxRetries) {
      return handler.next(err);
    }

    options.extra['retry_attempt'] = retries + 1;

    final jitter = Random().nextInt(200);
    final factor = pow(2, retries).toInt();
    final delay = Duration(
      milliseconds: baseDelay.inMilliseconds * factor + jitter,
    );
    await Future.delayed(delay);

    try {
      final response = await _dio.fetch(options);
      return handler.resolve(response);
    } on DioException catch (e) {
      return handler.next(e);
    }
  }

  bool _shouldRetry(DioException err) {
    if (err.requestOptions.extra['no_retry'] == true) return false;

    final status = err.response?.statusCode ?? 0;
    if (status >= 500) return true;

    return err.type == DioExceptionType.connectionError ||
        err.type == DioExceptionType.connectionTimeout ||
        err.type == DioExceptionType.receiveTimeout ||
        err.type == DioExceptionType.sendTimeout ||
        err.type == DioExceptionType.unknown;
  }
}
