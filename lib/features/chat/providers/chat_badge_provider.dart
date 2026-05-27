import 'dart:async';

import 'package:flutter/foundation.dart';

import '../services/chat_taxi_service.dart';

class ChatBadgeProvider extends ChangeNotifier {
  final ChatTaxiService _chatService = ChatTaxiService();

  final Map<int, int> _noLeidos = {};
  int? _monitoredServicioId;
  Timer? _pollTimer;

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

  /// Polling mientras hay servicio activo (evita pisar handlers Pusher del chat).
  Future<void> iniciarMonitoreo(int servicioId, int miUserId) async {
    if (servicioId <= 0 || miUserId <= 0) return;
    if (_monitoredServicioId == servicioId) {
      await actualizarNoLeidos(servicioId);
      return;
    }
    await detenerMonitoreo();
    _monitoredServicioId = servicioId;
    await actualizarNoLeidos(servicioId);
    _pollTimer = Timer.periodic(
      const Duration(seconds: 20),
      (_) => actualizarNoLeidos(servicioId),
    );
  }

  Future<void> detenerMonitoreo() async {
    _pollTimer?.cancel();
    _pollTimer = null;
    _monitoredServicioId = null;
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }
}
