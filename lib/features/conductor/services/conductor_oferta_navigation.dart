import 'package:flutter/material.dart';
import 'package:intellitaxi/features/conductor/data/conductor_oferta_exclusiva.dart';
import 'package:intellitaxi/features/conductor/presentation/conductor_oferta_exclusiva_screen.dart';
import 'package:intellitaxi/main.dart';

/// Abre/cierra la pantalla fullscreen de oferta exclusiva inDrive.
abstract final class ConductorOfertaNavigation {
  static bool _pantallaVisible = false;

  static bool get pantallaVisible => _pantallaVisible;

  static Future<void> abrirOfertaExclusiva(ConductorOfertaExclusiva oferta) async {
    if (_pantallaVisible) return;
    final nav = navigatorKey.currentState;
    if (nav == null) return;

    _pantallaVisible = true;
    try {
      await nav.push<void>(
        PageRouteBuilder<void>(
          opaque: true,
          fullscreenDialog: true,
          pageBuilder: (context, animation, secondaryAnimation) {
            return ConductorOfertaExclusivaScreen(oferta: oferta);
          },
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      );
    } finally {
      _pantallaVisible = false;
    }
  }

  static void cerrarSiVisible({String? mensaje}) {
    if (!_pantallaVisible) return;
    final nav = navigatorKey.currentState;
    _pantallaVisible = false;
    if (nav == null || !nav.canPop()) return;
    nav.pop();
    if (mensaje != null && mensaje.trim().isNotEmpty) {
      final ctx = navigatorKey.currentContext;
      if (ctx != null && ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(
            content: Text(mensaje),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }
}
