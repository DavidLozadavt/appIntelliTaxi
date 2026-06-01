import 'package:flutter/widgets.dart';
import 'package:intellitaxi/core/services/app_logger.dart';
import 'package:intellitaxi/features/conductor/providers/conductor_home_provider.dart';
import 'package:provider/provider.dart';

/// Cola de alertas FCM de conductor cuando la app aún no tiene contexto listo.
class ConductorPendingFcm {
  ConductorPendingFcm._();

  static Map<String, dynamic>? _pending;

  static void enqueue(Map<String, dynamic> data) {
    if (data.isEmpty) return;
    _pending = Map<String, dynamic>.from(data);
    AppLogger.d('📥 FCM conductor en cola (sesión o home no listos)');
  }

  static bool get hasPending => _pending != null && _pending!.isNotEmpty;

  static Future<void> flush(BuildContext context) async {
    final data = _pending;
    if (data == null || data.isEmpty) return;
    _pending = null;
    if (!context.mounted) {
      _pending = data;
      return;
    }
    try {
      await context.read<ConductorHomeProvider>().procesarAlertaSolicitudEntrante(
        data,
      );
      AppLogger.d('✅ FCM conductor procesado desde cola');
    } catch (e) {
      _pending = data;
      AppLogger.d('⚠️ ConductorPendingFcm flush: $e');
    }
  }
}
