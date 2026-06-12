import 'package:shared_preferences/shared_preferences.dart';

/// Una sola alerta push por solicitud (Pusher, FCM y notificación local).
class ConductorIncomingDedupStore {
  ConductorIncomingDedupStore._();

  static const _realtimeIdKey = 'conductor_incoming_realtime_id';
  static const _realtimeAtKey = 'conductor_incoming_realtime_at_ms';
  static const _pushIdKey = 'conductor_incoming_push_id';
  static const _pushAtKey = 'conductor_incoming_push_at_ms';
  static const _ttl = Duration(seconds: 90);
  static const _globalThrottle = Duration(seconds: 20);

  static String? _memoryId;
  static DateTime? _memoryAt;

  static Future<void> recordRealtimeIncoming(String solicitudId) async {
    if (solicitudId.isEmpty) return;
    _memoryId = solicitudId;
    _memoryAt = DateTime.now();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_realtimeIdKey, solicitudId);
    await prefs.setInt(_realtimeAtKey, _memoryAt!.millisecondsSinceEpoch);
  }

  static Future<void> recordPushShown(String? solicitudId) async {
    final now = DateTime.now();
    _memoryAt = now;
    if (solicitudId != null && solicitudId.isNotEmpty) {
      _memoryId = solicitudId;
    }
    final prefs = await SharedPreferences.getInstance();
    if (solicitudId != null && solicitudId.isNotEmpty) {
      await prefs.setString(_pushIdKey, solicitudId);
      await prefs.setString(_realtimeIdKey, solicitudId);
    }
    await prefs.setInt(_pushAtKey, now.millisecondsSinceEpoch);
    await prefs.setInt(_realtimeAtKey, now.millisecondsSinceEpoch);
  }

  static Future<bool> shouldSkipFcmFor(String? solicitudId) async {
    return !(await shouldShowPush(solicitudId));
  }

  static Future<bool> shouldShowPush(String? solicitudId) async {
    final now = DateTime.now();

    if (_memoryAt != null &&
        now.difference(_memoryAt!) <= _globalThrottle &&
        (solicitudId == null ||
            solicitudId.isEmpty ||
            solicitudId == _memoryId)) {
      return false;
    }

    if (solicitudId == null || solicitudId.isEmpty) {
      return true;
    }

    final prefs = await SharedPreferences.getInstance();
    for (final entry in [
      (_realtimeIdKey, _realtimeAtKey),
      (_pushIdKey, _pushAtKey),
    ]) {
      final lastId = prefs.getString(entry.$1);
      final lastAt = prefs.getInt(entry.$2);
      if (lastId == solicitudId && lastAt != null) {
        final age = now.difference(
          DateTime.fromMillisecondsSinceEpoch(lastAt),
        );
        if (age <= _ttl) return false;
      }
    }

    if (_memoryId == solicitudId &&
        _memoryAt != null &&
        now.difference(_memoryAt!) <= _ttl) {
      return false;
    }

    return true;
  }
}
