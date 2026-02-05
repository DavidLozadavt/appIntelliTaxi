import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../data/auth_model.dart';

class AuthProvider with ChangeNotifier {
  final AuthService _authService = AuthService();
  bool isLoading = false;

  AuthResponse? _authData;
  AuthResponse? get authData => _authData;

  User? get user => _authData?.user;
  Company? get company => _authData?.company;

  Persona? get persona => user?.persona;

  int? get activationId {
    return user?.activationCompanyUsers.isNotEmpty == true
        ? user!.activationCompanyUsers.first.id
        : null;
  }

  int? get userId => user?.id;
  int? get idPersona => persona?.id;

  List<String> get roles => _authData?.roles ?? [];
  List<String> get permissions => _authData?.permissions ?? [];
  bool get isAdmin => roles.contains('Admin');

  Future<bool> login(
    String email,
    String password,
    String deviceToken, {
    bool rememberMe = false,
  }) async {
    try {
      isLoading = true;
      notifyListeners();

      final AuthResponse response = await _authService.login(
        email,
        password,
        deviceToken,
      );

      _authData = response;
      await _authService.saveToken(response.token);
      await _authService.saveUserData(response);

      if (rememberMe) {
        await _authService.saveCredentials(email, password);
      } else {
        await _authService.clearCredentials();
      }

      isLoading = false;
      notifyListeners();

      return true;
    } catch (e) {
      isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> logout() async {
    try {
      isLoading = true;
      notifyListeners();

      await Future.delayed(const Duration(seconds: 2));

      await _authService.clearSession();
      _authData = null;

      isLoading = false;
      notifyListeners();
    } catch (e) {
      isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<String?> getSavedToken() async {
    return await _authService.getToken();
  }

  Future<void> loadUserFromStorage() async {
    _authData = await _authService.getSavedUserData();
    notifyListeners();
  }

  Future<Map<String, dynamic>?> getSavedCredentials() async {
    return await _authService.getSavedCredentials();
  }

  Future<bool> register({
    required String identificacion,
    required String nombre1,
    required String apellido1,
    required String fechaNac,
    required String direccion,
    required String email,
    required String celular,
    required String sexo,
    required int idTipoIdentificacion,
    required String password,
    required String passwordConfirmation,
    String? fotoPath,
  }) async {
    try {
      isLoading = true;
      notifyListeners();

      await _authService.register(
        identificacion: identificacion,
        nombre1: nombre1,
        apellido1: apellido1,
        fechaNac: fechaNac,
        direccion: direccion,
        email: email,
        celular: celular,
        sexo: sexo,
        idTipoIdentificacion: idTipoIdentificacion,
        password: password,
        passwordConfirmation: passwordConfirmation,
        fotoPath: fotoPath,
      );

      isLoading = false;
      notifyListeners();

      return true;
    } catch (e) {
      isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<bool> updateProfile({
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
      isLoading = true;
      notifyListeners();

      await _authService.updateProfile(
        personaId: personaId,
        identificacion: identificacion,
        nombre1: nombre1,
        apellido1: apellido1,
        fechaNac: fechaNac,
        direccion: direccion,
        email: email,
        celular: celular,
        sexo: sexo,
        idTipoIdentificacion: idTipoIdentificacion,
        fotoPath: fotoPath,
      );

      // Recargar datos del usuario
      await loadUserFromStorage();

      isLoading = false;
      notifyListeners();

      return true;
    } catch (e) {
      isLoading = false;
      notifyListeners();
      rethrow;
    }
  }
}
