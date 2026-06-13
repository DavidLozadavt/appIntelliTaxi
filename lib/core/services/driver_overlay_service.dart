import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:intellitaxi/core/diagnostics/app_diagnostics.dart';
import 'package:intellitaxi/core/services/app_foreground_service.dart';
import 'package:intellitaxi/core/services/app_logger.dart';
import 'package:intellitaxi/core/services/driver_overlay_state_store.dart';
import 'package:intellitaxi/core/utils/fcm_isolate_context.dart';
import 'package:intellitaxi/features/conductor/providers/conductor_home_provider.dart';
import 'package:intellitaxi/features/conductor/utils/conductor_overlay_badge_store.dart';
import 'package:provider/provider.dart';

/// Burbuja flotante Android: turno activo + app en segundo plano + permiso overlay.
class DriverOverlayService {
  DriverOverlayService._();
  static final DriverOverlayService instance = DriverOverlayService._();

  static const int _overlayWindowSize = 124;
  static const double bubbleVisualSize = 96;

  static const Duration _backgroundShowDelay = Duration(milliseconds: 600);
  static const Duration _backgroundRetryDelay = Duration(milliseconds: 1400);
  static const String _stableDriverMode = 'driver_bubble';

  bool _isRequestingPermission = false;
  bool _listenerRegistered = false;
  StreamSubscription<dynamic>? _overlayTapSubscription;
  String? _activeMode;
  String? _lastShareData;
  Timer? _showDebounce;
  Future<void>? _overlayQueue;
  int _foregroundGeneration = 0;
  bool _backgroundShowScheduled = false;
  BuildContext? _pendingShowContext;
  DateTime? _lastPermissionWarnAt;

  bool get _isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  bool get isPlatformSupported => _isSupported;

  void _overlayDiag(String message, {String? extra}) {
    AppLogger.i(message, tag: 'DriverOverlay');
    AppDiagnostics.record('overlay', message, extra: extra);
  }

  void _overlayDiagWarn(String message, {String? extra}) {
    AppLogger.w(message, tag: 'DriverOverlay');
    AppDiagnostics.record('overlay', message, extra: extra ?? 'warn');
  }
  Future<void> onTurnStarted() async {
    if (!_isSupported) return;
    await DriverOverlayStateStore.setArmed(true);
    ensureReturnListener();
    AppLogger.i('🔵 Overlay armado (turno activo)', tag: 'DriverOverlay');
    AppDiagnostics.record('overlay', 'armado turno activo');
    if (await hasPermission()) {
      _overlayDiag('permiso OK');
    } else {
      _overlayDiagWarn('sin permiso al iniciar turno');
    }
  }

  /// Idempotente: turno ya activo (login, restore API o caché) — mismo setup que al iniciar turno.
  Future<void> ensureReadyForActiveTurn({
    int llegando = 0,
    int enEspera = 0,
  }) async {
    if (!_isSupported) return;
    await onTurnStarted();
    await ConductorOverlayBadgeStore.write(
      llegando: llegando,
      enEspera: enEspera,
    );
    if (!FcmIsolateContext.isBackgroundHandler) {
      try {
        await AppForegroundService.instance.ensureOverlayNativeChannel();
      } catch (e) {
        AppLogger.w(
          '🔵 Canal nativo overlay no listo (se reintentará al minimizar): $e',
          tag: 'DriverOverlay',
        );
      }
    }
    _overlayDiag('listo para turno activo', extra: 'llegando=$llegando espera=$enEspera');
  }

  /// Llamar al finalizar turno o cerrar sesión.
  Future<void> onTurnEnded() async {
    if (!_isSupported) return;
    await DriverOverlayStateStore.setArmed(false);
    _foregroundGeneration++;
    _cancelBackgroundShow();
    await hide();
    AppLogger.i('🔵 Overlay desarmado (sin turno)', tag: 'DriverOverlay');
  }

  void ensureReturnListener() {
    if (!_isSupported || _listenerRegistered) return;
    _listenerRegistered = true;
    _overlayTapSubscription = FlutterOverlayWindow.overlayListener.listen(
      (message) {
        final text = message?.toString() ?? '';
        if (text.contains('launch_main') ||
            text.contains('open_app') ||
            text.contains('auto_open_app')) {
          AppLogger.d('🔵 Overlay listener → MainActivity');
          unawaited(AppForegroundService.instance.launchMainFromOverlay());
        }
      },
    );
  }

