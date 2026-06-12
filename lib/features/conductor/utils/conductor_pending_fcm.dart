import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:intellitaxi/core/services/app_logger.dart';
import 'package:intellitaxi/features/conductor/providers/conductor_home_provider.dart';
import 'package:intellitaxi/features/conductor/utils/conductor_overlay_badge_store.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Cola de alertas FCM de conductor (memoria + disco si la app no tiene contexto).
class ConductorPendingFcm {
  ConductorPendingFcm._();

  static const _prefsKey = 'conductor_pending_fcm_json';

  static Map<String, dynamic>? _pending;

  static Future<void> enqueue(Map<String, dynamic> data) async {
    if (data.isEmpty) return;
    _pending = Map<String, dynamic>.from(data);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, jsonEncode(_pending));
      AppLogger.d('📥 FCM conductor en cola (disco)');
    } catch (e) {
      AppLogger.d('⚠️ FCM cola disco: $e');
    }
  }

  static Future<Map<String, dynamic>?> _loadFromDisk() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw == null || raw.isEmpty) return null;
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (e) {
      AppLogger.d('⚠️ FCM cola lectura: $e');
    }
    return null;
  }

  static Future<void> _clearDisk() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefsKey);
    } catch (_) {}
  }

  static bool get hasPending => _pending != null && _pending!.isNotEmpty;

  static Future<bool> ensureLoaded() async {
    if (hasPending) return true;
    final fromDisk = await _loadFromDisk();
    if (fromDisk != null && fromDisk.isNotEmpty) {
      _pending = fromDisk;
      return true;
    }
    return false;
  }

  static Future<void> clearAfterProcessed() async {
    _pending = null;
    await _clearDisk();
  }

  /// Descarta cola pendiente (p. ej. logout).
  static Future<void> clear() => clearAfterProcessed();

  static Future<void> flush(BuildContext context) async {
    await ensureLoaded();
    final data = _pending;
    if (data == null || data.isEmpty) return;
    if (!context.mounted) return;

    try {
      await context.read<ConductorHomeProvider>().procesarAlertaSolicitudEntrante(
        data,
      );
      await clearAfterProcessed();
      await ConductorOverlayBadgeStore.clearPendingFlag();
      AppLogger.d('✅ FCM conductor procesado desde cola');
    } catch (e) {
      AppLogger.d('⚠️ ConductorPendingFcm flush: $e');
    }
  }
}
