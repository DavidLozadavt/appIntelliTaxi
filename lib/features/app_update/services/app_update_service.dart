import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intellitaxi/config/app_config.dart';
import 'package:intellitaxi/core/dio_client.dart';
import 'package:intellitaxi/core/services/app_logger.dart';
import 'package:intellitaxi/features/app_update/data/app_version_dto.dart';
import 'package:intellitaxi/features/app_update/widgets/app_update_download_dialog.dart';
import 'package:intellitaxi/features/app_update/widgets/app_update_dialog.dart';
import 'package:intellitaxi/main.dart';

class AppUpdateCheckResult {
  const AppUpdateCheckResult({
    required this.updateAvailable,
    required this.shouldBlock,
    this.remoteVersion,
  });

  final bool updateAvailable;
  final bool shouldBlock;
  final AppVersionDto? remoteVersion;
}

class AppUpdateService with WidgetsBindingObserver {
  AppUpdateService._();

  static final AppUpdateService instance = AppUpdateService._();
  static const MethodChannel _installerChannel = MethodChannel(
    'com.virtualt.intellitaxi/app_update',
  );

  final Dio _dio = DioClient.getInstance();
  bool _isDialogVisible = false;
  String? _visibleVersion;
  AppVersionDto? _pendingForcedVersion;
  bool _observerRegistered = false;

  Future<AppVersionDto?> getLatestVersion() async {
    try {
      final response = await _dio.get('app/latestVersion');
      if (response.statusCode == 404) return null;
      if (response.statusCode != 200 || response.data == null) {
        AppLogger.w(
          'Respuesta inesperada consultando latestVersion: ${response.statusCode}',
          tag: 'AppUpdate',
        );
        return null;
      }

      final data = Map<String, dynamic>.from(response.data as Map);
      final dto = AppVersionDto.fromJson(data);
      return dto.version.isEmpty ? null : dto;
    } on DioException catch (e, st) {
      if (e.response?.statusCode == 404) return null;
      AppLogger.e(
        'Error consultando latestVersion',
        tag: 'AppUpdate',
        error: e,
        stackTrace: st,
      );
      return null;
    } catch (e, st) {
      AppLogger.e(
        'Error parseando latestVersion',
        tag: 'AppUpdate',
        error: e,
        stackTrace: st,
      );
      return null;
    }
  }

