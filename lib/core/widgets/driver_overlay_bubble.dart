import 'dart:async' show StreamSubscription, unawaited;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:intellitaxi/core/services/app_foreground_service.dart';
import 'package:intellitaxi/core/services/app_logger.dart';
import 'package:intellitaxi/core/services/driver_overlay_service.dart';
import 'package:intellitaxi/core/theme/app_colors.dart';

/// App mínima para el isolate del overlay (Android).
class DriverOverlayApp extends StatefulWidget {
  const DriverOverlayApp({super.key});

  @override
  State<DriverOverlayApp> createState() => _DriverOverlayAppState();
}

class _DriverOverlayAppState extends State<DriverOverlayApp> {
  Uint8List? _logoBytes;

  /// PNG dedicado al overlay (isolate secundario en Android).
  static const String _logoAsset = 'assets/images/logo_overlay.png';

  StreamSubscription<dynamic>? _overlayCommandSubscription;

  @override
  void initState() {
    super.initState();
    unawaited(AppForegroundService.instance.ensureOverlayNativeChannel());
    _loadLogo();
    _listenForOpenAppCommands();
  }

  @override
  void dispose() {
    _overlayCommandSubscription?.cancel();
    super.dispose();
  }

  void _listenForOpenAppCommands() {
    _overlayCommandSubscription =
        FlutterOverlayWindow.overlayListener.listen((message) {
      final text = message?.toString() ?? '';
      if (text.contains('launch_main') ||
          text.contains('open_app') ||
          text.contains('auto_open_app')) {
        AppLogger.d('🔵 Overlay → MainActivity');
        unawaited(AppForegroundService.instance.launchMainFromOverlay());
      }
    });
  }

  Future<void> _loadLogo() async {
    try {
      final data = await rootBundle.load(_logoAsset);
      if (!mounted) return;
      setState(() => _logoBytes = data.buffer.asUint8List());
    } catch (_) {
      // Fallback visual en DriverOverlayBubble.
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true),
      home: Material(
        color: Colors.transparent,
        child: Center(
          child: DriverOverlayBubble(
            logoBytes: _logoBytes,
            size: DriverOverlayService.bubbleVisualSize,
          ),
        ),
      ),
    );
  }
}

/// UI de la burbuja flotante (isolate overlay de Android).
class DriverOverlayBubble extends StatelessWidget {
  final Uint8List? logoBytes;
  final String? label;
  final double size;

  const DriverOverlayBubble({
    super.key,
    this.logoBytes,
    this.label,
    this.size = DriverOverlayService.bubbleVisualSize,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () {
            unawaited(AppForegroundService.instance.openFromOverlayBubble());
          },
          child: _BubbleFace(size: size, logoBytes: logoBytes),
        ),
      ),
    );
  }
}

class _BubbleFace extends StatelessWidget {
  final double size;
  final Uint8List? logoBytes;

  const _BubbleFace({
    required this.size,
    this.logoBytes,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.white, width: 2.5),
      ),
      child: ClipOval(
        child: logoBytes != null && logoBytes!.isNotEmpty
            ? Image.memory(
                logoBytes!,
                width: size,
                height: size,
                fit: BoxFit.cover,
                gaplessPlayback: true,
                filterQuality: FilterQuality.medium,
                errorBuilder: (_, _, _) => _BrandFallback(size: size),
              )
            : _BrandFallback(size: size),
      ),
    );
  }
}

class _BrandFallback extends StatelessWidget {
  final double size;

  const _BrandFallback({required this.size});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.primary,
      child: Center(
        child: Icon(
          Icons.local_taxi_rounded,
          color: Colors.white,
          size: size * 0.48,
        ),
      ),
    );
  }
}
