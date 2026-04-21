import 'package:flutter/material.dart';
import 'package:intellitaxi/core/services/app_logger.dart';
import 'package:intellitaxi/features/home/presentation/navigation_screen.dart';
import 'package:intellitaxi/main.dart' show navigatorKey;

/// Reemplaza toda la pila por [NavigationScreen] (mismo destino que la ruta `/home`).
/// Usar tras cancelar/finalizar servicio cuando `pushNamedAndRemoveUntil` falla o deja pantalla negra.
///
/// [onSettled] se invoca una vez ~600 ms después (primer frame + reintentos); el argumento es
/// `true` si algún intento de navegación se ejecutó sin lanzar (no garantiza frame pintado).
void navigateReplacingStackWithHome({
  BuildContext? context,
  void Function(bool navigationInvoked)? onSettled,
}) {
  MaterialPageRoute<void> nuevaRutaHome() => MaterialPageRoute<void>(
        settings: const RouteSettings(name: '/home'),
        builder: (_) => const NavigationScreen(),
      );

  final navegacionOk = <bool>[false];

  void intentar() {
    if (navegacionOk[0]) return;
    final nav = navigatorKey.currentState;
    if (nav != null && nav.mounted) {
      try {
        nav.pushAndRemoveUntil(nuevaRutaHome(), (route) => false);
        navegacionOk[0] = true;
        return;
      } catch (e) {
        AppLogger.d('⚠️ navigateReplacingStackWithHome navigatorKey: $e');
      }
    }
    final ctx = context;
    if (ctx != null && ctx.mounted) {
      try {
        Navigator.of(ctx, rootNavigator: true).pushAndRemoveUntil(
          nuevaRutaHome(),
          (route) => false,
        );
        navegacionOk[0] = true;
      } catch (e) {
        AppLogger.d('⚠️ navigateReplacingStackWithHome context: $e');
      }
    }
  }

  intentar();
  WidgetsBinding.instance.addPostFrameCallback((_) => intentar());
  Future<void>.delayed(const Duration(milliseconds: 120), intentar);
  Future<void>.delayed(const Duration(milliseconds: 350), intentar);

  Future<void>.delayed(const Duration(milliseconds: 600), () {
    if (!navegacionOk[0]) {
      AppLogger.d(
        '⚠️ navigateReplacingStackWithHome: sin confirmación tras reintentos',
      );
    }
    onSettled?.call(navegacionOk[0]);
  });
}