  /// Único punto de entrada lifecycle (AppLifecycleManager).
  void syncWithAppLifecycle(
    AppLifecycleState state, {
    required BuildContext context,
    required bool isConductorSession,
  }) {
    if (!_isSupported || !isConductorSession) return;

    if (state == AppLifecycleState.resumed) {
      _foregroundGeneration++;
      _backgroundShowScheduled = false;
      _pendingShowContext = null;
      _cancelBackgroundShow();
      unawaited(hide());
      return;
    }

    if (state != AppLifecycleState.paused &&
        state != AppLifecycleState.hidden) {
      return;
    }

    if (_isRequestingPermission) {
      _logPermissionMissing('pidiendo permiso al usuario');
      return;
    }

    requestShowWhenBackgrounded(context: context);
  }

  /// Overlay: el servicio valida turno armado y permiso.
  void requestShowWhenBackgrounded({BuildContext? context}) {
    if (!_isSupported) return;
    if (context != null) {
      _pendingShowContext = context;
    }
    if (_backgroundShowScheduled) {
      AppLogger.d(
        '🔵 Overlay show ya programado (omitir duplicado)',
        tag: 'DriverOverlay',
      );
      return;
    }
    unawaited(_armBackgroundShowIfNeeded());
  }

  Future<void> _armBackgroundShowIfNeeded() async {
    if (!await DriverOverlayStateStore.isArmed()) {
      AppLogger.d('🔵 Overlay no programado: turno no armado', tag: 'DriverOverlay');
      return;
    }
    _backgroundShowScheduled = true;
    _scheduleBackgroundShow();
  }

  void _cancelBackgroundShow() {
    _showDebounce?.cancel();
    _showDebounce = null;
  }

  void _scheduleBackgroundShow() {
    final generation = _foregroundGeneration;
    _showDebounce?.cancel();
    AppLogger.i('🔵 Overlay programado en ${_backgroundShowDelay.inMilliseconds}ms', tag: 'DriverOverlay');
    AppDiagnostics.record('overlay', 'programado', extra: '${_backgroundShowDelay.inMilliseconds}ms');
    _showDebounce = Timer(_backgroundShowDelay, () {
      unawaited(_attemptBackgroundShow(generation));
    });
  }

  Future<void> _attemptBackgroundShow(int generation) async {
    if (generation != _foregroundGeneration) {
      AppLogger.d('🔵 Overlay cancelado (volvió a primer plano)', tag: 'DriverOverlay');
      return;
    }

    _overlayDiag('intentando mostrar');

    final ctx = _pendingShowContext;
    final first = await _showForBackgroundIfNeeded(
      ctx != null && ctx.mounted ? ctx : null,
    );
    if (first || generation != _foregroundGeneration) return;

    AppLogger.i(
      '🔵 Overlay reintento en ${_backgroundRetryDelay.inMilliseconds}ms',
      tag: 'DriverOverlay',
    );
    await Future<void>.delayed(_backgroundRetryDelay);
    if (generation != _foregroundGeneration) return;

    _overlayDiag('reintento mostrar');
    await _showForBackgroundIfNeeded(
      ctx != null && ctx.mounted ? ctx : null,
      isRetry: true,
    );
  }

  void _logPermissionMissing(String motivo) {
    final now = DateTime.now();
    if (_lastPermissionWarnAt != null &&
        now.difference(_lastPermissionWarnAt!) <
            const Duration(seconds: 30)) {
      return;
    }
    _lastPermissionWarnAt = now;
    AppLogger.w(
      '🔵 OVERLAY no visible ($motivo): activa «Mostrar sobre otras apps» '
      'en Ajustes → Apps → TaxbelUrbano.',
      tag: 'DriverOverlay',
    );
  }

  Future<void> showFromBadgeStore({bool enLinea = true}) async {
    if (!_isSupported) return;
    if (await _isAppInForeground()) return;
    if (!await DriverOverlayStateStore.isArmed() && !enLinea) return;

    final counts = await ConductorOverlayBadgeStore.read();
    if (counts.llegando <= 0 && counts.enEspera <= 0 && !enLinea) return;
    await showDriverBubble(
      llegando: counts.llegando,
      enEspera: counts.enEspera,
      enLinea: enLinea,
    );
  }

