import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/services/active_service_restoration_service.dart';
import '../../../core/services/active_service_screen_registry.dart';
import '../../../core/services/app_logger.dart';
import '../../../core/services/service_navigation_helper.dart';
import '../../../main.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/chat_badge_provider.dart';
import 'chat_helper.dart';

/// Navegación al abrir una notificación push del chat taxi (FCM).
class ChatNotificationNavigation {
  static bool isChatTaxiNotification(Map<String, dynamic> data) {
    final route = data['route']?.toString().toLowerCase().trim() ?? '';
    if (route == 'chat_servicio' || route == 'chat-servicio') {
      return true;
    }

    final servicioId = parseServicioId(data);
    if (servicioId == null) return false;

    final mensajeTipo =
        data['mensaje_tipo']?.toString().toLowerCase().trim() ?? '';
    if (mensajeTipo == 'texto' ||
        mensajeTipo == 'imagen' ||
        mensajeTipo == 'ubicacion') {
      return true;
    }

    final tipo = data['tipo']?.toString().toLowerCase() ?? '';
    if (tipo.contains('chat') ||
        tipo.contains('mensaje') ||
        tipo == 'nuevo_mensaje') {
      return true;
    }

    return false;
  }

  static int? parseServicioId(Map<String, dynamic> data) {
    final raw =
        data['servicio_id'] ?? data['servicioId'] ?? data['id_servicio'];
    if (raw == null) return null;
    if (raw is int) return raw;
    return int.tryParse(raw.toString());
  }

  static Future<void> openFromNotification(Map<String, dynamic> data) async {
    final servicioId = parseServicioId(data);
    if (servicioId == null || servicioId <= 0) {
      AppLogger.d('💬 FCM chat: servicio_id inválido');
      navigatorKey.currentState?.pushNamed('/home');
      return;
    }

    final context = navigatorKey.currentContext;
    if (context == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(openFromNotification(data));
      });
      return;
    }

    await _openChatForServicio(context, servicioId);
  }

  static Future<void> _openChatForServicio(
    BuildContext context,
    int servicioId,
  ) async {
    final auth = context.read<AuthProvider>();
    if (auth.user == null) {
      await auth.loadUserFromStorage();
    }

    final navContext = navigatorKey.currentContext;
    if (navContext == null || !navContext.mounted) return;

    final miUserId = auth.userId ?? auth.user?.id ?? 0;
    if (miUserId <= 0) {
      Navigator.of(navContext).pushNamed('/login');
      return;
    }

    try {
      navContext.read<ChatBadgeProvider>().limpiarNoLeidos(servicioId);
    } catch (_) {}

    await _ensureActiveServiceVisible(auth, servicioId);

    final chatContext = navigatorKey.currentContext;
    if (chatContext == null || !chatContext.mounted) {
      AppLogger.d('💬 FCM chat: sin contexto tras restaurar servicio');
      return;
    }

    await ChatHelper.abrirChat(
      context: chatContext,
      servicioId: servicioId,
      miUserId: miUserId,
    );
  }

  /// Si el viaje activo coincide con [servicioId], muestra primero la pantalla del mapa.
  static Future<void> _ensureActiveServiceVisible(
    AuthProvider auth,
    int servicioId,
  ) async {
    try {
      final restoration = ActiveServiceRestorationService();
      final activo = await restoration.verificarServicioActivoSegunRol(auth);
      if (activo == null) return;

      if (!ServiceNavigationHelper.shouldShowActiveService(activo)) return;

      final sidRaw = activo['servicio']?['id'];
      final sid = sidRaw is int
          ? sidRaw
          : int.tryParse(sidRaw?.toString() ?? '');
      if (sid != servicioId) return;

      final tipo = activo['tipo']?.toString();
      if (tipo == null) return;

      if (ActiveServiceScreenRegistry.isShowing(
        type: tipo,
        serviceId: servicioId,
      )) {
        return;
      }

      final navContext = navigatorKey.currentContext;
      if (navContext == null || !navContext.mounted) return;
      await ServiceNavigationHelper.navigateToActiveService(
        navContext,
        activo,
        auth,
      );
    } catch (e) {
      AppLogger.d('💬 FCM chat: no se pudo abrir servicio activo: $e');
    }
  }
}
