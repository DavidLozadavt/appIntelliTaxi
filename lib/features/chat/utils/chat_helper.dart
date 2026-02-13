// lib/features/chat/utils/chat_helper.dart

import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../presentation/chat_taxi_screen.dart';

class ChatHelper {
  /// Abrir chat desde cualquier pantalla
  ///
  /// Parámetros:
  /// - context: BuildContext actual
  /// - servicioId: ID del servicio activo
  /// - miUserId: ID del usuario actual (conductor o pasajero)
  static Future<void> abrirChat({
    required BuildContext context,
    required int servicioId,
    required int miUserId,
  }) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            ChatTaxiScreen(servicioId: servicioId, miUserId: miUserId),
      ),
    );
  }

  /// Crear botón flotante de chat
  /// Úsalo en el servicio activo (conductor o pasajero)
  static Widget botonFlotanteChat({
    required BuildContext context,
    required int servicioId,
    required int miUserId,
    int mensajesNoLeidos = 0,
  }) {
    return FloatingActionButton(
      onPressed: () => abrirChat(
        context: context,
        servicioId: servicioId,
        miUserId: miUserId,
      ),
      backgroundColor: const Color(0xFF0084FF),
      child: Stack(
        children: [
          const Icon(Iconsax.messages_copy, color: Colors.white),

          // Badge de mensajes no leídos
          if (mensajesNoLeidos > 0)
            Positioned(
              right: 0,
              top: 0,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                child: Text(
                  mensajesNoLeidos > 9 ? '9+' : '$mensajesNoLeidos',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Crear botón de chat en AppBar
  static Widget botonAppBarChat({
    required BuildContext context,
    required int servicioId,
    required int miUserId,
    int mensajesNoLeidos = 0,
  }) {
    return Stack(
      children: [
        IconButton(
          icon:  Icon(Iconsax.messages_copy),
          onPressed: () => abrirChat(
            context: context,
            servicioId: servicioId,
            miUserId: miUserId,
          ),
        ),

        // Badge de mensajes no leídos
        if (mensajesNoLeidos > 0)
          Positioned(
            right: 8,
            top: 8,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
              constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
              child: Text(
                mensajesNoLeidos > 9 ? '9+' : '$mensajesNoLeidos',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }
}
