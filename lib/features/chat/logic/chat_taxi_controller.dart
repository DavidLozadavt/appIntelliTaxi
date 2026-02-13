// lib/features/chat/logic/chat_taxi_controller.dart

import 'package:flutter/material.dart';
import '../data/mensaje_taxi_model.dart';
import '../services/chat_taxi_service.dart';

class ChatTaxiController extends ChangeNotifier {
  final ChatTaxiService _service;
  final int servicioId;
  final int miUserId;

  List<MensajeTaxi> _mensajes = [];
  bool _cargando = false;
  String? _error;
  Map<String, dynamic>? _infoChat;
  bool _pusherInicializado = false;

  ChatTaxiController({
    required ChatTaxiService service,
    required this.servicioId,
    required this.miUserId,
  }) : _service = service;

  // Getters
  List<MensajeTaxi> get mensajes => _mensajes;
  bool get cargando => _cargando;
  String? get error => _error;
  Map<String, dynamic>? get infoChat => _infoChat;
  bool get pusherInicializado => _pusherInicializado;

  /// Obtener nombre del otro usuario
  String get nombreOtroUsuario {
    if (_infoChat == null) return 'Usuario';
    final soyConductor = _infoChat!['soy_conductor'] ?? false;
    final otro = soyConductor
        ? _infoChat!['pasajero']
        : _infoChat!['conductor'];
    return otro?['nombre'] ?? 'Usuario';
  }

  /// Obtener foto del otro usuario
  String? get fotoOtroUsuario {
    if (_infoChat == null) return null;
    final soyConductor = _infoChat!['soy_conductor'] ?? false;
    final otro = soyConductor
        ? _infoChat!['pasajero']
        : _infoChat!['conductor'];
    return otro?['foto'];
  }

  /// Obtener rol del otro usuario
  String get rolOtroUsuario {
    if (_infoChat == null) return '';
    final soyConductor = _infoChat!['soy_conductor'] ?? false;
    return soyConductor ? 'Pasajero' : 'Conductor';
  }

  /// Inicializar el chat
  Future<void> inicializar() async {
    _cargando = true;
    _error = null;
    notifyListeners();

    try {
      // Cargar info del chat
      _infoChat = await _service.obtenerInfoChat(servicioId);

      if (_infoChat == null) {
        _error = 'No se pudo cargar la información del chat';
        _cargando = false;
        notifyListeners();
        return;
      }

      // Cargar mensajes existentes
      _mensajes = await _service.obtenerMensajes(servicioId);
      _mensajes.sort((a, b) => a.createdAt.compareTo(b.createdAt));

      // Suscribirse al canal (usa Pusher global secundario)
      await _service.suscribirseAlChat(
        servicioId: servicioId,
        onNuevoMensaje: _onNuevoMensaje,
        onMensajeLeido: _onMensajeLeido,
      );

      _pusherInicializado = true;
      _error = null;
    } catch (e) {
      _error = 'Error al inicializar: $e';
      print('Error inicializando chat: $e');
    }

    _cargando = false;
    notifyListeners();
  }

  /// Enviar mensaje
  Future<bool> enviarMensaje(String texto, {String tipo = 'texto'}) async {
    if (texto.trim().isEmpty) return false;

    try {
      final mensaje = await _service.enviarMensaje(
        servicioId: servicioId,
        mensaje: texto.trim(),
        tipo: tipo,
      );

      if (mensaje != null) {
        // El mensaje llegará por Pusher, pero lo agregamos inmediatamente
        // para mejor UX
        if (!_mensajes.any(
          (m) =>
              m.id == mensaje.id ||
              (m.mensaje == mensaje.mensaje &&
                  m.remitenteId == mensaje.remitenteId &&
                  m.createdAt.difference(mensaje.createdAt).abs().inSeconds <
                      2),
        )) {
          _mensajes.add(mensaje);
          _mensajes.sort((a, b) => a.createdAt.compareTo(b.createdAt));
          notifyListeners();
        }
        return true;
      }

      return false;
    } catch (e) {
      print('Error enviando mensaje: $e');
      return false;
    }
  }

  /// Callback cuando llega un nuevo mensaje por Pusher
  void _onNuevoMensaje(MensajeTaxi mensaje) {
    print('📨 Nuevo mensaje recibido: ${mensaje.mensaje}');

    // Evitar duplicados
    final existe = _mensajes.any(
      (m) =>
          m.id == mensaje.id ||
          (m.mensaje == mensaje.mensaje &&
              m.remitenteId == mensaje.remitenteId &&
              m.createdAt.difference(mensaje.createdAt).abs().inSeconds < 2),
    );

    if (!existe) {
      _mensajes.add(mensaje);
      _mensajes.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      notifyListeners();

      // Si el mensaje es para mí, marcarlo como leído
      if (mensaje.destinatarioId == miUserId && !mensaje.leido) {
        _service.marcarComoLeido(servicioId, mensajeId: mensaje.id);
      }
    }
  }

  /// Callback cuando el otro usuario lee los mensajes
  void _onMensajeLeido(int mensajeId, int leidoPor) {
    print('✓✓ Mensaje leído: $mensajeId por $leidoPor');

    bool cambios = false;

    // Actualizar el estado de los mensajes
    for (var i = 0; i < _mensajes.length; i++) {
      if (_mensajes[i].remitenteId == miUserId && !_mensajes[i].leido) {
        _mensajes[i] = _mensajes[i].copyWith(
          leido: true,
          fechaLectura: DateTime.now(),
        );
        cambios = true;
      }
    }

    if (cambios) {
      notifyListeners();
    }
  }

  /// Marcar todos los mensajes como leídos manualmente
  Future<void> marcarTodosComoLeidos() async {
    try {
      final exito = await _service.marcarComoLeido(servicioId);
      if (exito) {
        // Actualizar mensajes localmente
        bool cambios = false;
        for (var i = 0; i < _mensajes.length; i++) {
          if (_mensajes[i].destinatarioId == miUserId && !_mensajes[i].leido) {
            _mensajes[i] = _mensajes[i].copyWith(
              leido: true,
              fechaLectura: DateTime.now(),
            );
            cambios = true;
          }
        }
        if (cambios) {
          notifyListeners();
        }
      }
    } catch (e) {
      print('Error marcando como leídos: $e');
    }
  }

  /// Recargar mensajes
  Future<void> recargarMensajes() async {
    try {
      final mensajes = await _service.obtenerMensajes(servicioId);
      _mensajes = mensajes;
      _mensajes.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      notifyListeners();
    } catch (e) {
      print('Error recargando mensajes: $e');
    }
  }

  /// Obtener cantidad de mensajes no leídos
  Future<int> obtenerNoLeidos() async {
    try {
      return await _service.obtenerNoLeidos(servicioId);
    } catch (e) {
      print('Error obteniendo no leídos: $e');
      return 0;
    }
  }

  /// Limpiar recursos
  @override
  void dispose() {
    if (_pusherInicializado) {
      _service.desuscribirse(servicioId);
    }
    _service.dispose();
    super.dispose();
  }
}
