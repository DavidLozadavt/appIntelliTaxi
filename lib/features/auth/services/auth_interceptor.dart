import 'package:dio/dio.dart';
import 'package:intellitaxi/core/perf/runtime_perf_flags.dart';
import 'package:intellitaxi/core/services/app_logger.dart';
import 'package:intellitaxi/features/auth/data/auth_model.dart';
import 'package:intellitaxi/features/auth/services/auth_service.dart';

/// Añade Bearer y, ante 401, renueva con `POST auth/refresh` y reintenta una vez.
class AuthInterceptor extends QueuedInterceptor {
  AuthInterceptor({
    required Dio dio,
    AuthService? authService,
  })  : _dio = dio,
        _auth = authService ?? AuthService.instance;

  final Dio _dio;
  final AuthService _auth;

  static void Function(AuthResponse response)? onSessionRefreshed;
  static Future<void> Function()? onSessionExpired;

  bool _isRefreshing = false;
  final List<({RequestOptions options, ErrorInterceptorHandler handler})> _queue =
      [];

  static bool _isAuthRoute(String path) {
    return path.contains('login') || path.contains('auth/refresh');
  }

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (_isAuthRoute(options.path)) {
      return handler.next(options);
    }

    try {
      final token = await _auth.getToken();
      if (token != null && token.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $token';
        if (RuntimePerfFlags.logAuthInterceptor) {
          AppLogger.d('Bearer en solicitud', tag: 'AuthInterceptor');
        }
      }
    } catch (e) {
      AppLogger.e('Error en AuthInterceptor', tag: 'AuthInterceptor', error: e);
    }

    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final status = err.response?.statusCode;
    final path = err.requestOptions.path;
    final alreadyRetried = err.requestOptions.extra['auth_retry'] == true;

    if (status == 302) {
      AppLogger.w(
        '302: posible sesión expirada',
        tag: 'AuthInterceptor',
      );
    }

    if (status != 401 ||
        alreadyRetried ||
        _isAuthRoute(path) ||
        err.requestOptions.extra['no_auth_refresh'] == true) {
      return handler.next(err);
    }

    if (_isRefreshing) {
      _queue.add((options: err.requestOptions, handler: handler));
      return;
    }

    _isRefreshing = true;
    try {
      final session = await _auth.refresh();
      if (session == null) {
        await onSessionExpired?.call();
        return handler.next(err);
      }

      onSessionRefreshed?.call(session);

      final opts = err.requestOptions;
      opts.headers['Authorization'] = 'Bearer ${session.token}';
      opts.extra['auth_retry'] = true;

      final response = await _dio.fetch(opts);
      handler.resolve(response);

      for (final item in _queue) {
        item.options.headers['Authorization'] = 'Bearer ${session.token}';
        item.options.extra['auth_retry'] = true;
        try {
          final r = await _dio.fetch(item.options);
          item.handler.resolve(r);
        } catch (e) {
          item.handler.next(e is DioException ? e : err);
        }
      }
      _queue.clear();
    } catch (e, st) {
      AppLogger.e(
        'Refresh falló',
        tag: 'AuthInterceptor',
        error: e,
        stackTrace: st,
      );
      await onSessionExpired?.call();
      handler.next(err);
    } finally {
      _isRefreshing = false;
    }
  }
}