  bool _shouldShowBubbleForConductor(ConductorHomeProvider provider) {
    if (!provider.tieneTurnoActivo) return false;
    if (provider.enServicio) return true;
    if (provider.isOnline) return true;
    return provider.totalSolicitudesLlegando + provider.totalSolicitudesEnEspera >
        0;
  }

  /// Solo primer plano real; `inactive`/`paused`/`hidden` permiten burbuja.
  Future<bool> _isAppInForeground() async {
    if (FcmIsolateContext.isBackgroundHandler) return false;
    final state = WidgetsBinding.instance.lifecycleState;
    return state == AppLifecycleState.resumed;
  }

  Future<T> _enqueueOverlayOp<T>(Future<T> Function() action) async {
    final previous = _overlayQueue;
    final completer = Completer<void>();
    _overlayQueue = completer.future;
    if (previous != null) {
      try {
        await previous;
      } catch (_) {}
    }
    try {
      return await action();
    } finally {
      completer.complete();
    }
  }

  Future<void> syncBubbleForConductor(ConductorHomeProvider provider) async {
    if (!_isSupported) return;
    if (await _isAppInForeground()) return;

    if (!_shouldShowBubbleForConductor(provider)) {
      await hide();
      return;
    }

    final granted = await hasPermission();
    if (!granted) {
      _logPermissionMissing('sin permiso SYSTEM_ALERT_WINDOW');
      return;
    }

    if (provider.enServicio) {
      final id = provider.servicioActivoId;
      if (id != null && id > 0) {
        await showTripBubble(servicioId: id);
        return;
      }
    }

    final llegando = provider.totalSolicitudesLlegando;
    final enEspera = provider.totalSolicitudesEnEspera;
    await ConductorOverlayBadgeStore.write(
      llegando: llegando,
      enEspera: enEspera,
    );
    await showDriverBubble(
      llegando: llegando,
      enEspera: enEspera,
      enLinea: provider.isOnline,
    );
  }

  Future<void> syncBubbleFromStorage() async {
    if (!_isSupported) return;
    if (await _isAppInForeground()) return;

    if (!await DriverOverlayStateStore.isArmed()) {
      await hide();
      return;
    }

    final granted = await hasPermission();
    if (!granted) {
      _logPermissionMissing('sin permiso (storage fallback)');
      return;
    }

    final counts = await ConductorOverlayBadgeStore.read();
    await showDriverBubble(
      llegando: counts.llegando,
      enEspera: counts.enEspera,
      enLinea: true,
    );
  }

  /// `true` = mostrado u omitido con certeza; `false` = conviene reintentar.
  Future<bool> _showForBackgroundIfNeeded(
    BuildContext? context, {
    bool isRetry = false,
  }) async {
    if (!_isSupported) return true;
    if (await _isAppInForeground()) {
      AppLogger.d(
        '🔵 Overlay ${isRetry ? "reintento" : "intento"} omitido: app en primer plano',
        tag: 'DriverOverlay',
      );
      return false;
    }

    if (!await DriverOverlayStateStore.isArmed()) {
      AppLogger.d(
        '🔵 Overlay omitido: turno no armado',
        tag: 'DriverOverlay',
      );
      await hide();
      return true;
    }

    try {
      ConductorHomeProvider? provider;
      if (context != null) {
        try {
          if (context.mounted) {
            provider = context.read<ConductorHomeProvider>();
          }
        } catch (e) {
          AppLogger.d(
            '⚠️ Overlay: provider no disponible ($e)',
            tag: 'DriverOverlay',
          );
        }
      }

      if (provider != null) {
        if (!provider.tieneTurnoActivo) {
          await provider.cargarTurnoActual();
        }
        if (_shouldShowBubbleForConductor(provider)) {
          await syncBubbleForConductor(provider);
          return true;
        }
      }

      await syncBubbleFromStorage();
      return true;
    } catch (e, st) {
      AppLogger.e(
        'Error mostrando burbuja${isRetry ? " (reintento)" : ""}',
        tag: 'DriverOverlay',
        error: e,
        stackTrace: st,
      );
      return !isRetry;
    }
  }

  Future<bool> hasPermission() async {
    if (!_isSupported) return false;
    return FlutterOverlayWindow.isPermissionGranted();
  }

