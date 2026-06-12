import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:intellitaxi/core/services/app_foreground_service.dart';
import 'package:intellitaxi/core/services/app_logger.dart';
import 'package:intellitaxi/core/utils/fcm_isolate_context.dart';
import 'package:intellitaxi/features/conductor/providers/conductor_home_provider.dart';
import 'package:intellitaxi/features/conductor/utils/conductor_overlay_badge_store.dart';
import 'package:provider/provider.dart';

/// Burbuja flotante Android: solo con **turno activo** y app en segundo plano.
class DriverOverlayService {
  DriverOverlayService._();
  static final DriverOverlayService instance = DriverOverlayService._();

  static const int _overlayWindowSize = 124;
  static const double bubbleVisualSize = 96;

  bool _isRequestingPermission = false;
  bool _listenerRegistered = false;
  StreamSubscription<dynamic>? _overlayTapSubscription;
  String? _activeMode;
  String? _lastShareData;
  DateTime? _lastShownAt;
  Timer? _showDebounce;
  Future<void>? _overlayQueue;
  static const String _stableDriverMode = 'driver_bubble';
  static const Duration _reshowMinInterval = Duration(seconds: 4);
  AppLifecycleState? _lastOverlayLifecycle;
  bool _backgroundShowPending = false;
  DateTime? _lastPermissionWarnAt;

  bool get _isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Android: burbuja sobre otras apps. iOS no usa este canal.
  bool get isPlatformSupported => _isSupported;

  bool get isRequestingPermission => _isRequestingPermission;

  /// Escucha taps en la burbuja (`open_app`) y trae la app al frente.
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

  /// Sincroniza burbuja con el ciclo de vida global (único punto de entrada).
  void syncWithAppLifecycle(
    AppLifecycleState state, {
    required BuildContext context,
    required bool isConductorSession,
  }) {
    if (!_isSupported || !isConductorSession) return;

    if (state == AppLifecycleState.resumed) {
      _lastOverlayLifecycle = state;
      _backgroundShowPending = false;
      _showDebounce?.cancel();
      _showDebounce = null;
      unawaited(hide());
      return;
    }

    // `hidden` (Android 12+) y `paused`: una sola programación por transición.
    if (state != AppLifecycleState.paused &&
        state != AppLifecycleState.hidden) {
      return;
    }

    if (_lastOverlayLifecycle == AppLifecycleState.paused ||
        _lastOverlayLifecycle == AppLifecycleState.hidden) {
      return;
    }
    _lastOverlayLifecycle = state;

    if (_isRequestingPermission) {
      _logPermissionMissing('pidiendo permiso al usuario');
      return;
    }

    if (_backgroundShowPending) return;
    _backgroundShowPending = true;

    _showDebounce?.cancel();
    _showDebounce = Timer(const Duration(milliseconds: 300), () {
      _backgroundShowPending = false;
      unawaited(_showForBackgroundIfNeeded(context));
    });
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
      'en Ajustes → Apps → TaxbelUrbano. '
      'Sin ese permiso la burbuja no aparece al minimizar.',
      tag: 'DriverOverlay',
    );
  }

  /// Burbuja desde prefs (válido en isolate FCM / sin [BuildContext]).
  Future<void> showFromBadgeStore({bool enLinea = true}) async {
    if (!_isSupported) return;
    if (await _isAppInForeground()) return;
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
    return provider.totalSolicitudesLlegando + provider.totalSolicitudesEnEspera > 0;
  }

  Future<bool> _isAppInForeground() async {
    if (FcmIsolateContext.isBackgroundHandler) return false;
    final state = WidgetsBinding.instance.lifecycleState;
    return state == AppLifecycleState.resumed ||
        state == AppLifecycleState.inactive;
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

  /// Muestra o actualiza la burbuja según estado del conductor.
  Future<void> syncBubbleForConductor(ConductorHomeProvider provider) async {
    if (!_isSupported) return;
    if (await _isAppInForeground()) return;

    if (!_shouldShowBubbleForConductor(provider)) {
      AppLogger.d(
        '🔵 Overlay omitido: sin turno en línea ni servicios pendientes',
        tag: 'DriverOverlay',
      );
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

  Future<void> _showForBackgroundIfNeeded(BuildContext context) async {
    if (!_isSupported) return;
    if (await _isAppInForeground()) return;

    try {
      ConductorHomeProvider provider;
      try {
        provider = context.read<ConductorHomeProvider>();
      } catch (e) {
        AppLogger.d('⚠️ Overlay: sin ConductorHomeProvider ($e)');
        return;
      }

      if (!provider.tieneTurnoActivo) {
        await provider.cargarTurnoActual();
      }

      await syncBubbleForConductor(provider);
    } catch (e, st) {
      AppLogger.e(
        'Error mostrando burbuja',
        tag: 'DriverOverlay',
        error: e,
        stackTrace: st,
      );
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

  /// Burbuja en home conductor (con o sin turno iniciado).
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

  /// Alias histórico (turno / segundo plano).
  Future<void> showTurnoBubble({
    int llegando = 0,
    int enEspera = 0,
  }) =>
      showDriverBubble(llegando: llegando, enEspera: enEspera, enLinea: true);

  /// Burbuja durante viaje activo.
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

      final granted = await hasPermission();
      if (!granted) {
        _logPermissionMissing('permiso denegado al pintar burbuja');
        return;
      }

      final now = DateTime.now();
      final sameMode = _activeMode == mode ||
          (_activeMode == _stableDriverMode && mode == _stableDriverMode);
      final isActive = await FlutterOverlayWindow.isActive();
      final recentlyShown = _lastShownAt != null &&
          now.difference(_lastShownAt!) < _reshowMinInterval;
      if (isActive &&
          sameMode &&
          recentlyShown &&
          shareData != null &&
          shareData == _lastShareData) {
        return;
      }

      if (isActive && _activeMode != null && !sameMode) {
        await FlutterOverlayWindow.closeOverlay();
        _activeMode = null;
        _lastShareData = null;
        await Future<void>.delayed(const Duration(milliseconds: 120));
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
        _lastShownAt = DateTime.now();
        AppLogger.i('🔵 Overlay mostrado (modo: $mode)', tag: 'DriverOverlay');

        await Future<void>.delayed(const Duration(milliseconds: 300));
        if (!FcmIsolateContext.isBackgroundHandler) {
          await AppForegroundService.instance.ensureOverlayNativeChannel();
        }

        if (shareData != null) {
          await FlutterOverlayWindow.shareData(shareData);
          _lastShareData = shareData;
        }
      } catch (e, st) {
        AppLogger.e(
          'showOverlay falló',
          tag: 'DriverOverlay',
          error: e,
          stackTrace: st,
        );
        _activeMode = null;
        _lastShareData = null;
        _lastShownAt = null;
      }
    });
  }

  Future<void> hide() async {
    if (!_isSupported) return;
    await _enqueueOverlayOp(() async {
      _showDebounce?.cancel();
      _showDebounce = null;
      final isActive = await FlutterOverlayWindow.isActive();
      if (isActive) {
        await FlutterOverlayWindow.closeOverlay();
        AppLogger.i('🔵 Overlay ocultado (app en primer plano)', tag: 'DriverOverlay');
      }
      _activeMode = null;
      _lastShareData = null;
      _lastShownAt = null;
    });
  }

  void dispose() {
    _showDebounce?.cancel();
    _overlayTapSubscription?.cancel();
    _overlayTapSubscription = null;
    _listenerRegistered = false;
  }
}
