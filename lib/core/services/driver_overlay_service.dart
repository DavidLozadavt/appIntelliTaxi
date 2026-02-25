import 'package:flutter/foundation.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';

/// Servicio de overlay para conductor (solo Android).
/// Muestra una burbuja flotante cuando la app pasa a segundo plano.
class DriverOverlayService {
  DriverOverlayService._();
  static final DriverOverlayService instance = DriverOverlayService._();
  bool _isRequestingPermission = false;

  bool get _isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  bool get isRequestingPermission => _isRequestingPermission;

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

  Future<void> show({required int servicioId}) async {
    if (!_isSupported) return;
    if (_isRequestingPermission) return;

    final granted = await hasPermission();
    if (!granted) return;

    final isActive = await FlutterOverlayWindow.isActive();
    if (isActive) {
      await FlutterOverlayWindow.shareData('servicio_id:$servicioId');
      return;
    }

    await FlutterOverlayWindow.showOverlay(
      height: 120,
      width: 120,
      enableDrag: true,
      overlayTitle: 'Servicio activo',
      overlayContent: 'Conductor #$servicioId',
    );
  }

  Future<void> hide() async {
    if (!_isSupported) return;
    final isActive = await FlutterOverlayWindow.isActive();
    if (isActive) {
      await FlutterOverlayWindow.closeOverlay();
    }
  }
}