  Future<bool> requestPermissionIfNeeded() async {
    if (!_isSupported) return false;
    final granted = await hasPermission();
    if (granted) return true;
    _isRequestingPermission = true;
    try {
      final requested = await FlutterOverlayWindow.requestPermission();
      return requested ?? false;
    } finally {
      _isRequestingPermission = false;
    }
  }

  Future<void> showDriverBubble({
    int llegando = 0,
    int enEspera = 0,
    bool enLinea = false,
  }) async {
    final total = llegando + enEspera;
    final String content;
    if (total > 0) {
      content = '$total servicio${total == 1 ? '' : 's'} · Toca para abrir';
    } else if (enLinea) {
      content = 'En línea · Toca para abrir';
    } else {
      content = 'TaxbelUrbano · Toca para abrir';
    }
    await _showBubble(
      mode: _stableDriverMode,
      title: 'TaxbelUrbano',
      content: content,
      shareData: 'servicios:$llegando:$enEspera',
    );
  }

  Future<void> showTurnoBubble({
    int llegando = 0,
    int enEspera = 0,
  }) =>
      showDriverBubble(llegando: llegando, enEspera: enEspera, enLinea: true);

  Future<void> showTripBubble({required int servicioId}) async {
    await _showBubble(
      mode: 'trip:$servicioId',
      title: 'Viaje activo #$servicioId',
      content: 'Toca para volver al viaje',
      shareData: 'servicio_id:$servicioId',
    );
  }

  Future<void> show({required int servicioId}) =>
      showTripBubble(servicioId: servicioId);

  Future<void> _showBubble({
    required String mode,
    required String title,
    required String content,
    String? shareData,
  }) async {
    if (!_isSupported) return;
    if (_isRequestingPermission) return;

    await _enqueueOverlayOp(() async {
      ensureReturnListener();

      if (await _isAppInForeground()) return;

      final granted = await hasPermission();
      if (!granted) {
        _logPermissionMissing('permiso denegado al pintar burbuja');
        return;
      }

      final sameMode = _activeMode == mode ||
          (_activeMode == _stableDriverMode && mode == _stableDriverMode);
      final isActive = await FlutterOverlayWindow.isActive();

      if (isActive &&
          sameMode &&
          shareData != null &&
          shareData == _lastShareData) {
        AppLogger.d('🔵 Overlay ya visible (mismo contenido)', tag: 'DriverOverlay');
        return;
      }

      if (isActive && _activeMode != null && !sameMode) {
        await FlutterOverlayWindow.closeOverlay();
        _activeMode = null;
        _lastShareData = null;
        await Future<void>.delayed(const Duration(milliseconds: 150));
      }

      try {
        await FlutterOverlayWindow.showOverlay(
          height: _overlayWindowSize,
          width: _overlayWindowSize,
          enableDrag: true,
          alignment: OverlayAlignment.centerRight,
          overlayTitle: title,
          overlayContent: content,
          positionGravity: PositionGravity.right,
        );

        _activeMode = mode;
        _overlayDiag('mostrado', extra: 'modo=$mode');

        await Future<void>.delayed(const Duration(milliseconds: 300));
        if (!FcmIsolateContext.isBackgroundHandler) {
          await AppForegroundService.instance.ensureOverlayNativeChannel();
        }

        if (shareData != null) {
          await FlutterOverlayWindow.shareData(shareData);
          _lastShareData = shareData;
        }
      } catch (e, st) {
        _overlayDiagWarn('showOverlay falló', extra: e.toString());
        AppLogger.e(
          'showOverlay falló',
          tag: 'DriverOverlay',
          error: e,
          stackTrace: st,
        );
        _activeMode = null;
        _lastShareData = null;
      }
    });
  }

  Future<void> hide() async {
    if (!_isSupported) return;
    await _enqueueOverlayOp(() async {
      _cancelBackgroundShow();
      final isActive = await FlutterOverlayWindow.isActive();
      if (isActive) {
        await FlutterOverlayWindow.closeOverlay();
        AppLogger.i(
          '🔵 Overlay ocultado (app en primer plano)',
          tag: 'DriverOverlay',
        );
      }
      _activeMode = null;
      _lastShareData = null;
    });
  }

  void dispose() {
    _cancelBackgroundShow();
    _overlayTapSubscription?.cancel();
    _overlayTapSubscription = null;
    _listenerRegistered = false;
  }
}
