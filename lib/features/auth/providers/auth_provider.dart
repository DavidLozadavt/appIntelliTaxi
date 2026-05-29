import 'package:flutter/material.dart';
import 'package:intellitaxi/core/services/active_service_check_cache.dart';
import 'package:intellitaxi/features/rides/services/active_service_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';
import '../data/auth_model.dart';

class AuthProvider with ChangeNotifier {
  static const String roleConductor = 'CONDUCTOR-INTELLITAXI';
  static const String rolePasajero = 'PASAJERO-INTELLITAXI';
  final AuthService _authService = AuthService();
  static const String _activeRoleKey = 'active_role';
  bool isLoading = false;

  AuthResponse? _authData;
  AuthResponse? get authData => _authData;
  String? _activeRole;
  String? get activeRole => _activeRole;

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
  bool get hasConductorRole => roles.any(_isConductorRole);
  bool get hasPasajeroRole => roles.any(_isPasajeroRole);
  bool get canSwitchRole =>
      _availableAppRoles.contains(roleConductor) &&
      _availableAppRoles.contains(rolePasajero);
  List<String> get _availableAppRoles {
    final result = <String>[];
    if (hasConductorRole) result.add(roleConductor);
    if (hasPasajeroRole) result.add(rolePasajero);
    return result;
  }

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
      await _syncActiveRoleFromStorage();

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
      ActiveServiceCheckCache.invalidate();
      ActiveServiceManager.invalidateFetchCache();
      _authData = null;
      _activeRole = null;
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_activeRoleKey);

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
    await _syncActiveRoleFromStorage();
    notifyListeners();
  }

  Future<Map<String, dynamic>?> getSavedCredentials() async {
    return await _authService.getSavedCredentials();
  }

  Future<bool> register({
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
      isLoading = true;
      notifyListeners();

      await _authService.register(
        nombre1: nombre1,
        apellido1: apellido1,
        direccion: direccion,
        email: email,
        celular: celular,
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

      final response = await _authService.updateProfile(
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

      _applyProfileUpdateToSession(
        response: response,
        identificacion: identificacion,
        nombre1: nombre1,
        apellido1: apellido1,
        fechaNac: fechaNac,
        direccion: direccion,
        email: email,
        celular: celular,
        sexo: sexo,
        idTipoIdentificacion: idTipoIdentificacion,
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

  void _applyProfileUpdateToSession({
    required Map<String, dynamic> response,
    required String identificacion,
    required String nombre1,
    required String apellido1,
    required String fechaNac,
    required String direccion,
    required String email,
    required String celular,
    required String sexo,
    required int idTipoIdentificacion,
  }) {
    if (_authData == null) return;

    final authMap = _authData!.toJson();
    final userMap =
        (authMap['user'] as Map<String, dynamic>?) ?? <String, dynamic>{};
    final personaMap =
        (userMap['persona'] as Map<String, dynamic>?) ?? <String, dynamic>{};

    personaMap['identificacion'] = identificacion;
    personaMap['nombre1'] = nombre1;
    personaMap['apellido1'] = apellido1;
    personaMap['fechaNac'] = fechaNac;
    personaMap['direccion'] = direccion;
    personaMap['email'] = email;
    personaMap['celular'] = celular;
    personaMap['sexo'] = sexo;
    personaMap['idTipoIdentificacion'] = idTipoIdentificacion;
    userMap['email'] = email;

    final personaUpdated = _extractPersonaFromUpdateResponse(response);
    if (personaUpdated != null) {
      personaMap.addAll(personaUpdated);
    }

    userMap['persona'] = personaMap;
    authMap['user'] = userMap;

    _authData = AuthResponse.fromJson(authMap);
    _authService.saveUserData(_authData!);
  }

  Map<String, dynamic>? _extractPersonaFromUpdateResponse(
    Map<String, dynamic> response,
  ) {
    final user = response['user'];
    if (user is Map && user['persona'] is Map) {
      return Map<String, dynamic>.from(user['persona'] as Map);
    }

    final data = response['data'];
    if (data is Map && data['user'] is Map) {
      final userData = data['user'] as Map;
      if (userData['persona'] is Map) {
        return Map<String, dynamic>.from(userData['persona'] as Map);
      }
    }

    return null;
  }

  Future<void> setActiveRole(String role) async {
    final normalized = _normalizeAppRole(role);
    if (!_availableAppRoles.contains(normalized)) return;
    if (_activeRole == normalized) return;

    _activeRole = normalized;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_activeRoleKey, normalized);
    notifyListeners();
  }

  Future<void> _syncActiveRoleFromStorage() async {
    if (_authData == null) {
      _activeRole = null;
      return;
    }

    final available = _availableAppRoles;
    if (available.isEmpty) {
      _activeRole = null;
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final storedRaw = prefs.getString(_activeRoleKey);
    final stored = storedRaw == null ? null : _normalizeAppRole(storedRaw);

    if (stored != null && available.contains(stored)) {
      _activeRole = stored;
      return;
    }

    if (available.length == 1) {
      _activeRole = available.first;
      await prefs.setString(_activeRoleKey, _activeRole!);
      return;
    }

    // Si tiene ambos roles y aún no eligió uno, forzar selección en UI.
    _activeRole = null;
    await prefs.remove(_activeRoleKey);
  }

  bool _isConductorRole(String role) {
    final r = role.toUpperCase();
    return r == roleConductor ||
        r == 'CONDUCTOR' ||
        r == 'MOTORISTA' ||
        r == 'DRIVER';
  }

  bool _isPasajeroRole(String role) {
    final r = role.toUpperCase();
    return r == rolePasajero ||
        r == 'PASAJERO' ||
        r == 'PASSENGER' ||
        r == 'CLIENTE';
  }

  String _normalizeAppRole(String role) {
    if (_isConductorRole(role)) return roleConductor;
    if (_isPasajeroRole(role)) return rolePasajero;
    return role.toUpperCase();
  }
}
