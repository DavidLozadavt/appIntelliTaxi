import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:intellitaxi/features/chat/data/mensaje_taxi_model.dart';
import 'package:intellitaxi/features/chat/services/chat_taxi_realtime_hub.dart';
import 'package:intellitaxi/features/chat/services/chat_taxi_service.dart';

class ChatBadgeProvider extends ChangeNotifier {
  final ChatTaxiService _chatService = ChatTaxiService();

  final Map<int, int> _noLeidos = {};
  int? _monitoredServicioId;
  int? _miUserId;
  Timer? _pollTimer;
  void Function(MensajeTaxi)? _socketListener;

  int getNoLeidos(int servicioId) => _noLeidos[servicioId] ?? 0;

  Future<void> actualizarNoLeidos(int servicioId) async {
    if (servicioId <= 0) return;
    final cantidad = await _chatService.obtenerNoLeidos(servicioId);
    if (_noLeidos[servicioId] != cantidad) {
      _noLeidos[servicioId] = cantidad;
      notifyListeners();
    }
  }

  void limpiarNoLeidos(int servicioId) {
    if ((_noLeidos[servicioId] ?? 0) == 0) return;
    _noLeidos[servicioId] = 0;
    notifyListeners();
  }

  void incrementarNoLeidos(int servicioId) {
    _noLeidos[servicioId] = (_noLeidos[servicioId] ?? 0) + 1;
    notifyListeners();
  }

  /// Socket VPS + polling de respaldo mientras hay servicio activo.
  Future<void> iniciarMonitoreo(int servicioId, int miUserId) async {
    if (servicioId <= 0 || miUserId <= 0) return;
    if (_monitoredServicioId == servicioId && _socketListener != null) {
      await actualizarNoLeidos(servicioId);
      return;
    }
    await detenerMonitoreo();

    _monitoredServicioId = servicioId;
    _miUserId = miUserId;

    await _chatService.mantenerCanalActivo(servicioId);

    _socketListener = (MensajeTaxi m) {
      if (m.destinatarioId == miUserId) {
        incrementarNoLeidos(servicioId);
      }
    };
    ChatTaxiRealtimeHub.addMensajeListener(servicioId, _socketListener!);

    await actualizarNoLeidos(servicioId);

    _pollTimer = Timer.periodic(
      const Duration(seconds: 45),
      (_) => actualizarNoLeidos(servicioId),
    );
  }

  Future<void> detenerMonitoreo() async {
    _pollTimer?.cancel();
    _pollTimer = null;

    final sid = _monitoredServicioId;
    final listener = _socketListener;
    if (sid != null && listener != null) {
      ChatTaxiRealtimeHub.removeMensajeListener(sid, listener);
    }

    _socketListener = null;
    _monitoredServicioId = null;
    _miUserId = null;
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }
}
