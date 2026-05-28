import 'package:flutter/material.dart';

/// Opción de tono para alertas de nuevo servicio (conductor).
class ConductorNotificationSoundOption {
  const ConductorNotificationSoundOption({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.assetPath,
    required this.icon,
  });

  final String id;
  final String title;
  final String subtitle;

  /// Ruta relativa para [AssetSource] (sin prefijo `assets/`).
  final String assetPath;
  final IconData icon;
}
