import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

/// Icono de marca WhatsApp (verde #25D366).
class WhatsAppBrandIcon extends StatelessWidget {
  const WhatsAppBrandIcon({
    super.key,
    this.size = 22,
    this.solid = true,
    this.color,
  });

  final double size;
  final bool solid;
  final Color? color;

  static const Color brandGreen = Color(0xFF25D366);

  @override
  Widget build(BuildContext context) {
    final icon = FaIcon(
      FontAwesomeIcons.whatsapp,
      size: size * 0.62,
      color: Colors.white,
    );

    if (!solid || color != null) {
      return FaIcon(
        FontAwesomeIcons.whatsapp,
        size: size,
        color: color ?? brandGreen,
      );
    }

    return Container(
      width: size + 8,
      height: size + 8,
      decoration: BoxDecoration(
        color: brandGreen,
        borderRadius: BorderRadius.circular((size + 8) * 0.22),
      ),
      alignment: Alignment.center,
      child: icon,
    );
  }
}
