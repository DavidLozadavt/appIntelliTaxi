import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:provider/provider.dart';

import '../presentation/chat_taxi_screen.dart';
import '../providers/chat_badge_provider.dart';
import '../widgets/chat_badge_wrap.dart';

class ChatHelper {
  static Future<void> abrirChat({
    required BuildContext context,
    required int servicioId,
    required int miUserId,
  }) async {
    final badge = context.read<ChatBadgeProvider>();
    badge.limpiarNoLeidos(servicioId);

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            ChatTaxiScreen(servicioId: servicioId, miUserId: miUserId),
      ),
    );

    if (context.mounted) {
      await badge.actualizarNoLeidos(servicioId);
    }
  }

  static Widget botonFlotanteChat({
    required BuildContext context,
    required int servicioId,
    required int miUserId,
  }) {
    return FloatingActionButton(
      onPressed: () => abrirChat(
        context: context,
        servicioId: servicioId,
        miUserId: miUserId,
      ),
      backgroundColor: const Color(0xFF0084FF),
      child: ChatUnreadBadge(
        servicioId: servicioId,
        child: const Icon(Iconsax.messages_copy, color: Colors.white),
      ),
    );
  }

  static Widget botonAppBarChat({
    required BuildContext context,
    required int servicioId,
    required int miUserId,
  }) {
    return ChatUnreadBadge(
      servicioId: servicioId,
      child: IconButton(
        icon: const Icon(Iconsax.messages_copy),
        onPressed: () => abrirChat(
          context: context,
          servicioId: servicioId,
          miUserId: miUserId,
        ),
      ),
    );
  }
}
