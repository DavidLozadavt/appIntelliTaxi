import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:intellitaxi/core/theme/app_colors.dart';
import 'package:intellitaxi/features/conductor/data/conductor_notification_sound_catalog.dart';
import 'package:intellitaxi/features/conductor/data/conductor_notification_sound_option.dart';
import 'package:intellitaxi/features/conductor/services/conductor_notification_sound_prefs.dart';
import 'package:intellitaxi/features/conductor/services/conductor_notification_sound_service.dart';

/// Pantalla para que el conductor elija el tono de nuevas solicitudes.
class ConductorNotificationSoundScreen extends StatefulWidget {
  const ConductorNotificationSoundScreen({super.key});

  @override
  State<ConductorNotificationSoundScreen> createState() =>
      _ConductorNotificationSoundScreenState();
}

class _ConductorNotificationSoundScreenState
    extends State<ConductorNotificationSoundScreen> {
  String? _selectedId;
  String? _previewingId;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSelection();
  }

  @override
  void dispose() {
    ConductorNotificationSoundService.stopPreview();
    super.dispose();
  }

  Future<void> _loadSelection() async {
    final id = await ConductorNotificationSoundPrefs.getSelectedSoundId();
    if (!mounted) return;
    setState(() {
      _selectedId = id;
      _loading = false;
    });
  }

  Future<void> _select(ConductorNotificationSoundOption option) async {
    HapticFeedback.selectionClick();
    await ConductorNotificationSoundPrefs.setSelectedSoundId(option.id);
    if (!mounted) return;
    setState(() {
      _selectedId = option.id;
      _previewingId = option.id;
    });
    await ConductorNotificationSoundService.preview(option.assetPath);
    if (!mounted) return;
    setState(() => _previewingId = null);
  }

  Future<void> _replay(ConductorNotificationSoundOption option) async {
    HapticFeedback.lightImpact();
    setState(() => _previewingId = option.id);
    await ConductorNotificationSoundService.preview(option.assetPath);
    if (!mounted) return;
    setState(() => _previewingId = null);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : const Color(0xFFF6F4F5),
      appBar: AppBar(
        title: const Text(
          'Sonido de servicios',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.brandWineDark,
                  AppColors.primary,
                ],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
            ),
            child: Text(
              'Elige el tono al llegar una nueva solicitud. Toca una opción para guardarla y escucharla.',
              style: TextStyle(
                fontSize: 13,
                height: 1.3,
                color: Colors.white.withValues(alpha: 0.95),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    itemCount: ConductorNotificationSoundCatalog.options.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final option =
                          ConductorNotificationSoundCatalog.options[index];
                      return _SoundOptionCard(
                        option: option,
                        selected: _selectedId == option.id,
                        previewing: _previewingId == option.id,
                        isDark: isDark,
                        onSelect: () => _select(option),
                        onReplay: () => _replay(option),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _SoundOptionCard extends StatelessWidget {
  const _SoundOptionCard({
    required this.option,
    required this.selected,
    required this.previewing,
    required this.isDark,
    required this.onSelect,
    required this.onReplay,
  });

  final ConductorNotificationSoundOption option;
  final bool selected;
  final bool previewing;
  final bool isDark;
  final VoidCallback onSelect;
  final VoidCallback onReplay;

  @override
  Widget build(BuildContext context) {
    final borderColor = selected ? AppColors.accent : Colors.transparent;
    final cardColor = isDark ? AppColors.darkCard : Colors.white;

    return Material(
      color: cardColor,
      elevation: selected ? 3 : 0,
      shadowColor: AppColors.accent.withValues(alpha: 0.25),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onSelect,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: borderColor,
              width: selected ? 2 : 1,
            ),
            color: selected
                ? AppColors.accent.withValues(alpha: isDark ? 0.12 : 0.06)
                : cardColor,
          ),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: LinearGradient(
                    colors: selected
                        ? [AppColors.accent, AppColors.brandWineLight]
                        : [
                            (isDark ? Colors.white : Colors.black)
                                .withValues(alpha: 0.06),
                            (isDark ? Colors.white : Colors.black)
                                .withValues(alpha: 0.03),
                          ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Icon(
                  option.icon,
                  color: selected ? Colors.white : AppColors.accent,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      option.title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      option.subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.3,
                        color: isDark ? Colors.white60 : Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: previewing ? null : onReplay,
                tooltip: 'Escuchar',
                visualDensity: VisualDensity.compact,
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.accent.withValues(alpha: 0.12),
                  foregroundColor: AppColors.accent,
                ),
                icon: previewing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Iconsax.play_circle_copy, size: 22),
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: selected
                    ? const Icon(
                        Icons.check_circle_rounded,
                        key: ValueKey('on'),
                        color: AppColors.accent,
                        size: 26,
                      )
                    : Icon(
                        Icons.circle_outlined,
                        key: const ValueKey('off'),
                        color: Colors.grey.shade400,
                        size: 26,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
