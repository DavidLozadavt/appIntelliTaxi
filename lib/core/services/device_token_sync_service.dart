import 'dart:async';

import 'package:dio/dio.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:intellitaxi/config/app_config.dart';
import 'package:intellitaxi/core/dio_client.dart';
import 'package:intellitaxi/core/network/mobile_network_config.dart';
import 'package:intellitaxi/core/services/app_logger.dart';
import 'package:intellitaxi/core/services/fcm_token_resolver.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Sincroniza el token FCM con el backend cuando hay sesión activa.
///
/// Cubre: login sin token, FCM tardío en datos móviles lentos y [onTokenRefresh].
class DeviceTokenSyncService {
  DeviceTokenSyncService._();

  static final DeviceTokenSyncService instance = DeviceTokenSyncService._();

  static const _tag = 'DeviceToken';
  static const _prefsSyncedKey = 'synced_fcm_device_token';
  static const _prefsPendingKey = 'pending_fcm_device_token';
  static const _sessionTokenKey = 'token';

  bool _refreshListenerAttached = false;
  String? _syncInFlightToken;

  /// Escucha renovaciones de FCM (debe llamarse una vez al iniciar FCM).
  void attachTokenRefreshListener() {
    if (_refreshListenerAttached) return;
    _refreshListenerAttached = true;
    FirebaseMessaging.instance.onTokenRefresh.listen((token) {
      AppLogger.i('FCM onTokenRefresh → sincronizar backend', tag: _tag);
      unawaited(onTokenAvailable(token));
    });
  }

  /// Tras login: sincroniza el token enviado o uno pendiente / recién obtenido.
  Future<void> afterLogin({required String deviceTokenFromLogin}) async {
    final trimmed = deviceTokenFromLogin.trim();
    if (trimmed.isNotEmpty) {
      await onTokenAvailable(trimmed);
      return;
    }
    await flushPendingIfNeeded();
  }

  /// Token FCM disponible (arranque, refresh o login).
  Future<void> onTokenAvailable(String token) async {
    final normalized = token.trim();
    if (normalized.isEmpty) return;
    await _syncIfNeeded(normalized);
  }

  /// Reintenta token pendiente o pide uno nuevo a FCM (sesión ya guardada).
  Future<void> flushPendingIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    final pending = prefs.getString(_prefsPendingKey)?.trim();
    if (pending != null && pending.isNotEmpty) {
      await _syncIfNeeded(pending, force: true);
    }

    final session = prefs.getString(_sessionTokenKey);
    if (session == null || session.isEmpty) return;

    final fresh = await FcmTokenResolver.resolveForAuth(
      maxWait: MobileNetworkConfig.fcmMaxWaitBeforeLogin,
    );
    if (fresh != null) {
      await onTokenAvailable(fresh);
    }
  }

  /// Limpia estado local al cerrar sesión.
  Future<void> clearLocalCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsSyncedKey);
    await prefs.remove(_prefsPendingKey);
    _syncInFlightToken = null;
  }

  /// Desvincula el token FCM del usuario en el backend (antes de borrar la sesión).
  Future<void> unregisterFromBackend() async {
    final prefs = await SharedPreferences.getInstance();
    final session = prefs.getString(_sessionTokenKey)?.trim();
    if (session == null || session.isEmpty) {
      await clearLocalCache();
      return;
    }

    final path = AppConfig.deviceTokenSyncPath;
    try {
      await DioClient.getInstance().post(
        path,
        data: {'device_token': null},
        options: Options(
          headers: {'Authorization': 'Bearer $session'},
          sendTimeout: MobileNetworkConfig.userActionTimeout,
          receiveTimeout: MobileNetworkConfig.userActionTimeout,
          extra: const {'no_auth_refresh': true},
        ),
      );
      AppLogger.i('device_token desvinculado en logout', tag: _tag);
    } on DioException catch (e) {
      AppLogger.w(
        'No se pudo desvincular device_token (${e.response?.statusCode})',
        tag: _tag,
      );
    } catch (e) {
      AppLogger.w('No se pudo desvincular device_token: $e', tag: _tag);
    } finally {
      await clearLocalCache();
    }
  }

  Future<void> _syncIfNeeded(String fcmToken, {bool force = false}) async {
    if (_syncInFlightToken == fcmToken) return;
    _syncInFlightToken = fcmToken;

    try {
      final prefs = await SharedPreferences.getInstance();
      final session = prefs.getString(_sessionTokenKey);
      if (session == null || session.isEmpty) {
        await prefs.setString(_prefsPendingKey, fcmToken);
        AppLogger.d('FCM guardado en cola (sin sesión)', tag: _tag);
        return;
      }

      if (!force) {
        final lastSynced = prefs.getString(_prefsSyncedKey);
        if (lastSynced == fcmToken) return;
      }

      final ok = await _postToBackend(fcmToken);
      if (ok) {
        await prefs.setString(_prefsSyncedKey, fcmToken);
        await prefs.remove(_prefsPendingKey);
        AppLogger.i('device_token sincronizado con el backend', tag: _tag);
      } else {
        await prefs.setString(_prefsPendingKey, fcmToken);
      }
    } finally {
      if (_syncInFlightToken == fcmToken) {
        _syncInFlightToken = null;
      }
    }
  }

  Future<bool> _postToBackend(String fcmToken) async {
    final path = AppConfig.deviceTokenSyncPath;
    try {
      await DioClient.getInstance().post(
        path,
        data: {'device_token': fcmToken},
        options: Options(
          sendTimeout: MobileNetworkConfig.userActionTimeout,
          receiveTimeout: MobileNetworkConfig.userActionTimeout,
        ),
      );
      return true;
    } on DioException catch (e, st) {
      final status = e.response?.statusCode;
      if (status == 404) {
        AppLogger.w(
          'Ruta $path no existe (404). Configura DEVICE_TOKEN_SYNC_PATH en .env o crea el endpoint en Laravel.',
          tag: _tag,
        );
      } else {
        AppLogger.e(
          'Error sincronizando device_token ($status)',
          tag: _tag,
          error: e,
          stackTrace: st,
        );
      }
      return false;
    } catch (e, st) {
      AppLogger.e(
        'Error sincronizando device_token',
        tag: _tag,
        error: e,
        stackTrace: st,
      );
      return false;
    }
  }
}
