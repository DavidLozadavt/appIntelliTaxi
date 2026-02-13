// lib/features/chat/logic/chat_badge_provider.dart

import 'package:flutter/foundation.dart';
import '../services/chat_taxi_service.dart';

class ChatBadgeProvider extends ChangeNotifier {
  final ChatTaxiService _chatService = ChatTaxiService();
  
  // Mapa de servicioId -> cantidad de no leídos
  final Map<int, int> _noLeidos = {};
  
  int getNoLeidos(int servicioId) => _noLeidos[servicioId] ?? 0;
  
  /// Actualizar contador de no leídos para un servicio específico
  Future<void> actualizarNoLeidos(int servicioId) async {
    final cantidad = await _chatService.obtenerNoLeidos(servicioId);
    if (_noLeidos[servicioId] != cantidad) {
      _noLeidos[servicioId] = cantidad;
      notifyListeners();
    }
  }
  
  /// Limpiar contador al abrir el chat
  void limpiarNoLeidos(int servicioId) {
    if (_noLeidos.containsKey(servicioId)) {
      _noLeidos[servicioId] = 0;
      notifyListeners();
    }
  }
  
  /// Incrementar contador cuando llega un mensaje nuevo
  void incrementarNoLeidos(int servicioId) {
    _noLeidos[servicioId] = (_noLeidos[servicioId] ?? 0) + 1;
    notifyListeners();
  }
}
