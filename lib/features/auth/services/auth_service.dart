import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:intellitaxi/config/app_config.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/auth_model.dart';

class AuthService {
  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: AppConfig.baseUrl,
      headers: {"Accept": "application/json"},
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
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
      throw Exception(e.response?.data['message'] ?? 'Error de conexión');
    }
  }

  /// 📌 Guardar token
  Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', token);
  }

  /// 📌 Obtener token
  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  /// 📌 Guardar datos completos del usuario
  Future<void> saveUserData(AuthResponse response) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = jsonEncode(response.toJson());
    await prefs.setString('user_data', jsonString);
  }

  /// 📌 Obtener datos guardados del usuario
  Future<AuthResponse?> getSavedUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString('user_data');
    if (jsonString != null) {
      final Map<String, dynamic> jsonMap = jsonDecode(jsonString);
      return AuthResponse.fromJson(jsonMap);
    }
    return null;
  }

  /// 📌 Cerrar sesión y limpiar todo
  Future<void> clearSession() async {
  final prefs = await SharedPreferences.getInstance();
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
    print("Error en logout API: $e");
  }

  // 👈 Después de llamar a la API borras todo
  await prefs.remove('token');
  await prefs.remove('user_data');
}


  /// 📌 Guardar credenciales si el usuario marcó "Recuérdame"
  Future<void> saveCredentials(String email, String password) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('saved_email', email);
    await prefs.setString('saved_password', password);
    await prefs.setBool('remember_me', true);
  }

  /// 📌 Obtener credenciales guardadas
  Future<Map<String, dynamic>?> getSavedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
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
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('saved_email');
    await prefs.remove('saved_password');
    await prefs.remove('remember_me');
  }
}
