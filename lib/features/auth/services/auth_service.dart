import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:intellitaxi/config/app_config.dart';
import 'package:intellitaxi/core/interceptors/retry_interceptor.dart';
import 'package:intellitaxi/core/network/mobile_network_config.dart';
import 'package:intellitaxi/core/services/device_token_sync_service.dart';
import 'package:intellitaxi/core/services/fcm_logout_cleanup.dart';
import 'package:intellitaxi/core/utils/dio_error_message.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intellitaxi/core/bootstrap/session_preload.dart';
import 'package:intellitaxi/core/bootstrap/session_snapshot.dart';

import '../data/auth_model.dart';
import '../data/auth_session.dart';
import 'package:intellitaxi/core/services/app_logger.dart';

class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();
  factory AuthService() => instance;

  static const _keyExpiresAt = 'expires_at_iso';

  static SharedPreferences? _prefsCache;

  static Future<SharedPreferences> sharedPreferences() async {
    return _prefsCache ??= await SharedPreferences.getInstance();
  }

  static void invalidatePrefsCache() {
    _prefsCache = null;
  }

  /// Una sola lectura de prefs: token + JSON de usuario + rol activo.
  static Future<SessionSnapshot> readSessionSnapshot() async {
    final prefs = await sharedPreferences();
    final token = prefs.getString('token');
    final raw = prefs.getString('user_data');
    AuthResponse? auth;
    if (raw != null && raw.isNotEmpty) {
      try {
        auth = AuthResponse.fromJson(
          jsonDecode(raw) as Map<String, dynamic>,
        );
      } catch (_) {
        auth = null;
      }
    }
    return SessionSnapshot(
      token: token,
      authResponse: auth,
      storedActiveRole: prefs.getString('active_role'),
    );
  }

  final Dio _dio = () {
    final dio = Dio(
      BaseOptions(
        baseUrl: AppConfig.baseUrl,
        headers: {"Accept": "application/json"},
        connectTimeout: MobileNetworkConfig.httpConnectTimeout,
        receiveTimeout: MobileNetworkConfig.httpReceiveTimeout,
        sendTimeout: MobileNetworkConfig.httpSendTimeout,
      ),
    );
    dio.interceptors.add(
      RetryInterceptor(
        dio: dio,
        maxRetries: MobileNetworkConfig.httpMaxRetries,
        baseDelay: MobileNetworkConfig.httpRetryBaseDelay,
      ),
    );
    return dio;
  }();

  /// 📌 LOGIN
  Future<AuthResponse> login(String email, String password, deviceToken) async {
    try {
      final response = await _dio.post(
        'login',
        data: {
          'email': email,
          'password': password,
          'device_token': deviceToken,
        },
      );

      final auth = AuthResponse.fromJson(
        response.data as Map<String, dynamic>,
      );
      await _persistSession(auth);
      return auth;
    } on DioException catch (e) {
      throw Exception(
        _extractDioErrorMessage(
          e,
          fallback: 'No fue posible iniciar sesión. Intenta nuevamente.',
        ),
      );
    }
  }

  /// Renueva JWT (`POST auth/refresh`). El token del header puede estar expirado.
  Future<AuthResponse?> refresh({
    String? deviceToken,
    bool isRetry = false,
  }) async {
    final token = await getToken();
    if (token == null || token.isEmpty) return null;

    try {
      final response = await _dio.post(
        'auth/refresh',
        data: deviceToken != null && deviceToken.isNotEmpty
            ? {'device_token': deviceToken}
            : null,
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
          extra: const {'no_auth_refresh': true},
        ),
      );

      final data = response.data;
      if (data is! Map<String, dynamic>) return null;
      if (data['success'] != true) return null;

      final auth = AuthResponse.fromJson(data);
      await _persistSession(auth);
      return auth;
    } on DioException catch (e) {
      final code = _errorCode(e);
      AppLogger.w(
        'auth/refresh falló status=${e.response?.statusCode} code=$code',
        tag: 'AuthService',
      );
      if (_isTerminalRefreshError(e, code)) return null;
      if (!isRetry &&
          e.response?.statusCode == 500 &&
          code == 'refresh_failed') {
        await Future<void>.delayed(const Duration(milliseconds: 800));
        return refresh(deviceToken: deviceToken, isRetry: true);
      }
      return null;
    }
  }

  /// Al abrir la app: renueva si el token expira pronto (evita 401 en bloque).
  Future<void> ensureValidSession({String? deviceToken}) async {
    final token = await getToken();
    if (token == null || token.isEmpty) return;

    final timing = await readSessionTiming();
    if (timing == null || !timing.shouldRefreshSoon) return;

    try {
      await refresh(deviceToken: deviceToken);
    } catch (_) {
      // El interceptor atenderá el siguiente 401.
    }
  }

  Future<AuthSessionTiming?> readSessionTiming() async {
    final iso = await getExpiresAtIso();
    if (iso == null || iso.isEmpty) return null;
    try {
      return AuthSessionTiming.fromStoredIso(iso);
    } catch (_) {
      return null;
    }
  }

  String? _errorCode(DioException e) {
    final data = e.response?.data;
    if (data is Map<String, dynamic>) {
      return data['code'] as String?;
    }
    return null;
  }

  bool _isTerminalRefreshError(DioException e, String? code) {
    final status = e.response?.statusCode;
    if (status == 403 && code == 'account_inactive') return true;
    if (status != 401) return false;
    return code == null ||
        code == 'token_missing' ||
        code == 'token_invalid' ||
        code == 'refresh_expired' ||
        code == 'user_not_found';
  }

  Future<void> _persistSession(AuthResponse response) async {
    await saveToken(response.token);
    if (response.expiresAt != null) {
      await saveExpiresAt(response.expiresAt!);
    }
    await saveUserData(response);
  }

  /// 📌 REGISTER
  Future<Map<String, dynamic>> register({
    required String nombre1,
    required String apellido1,
    required String direccion,
    required String email,
    required String celular,
    required String password,
    required String passwordConfirmation,
    String? fotoPath,
  }) async {
    try {
      FormData formData = FormData.fromMap({
        'nombre1': nombre1,
        'apellido1': apellido1,
        'direccion': direccion,
        'email': email,
        'celular': celular,
        'password': password,
        'password_confirmation': passwordConfirmation,
        if (fotoPath != null)
          'foto': await MultipartFile.fromFile(fotoPath, filename: 'photo.jpg'),
      });

      final response = await _dio.post('register_passenger', data: formData);

      return response.data;
    } on DioException catch (e) {
      throw Exception(
        _extractDioErrorMessage(e, fallback: 'Error en el registro'),
      );
    }
  }

  /// 📌 UPDATE PROFILE
  Future<Map<String, dynamic>> updateProfile({
    required int personaId,
    required String identificacion,
    required String nombre1,
    required String apellido1,
    required String fechaNac,
    required String direccion,
    required String email,
    required String celular,
    required String sexo,
    required int idTipoIdentificacion,
    String? fotoPath,
  }) async {
    try {
      final token = await getToken();

      FormData formData = FormData.fromMap({
        'identificacion': identificacion,
        'nombre1': nombre1,
        'apellido1': apellido1,
        'fechaNac': fechaNac,
        'direccion': direccion,
        'email': email,
        'celular': celular,
        'sexo': sexo,
        'idTipoIdentificacion': idTipoIdentificacion,
        // '_method': 'POST',
        if (fotoPath != null)
          'foto': await MultipartFile.fromFile(fotoPath, filename: 'photo.jpg'),
      });

      final response = await _dio.post(
        'update_passenger_profile',
        data: formData,
        options: Options(headers: {"Authorization": "Bearer $token"}),
      );

      return response.data;
    } on DioException catch (e) {
      throw Exception(
        _extractDioErrorMessage(e, fallback: 'Error al actualizar perfil'),
      );
    }
  }

  String _extractDioErrorMessage(DioException e, {required String fallback}) {
    final data = e.response?.data;
    AppLogger.d('AuthService DioException status=${e.response?.statusCode}');
    AppLogger.d('AuthService DioException body=$data');

    if (data is Map<String, dynamic>) {
      final detailedError = _extractFirstValidationError(data['errors']) ??
          _extractFirstValidationError(data['details']);
      if (detailedError != null) {
        return detailedError;
      }

      final backendError = data['error'];
      if (backendError is String && backendError.trim().isNotEmpty) {
        return backendError;
      }

      final backendMessage = data['message'];
      if (backendMessage is String && backendMessage.trim().isNotEmpty) {
        return backendMessage;
      }

    }

    if (data is String && data.trim().isNotEmpty) {
      return data;
    }

    return DioErrorMessage.from(e, fallback: fallback);
  }

  String? _extractFirstValidationError(dynamic source) {
    if (source is! Map || source.isEmpty) return null;
    final firstValue = source.values.first;
    if (firstValue is List && firstValue.isNotEmpty) {
      final firstError = firstValue.first;
      if (firstError is String && firstError.trim().isNotEmpty) {
        return firstError;
      }
    }
    if (firstValue is String && firstValue.trim().isNotEmpty) {
      return firstValue;
    }
    return null;
  }

  /// 📌 Guardar token
  Future<void> saveToken(String token) async {
    final prefs = await sharedPreferences();
    await prefs.setString('token', token);
    SessionPreload.invalidate();
  }

  Future<void> saveExpiresAt(DateTime expiresAt) async {
    final prefs = await sharedPreferences();
    await prefs.setString(_keyExpiresAt, expiresAt.toIso8601String());
    SessionPreload.invalidate();
  }

  Future<String?> getExpiresAtIso() async {
    final prefs = await sharedPreferences();
    return prefs.getString(_keyExpiresAt);
  }

  /// 📌 Obtener token
  Future<String?> getToken() async {
    final prefs = await sharedPreferences();
    return prefs.getString('token');
  }

  /// 📌 Guardar datos completos del usuario
  Future<void> saveUserData(AuthResponse response) async {
    final prefs = await sharedPreferences();
    final jsonString = jsonEncode(response.toJson());
    await prefs.setString('user_data', jsonString);
    SessionPreload.invalidate();
  }

  /// 📌 Obtener datos guardados del usuario
  Future<AuthResponse?> getSavedUserData() async {
    final snap = await readSessionSnapshot();
    return snap.authResponse;
  }

  /// 📌 Cerrar sesión y limpiar todo
  Future<void> clearSession({bool skipLogoutApi = false}) async {
    final prefs = await sharedPreferences();
    final token = prefs.getString('token');

    await DeviceTokenSyncService.instance.unregisterFromBackend();

    if (!skipLogoutApi && token != null && token.isNotEmpty) {
      try {
        await _dio.post(
          'logout',
          options: Options(
            headers: {'Authorization': 'Bearer $token'},
            extra: const {'no_auth_refresh': true},
          ),
        );
      } catch (e) {
        AppLogger.d('Error en logout API: $e');
      }
    }

    await prefs.remove('token');
    await prefs.remove('user_data');
    await prefs.remove(_keyExpiresAt);
    await prefs.remove('active_role');
    await DeviceTokenSyncService.instance.clearLocalCache();
    await FcmLogoutCleanup.run();
    SessionPreload.invalidate();
  }

  /// 📌 Guardar credenciales si el usuario marcó "Recuérdame"
  Future<void> saveCredentials(String email, String password) async {
    final prefs = await sharedPreferences();
    await prefs.setString('saved_email', email);
    await prefs.setString('saved_password', password);
    await prefs.setBool('remember_me', true);
  }

  /// 📌 Obtener credenciales guardadas
  Future<Map<String, dynamic>?> getSavedCredentials() async {
    final prefs = await sharedPreferences();
    final remember = prefs.getBool('remember_me') ?? false;

    if (remember) {
      return {
        'email': prefs.getString('saved_email') ?? '',
        'password': prefs.getString('saved_password') ?? '',
      };
    }
    return null;
  }

  /// 📌 Limpiar credenciales si no quiere recordar
  Future<void> clearCredentials() async {
    final prefs = await sharedPreferences();
    await prefs.remove('saved_email');
    await prefs.remove('saved_password');
    await prefs.remove('remember_me');
  }
}
