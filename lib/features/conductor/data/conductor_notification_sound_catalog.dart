import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:intellitaxi/features/conductor/data/conductor_notification_sound_option.dart';

/// Catálogo de tonos disponibles para nuevas solicitudes.
class ConductorNotificationSoundCatalog {
  ConductorNotificationSoundCatalog._();

  static const String defaultSoundId = 'taxbel_clasico';

  static const List<ConductorNotificationSoundOption> options = [
    ConductorNotificationSoundOption(
      id: 'taxbel_clasico',
      title: 'Taxbel clásico',
      subtitle: 'El tono oficial de la flota',
      assetPath: 'sound/nuevoServicio.mp3',
      icon: Iconsax.music_dashboard_copy,
    ),
    ConductorNotificationSoundOption(
      id: 'oferta_rapida',
      title: 'Oferta rápida',
      subtitle: 'Corto y directo para no perder tiempo',
      assetPath: 'sound/nuevaoferta.mp3',
      icon: Iconsax.flash_1_copy,
    ),
    ConductorNotificationSoundOption(
      id: 'campana_suave',
      title: 'Campana suave',
      subtitle: 'Discreto, ideal si conduces de noche',
      assetPath: 'sound/universfield-new-notification-022-370046.mp3',
      icon: Iconsax.notification_bing_copy,
    ),
    ConductorNotificationSoundOption(
      id: 'tono_brillante',
      title: 'Tono brillante',
      subtitle: 'Más llamativo en calles con ruido',
      assetPath: 'sound/universfield-new-notification-053-494247.mp3',
      icon: Iconsax.volume_high_copy,
    ),
    ConductorNotificationSoundOption(
      id: 'chime_moderno',
      title: 'Chime moderno',
      subtitle: 'Estilo actual, claro y equilibrado',
      assetPath: 'sound/universfield-new-notification-059-494262.mp3',
      icon: Iconsax.musicnote_copy,
    ),
    ConductorNotificationSoundOption(
      id: 'pulso_corto',
      title: 'Pulso corto',
      subtitle: 'Breve y enérgico',
      assetPath: 'sound/universfield-new-notification-046-494237.mp3',
      icon: Iconsax.activity_copy,
    ),
    ConductorNotificationSoundOption(
      id: 'alerta_ligera',
      title: 'Alerta ligera',
      subtitle: 'Suave pero fácil de distinguir',
      assetPath: 'sound/universfield-new-notification-048-494235.mp3',
      icon: Iconsax.microphone_2_copy,
    ),
    ConductorNotificationSoundOption(
      id: 'notificacion_profunda',
      title: 'Notificación profunda',
      subtitle: 'Más grave, buena en ambientes ruidosos',
      assetPath: 'sound/universfield-new-notification-065-494546.mp3',
      icon: Iconsax.notification_bing_copy,
    ),
    ConductorNotificationSoundOption(
      id: 'timbre_clasico',
      title: 'Timbre clásico',
      subtitle: 'Estilo ringtone tradicional',
      assetPath: 'sound/universfield-ringtone-055-494939.mp3',
      icon: Iconsax.call_copy,
    ),
    ConductorNotificationSoundOption(
      id: 'movil_claro',
      title: 'Móvil claro',
      subtitle: 'Limpio, como notificación de celular',
      assetPath: 'sound/universfield-clear-mobile-notification-487900.mp3',
      icon: Iconsax.mobile_copy,
    ),
    ConductorNotificationSoundOption(
      id: 'simple_nitido',
      title: 'Simple y nítido',
      subtitle: 'Minimalista, sin distracciones',
      assetPath: 'sound/universfield-simple-notification-152054.mp3',
      icon: Iconsax.tick_circle_copy,
    ),
  ];

  static ConductorNotificationSoundOption get defaultOption =>
      byId(defaultSoundId) ?? options.first;

  static ConductorNotificationSoundOption? byId(String? id) {
    if (id == null || id.isEmpty) return null;
    for (final o in options) {
      if (o.id == id) return o;
    }
    return null;
  }
}