  Future<AppUpdateCheckResult> checkForUpdate({
    AppVersionDto? remoteOverride,
  }) async {
    _ensureObserverRegistered();
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final localVersion = packageInfo.version.trim();
      final remoteVersion = remoteOverride ?? await getLatestVersion();

      if (remoteVersion == null) {
        return const AppUpdateCheckResult(
          updateAvailable: false,
          shouldBlock: false,
        );
      }

      final updateAvailable = isNewerVersion(
        localVersion,
        remoteVersion.version,
      );
      if (!updateAvailable) {
        _clearPendingForcedUpdateIfMatched(localVersion);
        return AppUpdateCheckResult(
          updateAvailable: false,
          shouldBlock: false,
          remoteVersion: remoteVersion,
        );
      }

      _pendingForcedVersion = remoteVersion.forceUpdate ? remoteVersion : null;
      await _showUpdateDialog(versionInfo: remoteVersion);

      return AppUpdateCheckResult(
        updateAvailable: true,
        shouldBlock: remoteVersion.forceUpdate,
        remoteVersion: remoteVersion,
      );
    } catch (e, st) {
      AppLogger.e(
        'Error validando actualización',
        tag: 'AppUpdate',
        error: e,
        stackTrace: st,
      );
      return const AppUpdateCheckResult(
        updateAvailable: false,
        shouldBlock: false,
      );
    }
  }

  Future<void> handlePushData(Map<String, dynamic> data) async {
    _ensureObserverRegistered();
    final type = data['type']?.toString().toLowerCase().trim();
    final tipo = data['tipo']?.toString().toLowerCase().trim();
    if (type != 'app_update' && tipo != 'app_update') {
      return;
    }

    final remoteVersion = AppVersionDto.fromJson(data);
    if (remoteVersion.version.isEmpty) {
      AppLogger.w('Push app_update recibido sin versión', tag: 'AppUpdate');
      return;
    }

    if (remoteVersion.forceUpdate) {
      _pendingForcedVersion = remoteVersion;
    }
    await checkForUpdate(remoteOverride: remoteVersion);
  }

  bool isNewerVersion(String local, String remote) {
    final localParts = _parseVersion(local);
    final remoteParts = _parseVersion(remote);
    final maxLength = localParts.length > remoteParts.length
        ? localParts.length
        : remoteParts.length;

    for (var i = 0; i < maxLength; i++) {
      final localValue = i < localParts.length ? localParts[i] : 0;
      final remoteValue = i < remoteParts.length ? remoteParts[i] : 0;
      if (remoteValue > localValue) return true;
      if (remoteValue < localValue) return false;
    }

    return false;
  }

  Future<void> openApkUrl(
    BuildContext context,
    AppVersionDto versionInfo,
  ) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final apkUrl = versionInfo.apkUrl?.trim();
    if (apkUrl == null || apkUrl.isEmpty) {
      _showSnackBar(messenger, 'No hay URL de descarga disponible.');
      return;
    }

    final uri = _resolveApkUri(apkUrl);
    if (uri == null) {
      _showSnackBar(messenger, 'La URL de descarga no es válida.');
      return;
    }

    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);

    if (!launched) {
      _showSnackBar(messenger, 'No se pudo abrir la descarga del APK.');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    final pendingVersion = _pendingForcedVersion;
    if (pendingVersion == null || _isDialogVisible) return;
    Future<void>.delayed(const Duration(milliseconds: 500), () async {
      if (_isDialogVisible) return;
      await checkForUpdate(remoteOverride: pendingVersion);
    });
  }

  List<int> _parseVersion(String version) {
    return version
        .split('.')
        .map(
          (part) => int.tryParse(RegExp(r'\d+').stringMatch(part) ?? '0') ?? 0,
        )
        .toList();
  }

  Future<void> _showUpdateDialog({required AppVersionDto versionInfo}) async {
    if (_isDialogVisible && _visibleVersion == versionInfo.version) {
      return;
    }

    final navigatorState = await _resolveNavigatorState();
    if (navigatorState == null) {
      AppLogger.w(
        'No hay contexto disponible para mostrar update dialog',
        tag: 'AppUpdate',
      );
      return;
    }

    _isDialogVisible = true;
    _visibleVersion = versionInfo.version;

    await showDialog<void>(
      // ignore: use_build_context_synchronously
      context: navigatorState.context,
      barrierDismissible: !versionInfo.forceUpdate,
      useRootNavigator: true,
      builder: (dialogBuildContext) {
        return AppUpdateDialog(
          versionInfo: versionInfo,
          onLaterPressed: versionInfo.forceUpdate
              ? null
              : () =>
                    Navigator.of(dialogBuildContext, rootNavigator: true).pop(),
          onUpdatePressed: () async {
            Navigator.of(dialogBuildContext, rootNavigator: true).pop();
            await _startDownloadAndInstall(versionInfo);
          },
        );
      },
    );

    _isDialogVisible = false;
    _visibleVersion = null;
  }

  Future<NavigatorState?> _resolveNavigatorState() async {
    for (var i = 0; i < 10; i++) {
      final currentState = navigatorKey.currentState;
      if (currentState != null && currentState.mounted) {
        return currentState;
      }
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
    return null;
  }

  void _showSnackBar(ScaffoldMessengerState? messenger, String message) {
    messenger?.showSnackBar(SnackBar(content: Text(message)));
  }

  void _ensureObserverRegistered() {
    if (_observerRegistered) return;
    WidgetsBinding.instance.addObserver(this);
    _observerRegistered = true;
  }

  void _clearPendingForcedUpdateIfMatched(String installedVersion) {
    final pendingVersion = _pendingForcedVersion;
    if (pendingVersion == null) return;
    if (!isNewerVersion(installedVersion, pendingVersion.version)) {
      _pendingForcedVersion = null;
    }
  }

  Future<void> _startDownloadAndInstall(AppVersionDto versionInfo) async {
    final navigatorState = await _resolveNavigatorState();
    if (navigatorState == null) {
      AppLogger.w(
        'No hay navigatorState para iniciar descarga de actualización',
        tag: 'AppUpdate',
      );
      return;
    }

    final progressNotifier = ValueNotifier<double?>(null);
    final statusNotifier = ValueNotifier<String>('Iniciando descarga...');
    final cancelToken = CancelToken();
    // ignore: use_build_context_synchronously
    final messenger = ScaffoldMessenger.maybeOf(navigatorState.context);
    final installFuture = _downloadAndInstallApk(
      versionInfo: versionInfo,
      navigatorState: navigatorState,
      messenger: messenger,
      progressNotifier: progressNotifier,
      statusNotifier: statusNotifier,
      cancelToken: cancelToken,
    );

    await showDialog<void>(
      // ignore: use_build_context_synchronously
      context: navigatorState.context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (_) => AppUpdateDownloadDialog(
        version: versionInfo.version,
        progressListenable: progressNotifier,
        statusListenable: statusNotifier,
        forceUpdate: versionInfo.forceUpdate,
        onCancelPressed: versionInfo.forceUpdate
            ? null
            : () {
                statusNotifier.value = 'Posponiendo actualización...';
                cancelToken.cancel('update_postponed_by_user');
              },
      ),
    );

    await installFuture;
    progressNotifier.dispose();
    statusNotifier.dispose();
  }

  Future<void> _downloadAndInstallApk({
    required AppVersionDto versionInfo,
    required NavigatorState navigatorState,
    required ScaffoldMessengerState? messenger,
    required ValueNotifier<double?> progressNotifier,
    required ValueNotifier<String> statusNotifier,
    required CancelToken cancelToken,
  }) async {
    String? errorMessage;
    var shouldReshowDialog = false;
    var shouldCloseDialog = true;

    try {
      final apkUrl = versionInfo.apkUrl?.trim();
      if (apkUrl == null || apkUrl.isEmpty) {
        throw const _AppUpdateFlowException(
          'No hay URL de descarga disponible para esta actualización.',
        );
      }

      final uri = _resolveApkUri(apkUrl);
      if (uri == null) {
        throw const _AppUpdateFlowException('La URL del APK no es válida.');
      }

      final targetFile = await _buildTargetApkFile(versionInfo.version);
      statusNotifier.value = 'Descargando APK...';
      progressNotifier.value = 0;

      await _dio.download(
        uri.toString(),
        targetFile.path,
        cancelToken: cancelToken,
        deleteOnError: true,
        onReceiveProgress: (received, total) {
          if (total <= 0) {
            progressNotifier.value = null;
            return;
          }
          progressNotifier.value = received / total;
        },
      );

      statusNotifier.value = 'Preparando instalador...';
      progressNotifier.value = 1;

      final result = await _installerChannel.invokeMethod<String>(
        'installApk',
        {'filePath': targetFile.path},
      );

      switch (result) {
        case 'install_started':
          statusNotifier.value = 'Instalador abierto.';
          break;
        case 'settings_opened':
          errorMessage =
              'Permite instalar apps desde esta aplicación y vuelve a intentar.';
          break;
        default:
          errorMessage = 'No se pudo iniciar la instalación del APK.';
          shouldReshowDialog = versionInfo.forceUpdate;
          break;
      }
    } on DioException catch (e, st) {
      if (CancelToken.isCancel(e)) {
        errorMessage = 'Actualización pospuesta.';
        shouldCloseDialog = true;
      } else {
        AppLogger.e(
          'Error descargando APK de actualización',
          tag: 'AppUpdate',
          error: e,
          stackTrace: st,
        );
        errorMessage =
            'No se pudo descargar la actualización. Revisa tu conexión e intenta de nuevo.';
        shouldReshowDialog = versionInfo.forceUpdate;
      }
    } on PlatformException catch (e, st) {
      AppLogger.e(
        'Error invocando instalador nativo',
        tag: 'AppUpdate',
        error: e,
        stackTrace: st,
      );
      errorMessage =
          'No se pudo abrir el instalador del sistema. Intenta nuevamente.';
      shouldReshowDialog = versionInfo.forceUpdate;
    } on _AppUpdateFlowException catch (e) {
      errorMessage = e.message;
      shouldReshowDialog = versionInfo.forceUpdate;
    } catch (e, st) {
      AppLogger.e(
        'Error inesperado en flujo de actualización',
        tag: 'AppUpdate',
        error: e,
        stackTrace: st,
      );
      errorMessage = 'Ocurrió un problema preparando la actualización.';
      shouldReshowDialog = versionInfo.forceUpdate;
    } finally {
      await Future<void>.delayed(const Duration(milliseconds: 250));
      if (shouldCloseDialog) {
        _closeTopDialog(navigatorState);
      }
    }

    if (errorMessage != null) {
      _showSnackBar(messenger, errorMessage);
      if (shouldReshowDialog) {
        unawaited(_showUpdateDialog(versionInfo: versionInfo));
      }
    }
  }

  Future<File> _buildTargetApkFile(String version) async {
    final baseDir = await getApplicationSupportDirectory();
    final updatesDir = Directory('${baseDir.path}/updates');
    if (!updatesDir.existsSync()) {
      await updatesDir.create(recursive: true);
    }

    final safeVersion = version.replaceAll(RegExp(r'[^0-9A-Za-z._-]'), '_');
    final file = File('${updatesDir.path}/intellitaxi-$safeVersion.apk');
    if (file.existsSync()) {
      await file.delete();
    }
    return file;
  }

  void _closeTopDialog(NavigatorState navigatorState) {
    if (!navigatorState.mounted) return;
    Navigator.of(navigatorState.context, rootNavigator: true).pop();
  }

  Uri? _resolveApkUri(String rawUrl) {
    final normalized = rawUrl.trim();
    if (normalized.isEmpty) return null;

    final parsed = Uri.tryParse(normalized);
    final backendBaseUri = _getBackendBaseUri();

    if (parsed == null) return null;

    if (!parsed.hasScheme) {
      if (backendBaseUri == null) return null;
      final relativePath = normalized.startsWith('/')
          ? normalized
          : '/$normalized';
      return backendBaseUri.resolve(relativePath);
    }

    if (_isLocalhostLike(parsed.host) && backendBaseUri != null) {
      return parsed.replace(
        scheme: backendBaseUri.scheme,
        host: backendBaseUri.host,
        port: backendBaseUri.hasPort ? backendBaseUri.port : 0,
      );
    }

    return parsed;
  }

  Uri? _getBackendBaseUri() {
    final rawBaseUrl = AppConfig.baseUrl.trim();
    final parsed = Uri.tryParse(rawBaseUrl);
    if (parsed == null || !parsed.hasScheme || parsed.host.isEmpty) {
      return null;
    }

    final normalizedPath = parsed.path.endsWith('/')
        ? parsed.path
        : '${parsed.path}/';
    final withoutApiPath = normalizedPath.endsWith('/api/')
        ? normalizedPath.substring(0, normalizedPath.length - 4)
        : normalizedPath;

    return parsed.replace(path: withoutApiPath, query: null, fragment: null);
  }

  bool _isLocalhostLike(String host) {
    final normalizedHost = host.trim().toLowerCase();
    return normalizedHost == 'localhost' ||
        normalizedHost == '127.0.0.1' ||
        normalizedHost == '0.0.0.0' ||
        normalizedHost == '10.0.2.2';
  }
}

class _AppUpdateFlowException implements Exception {
  const _AppUpdateFlowException(this.message);

  final String message;
}
