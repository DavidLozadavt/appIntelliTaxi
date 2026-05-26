import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:intellitaxi/core/services/app_logger.dart';
import 'package:intellitaxi/core/services/incoming_service_notification_service.dart';

/// Burbuja flotante Android para volver a IntelliTaxi desde otras apps.
/// - **Online:** conductor disponible en home.
/// - **Viaje:** pantalla de servicio activo.
class DriverOverlayService {
  DriverOverlayService._();
  static final DriverOverlayService instance = DriverOverlayService._();

  bool _isRequestingPermission = false;
  bool _listenerRegistered = false;
  StreamSubscription<dynamic>? _overlayTapSubscription;
  String? _activeMode;

  bool get _isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  bool get isRequestingPermission => _isRequestingPermission;

  /// Escucha taps en la burbuja (`open_app`) y trae la app al frente.
  void ensureReturnListener() {
    if (!_isSupported || _listenerRegistered) return;
    _listenerRegistered = true;
    _overlayTapSubscription = FlutterOverlayWindow.overlayListener.listen(
      (message) {
        final text = message?.toString() ?? '';
        if (text.contains('open_app')) {
          AppLogger.d('🔵 Overlay tap → abrir IntelliTaxi');
          IncomingServiceNotificationService.instance.bringAppToForeground();
        }
      },
    );
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

  /// Burbuja mientras el conductor está **online** (home, otras apps abiertas).
  Future<void> showOnlineBubble() async {
    await _showBubble(
      mode: 'online',
      title: 'IntelliTaxi — Disponible',
      content: 'Toca para volver a la app',
    );
  }

  /// Burbuja durante **viaje activo** (mapa en segundo plano).
  Future<void> showTripBubble({required int servicioId}) async {
    await _showBubble(
      mode: 'trip:$servicioId',
      title: 'Viaje activo #$servicioId',
      content: 'Toca para volver al viaje',
      shareData: 'servicio_id:$servicioId',
    );
  }

  /// Compatibilidad con código existente.
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
    if (!granted) return;

    if (_activeMode == mode) {
      if (shareData != null) {
        await FlutterOverlayWindow.shareData(shareData);
      }
      return;
    }

    final isActive = await FlutterOverlayWindow.isActive();
    if (isActive) {
      await FlutterOverlayWindow.closeOverlay();
    }

    await FlutterOverlayWindow.showOverlay(
      height: 72,
      width: 72,
      enableDrag: true,
      alignment: OverlayAlignment.centerRight,
      overlayTitle: title,
      overlayContent: content,
      positionGravity: PositionGravity.auto,
    );

    _activeMode = mode;
    if (shareData != null) {
      await FlutterOverlayWindow.shareData(shareData);
    }
  }

  Future<void> hide() async {
    if (!_isSupported) return;
    final isActive = await FlutterOverlayWindow.isActive();
    if (isActive) {
      await FlutterOverlayWindow.closeOverlay();
    }
    _activeMode = null;
  }

  void dispose() {
    _overlayTapSubscription?.cancel();
    _overlayTapSubscription = null;
    _listenerRegistered = false;
  }
}
