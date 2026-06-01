import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:intellitaxi/core/services/app_foreground_service.dart';
import 'package:intellitaxi/core/services/app_logger.dart';
import 'package:intellitaxi/features/conductor/providers/conductor_home_provider.dart';
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
  Timer? _showDebounce;
  static const String _stableDriverMode = 'driver_bubble';

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
        if (text.contains('open_app')) {
          AppLogger.d('🔵 Overlay tap → abrir app');
          unawaited(AppForegroundService.instance.bringAppToForeground());
        }
      },
    );
  }

  /// Sincroniza burbuja con el ciclo de vida global (NavigationScreen / viaje).
  void syncWithAppLifecycle(
    AppLifecycleState state, {
    required BuildContext context,
    required bool isConductorSession,
  }) {
    if (!_isSupported || !isConductorSession) return;

    if (state == AppLifecycleState.resumed) {
      _showDebounce?.cancel();
      _showDebounce = null;
      unawaited(hide());
      return;
    }

    // Solo en `paused`: en `hidden` Android 12+ suele rechazar startForeground().
    if (state != AppLifecycleState.paused) {
      return;
    }

    if (_isRequestingPermission) return;

    _showDebounce?.cancel();
    _showDebounce = Timer(const Duration(milliseconds: 600), () {
      unawaited(_showForBackgroundIfNeeded(context));
    });
  }

  /// Muestra o actualiza la burbuja según estado del conductor (sin exigir turno activo).
  Future<void> syncBubbleForConductor(ConductorHomeProvider provider) async {
    if (!_isSupported) return;

    final granted = await hasPermission();
    if (!granted) {
      AppLogger.d('🔵 Overlay: sin permiso SYSTEM_ALERT_WINDOW');
      return;
    }

    if (provider.enServicio) {
      final id = provider.servicioActivoId;
      if (id != null && id > 0) {
        await showTripBubble(servicioId: id);
        return;
      }
    }

    await showDriverBubble(
      llegando: provider.solicitudesOrdenadas.length,
      enEspera: provider.totalSolicitudesEnEspera,
      enLinea: provider.isOnline,
    );
  }

  Future<void> _showForBackgroundIfNeeded(BuildContext context) async {
    if (!_isSupported) return;

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

    ensureReturnListener();

    final granted = await hasPermission();
    if (!granted) {
      AppLogger.d('🔵 Overlay: permiso denegado al mostrar');
      return;
    }

    final isActive = await FlutterOverlayWindow.isActive();
    if (isActive &&
        (_activeMode == mode ||
            (_activeMode == _stableDriverMode && mode == _stableDriverMode))) {
      if (shareData != null) {
        await FlutterOverlayWindow.shareData(shareData);
      }
      return;
    }

    if (isActive && _activeMode != mode) {
      await FlutterOverlayWindow.closeOverlay();
      _activeMode = null;
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
      AppLogger.d('🔵 Overlay mostrado (modo: $mode)');

      await Future<void>.delayed(const Duration(milliseconds: 300));
      await AppForegroundService.instance.ensureOverlayNativeChannel();

      if (shareData != null) {
        await FlutterOverlayWindow.shareData(shareData);
      }
    } catch (e, st) {
      AppLogger.e(
        'showOverlay falló',
        tag: 'DriverOverlay',
        error: e,
        stackTrace: st,
      );
      _activeMode = null;
    }
  }

  Future<void> hide() async {
    if (!_isSupported) return;
    _showDebounce?.cancel();
    _showDebounce = null;
    final isActive = await FlutterOverlayWindow.isActive();
    if (isActive) {
      await FlutterOverlayWindow.closeOverlay();
      AppLogger.d('🔵 Overlay ocultado');
    }
    _activeMode = null;
  }

  void dispose() {
    _showDebounce?.cancel();
    _overlayTapSubscription?.cancel();
    _overlayTapSubscription = null;
    _listenerRegistered = false;
  }
}
