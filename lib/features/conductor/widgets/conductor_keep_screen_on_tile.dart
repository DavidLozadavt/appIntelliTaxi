import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:intellitaxi/core/services/keep_screen_on_service.dart';
import 'package:intellitaxi/core/theme/app_colors.dart';
import 'package:provider/provider.dart';
import 'package:intellitaxi/features/conductor/providers/conductor_home_provider.dart';

/// Opción «Pantalla siempre activa» (pantalla Ajustes).
class ConductorKeepScreenOnTile extends StatefulWidget {
  const ConductorKeepScreenOnTile({super.key});

  @override
  State<ConductorKeepScreenOnTile> createState() =>
      _ConductorKeepScreenOnTileState();
}

class _ConductorKeepScreenOnTileState extends State<ConductorKeepScreenOnTile> {
  bool _loading = true;
  bool _enabled = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await KeepScreenOnService.loadPreference();
    if (!mounted) return;
    setState(() {
      _enabled = KeepScreenOnService.userEnabled;
      _loading = false;
    });
    _syncHoldFromProvider();
  }

  void _syncHoldFromProvider() {
    final provider = context.read<ConductorHomeProvider>();
    if (!KeepScreenOnService.userEnabled) return;
    if (provider.isOnline && provider.tieneTurnoActivo) {
      KeepScreenOnService.acquire('conductor_turno');
    } else {
      KeepScreenOnService.release('conductor_turno');
    }
  }

  Future<void> _onChanged(bool value) async {
    setState(() => _enabled = value);
    await KeepScreenOnService.setUserEnabled(value);
    if (!mounted) return;
    if (value) {
      _syncHoldFromProvider();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'La pantalla permanecerá encendida mientras tengas turno activo.',
          ),
          duration: Duration(seconds: 3),
        ),
      );
    } else {
      await KeepScreenOnService.releaseAll();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pantalla siempre activa desactivada.'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.accent.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(
          Iconsax.mobile_copy,
          color: AppColors.accent,
          size: 22,
        ),
      ),
      title: const Text(
        'Pantalla siempre activa',
        style: TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        'Evita que el teléfono se apague con turno en línea',
        style: TextStyle(
          fontSize: 13,
          color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
        ),
      ),
      trailing: _loading
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Switch.adaptive(
              value: _enabled,
              activeColor: AppColors.accent,
              onChanged: _onChanged,
            ),
    );
  }
}
