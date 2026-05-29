import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:intellitaxi/config/app_config.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intellitaxi/core/bootstrap/session_preload.dart';
import 'package:intellitaxi/core/bootstrap/session_snapshot.dart';

import '../data/auth_model.dart';
import 'package:intellitaxi/core/services/app_logger.dart';

class AuthService {
  static SharedPreferences? _prefsCache;

  static Future<SharedPreferences> sharedPreferences() async {
    return _prefsCache ??= await SharedPreferences.getInstance();
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

  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: AppConfig.baseUrl,
      headers: {"Accept": "application/json"},
      connectTimeout: const Duration(seconds: 60),
      receiveTimeout: const Duration(seconds: 60),
    ),
  );

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

      return AuthResponse.fromJson(response.data);
    } on DioException catch (e) {
      throw Exception(
        _extractDioErrorMessage(
          e,
          fallback: 'No fue posible iniciar sesión. Intenta nuevamente.',
        ),
      );
    }
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

    return fallback;
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
  Future<void> clearSession() async {
    final prefs = await sharedPreferences();
    final token = prefs.getString('token');

    try {
      await _dio.post(
        "logout",
        options: Options(
          headers: {
            "Authorization": "Bearer $token", // 👈 Envía el token
          },
        ),
      );
    } catch (e) {
      // Opcional: manejar error si falla la petición
      AppLogger.d("Error en logout API: $e");
    }

    // 👈 Después de llamar a la API borras todo
    await prefs.remove('token');
    await prefs.remove('user_data');
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
