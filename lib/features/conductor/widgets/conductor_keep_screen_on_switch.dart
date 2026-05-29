import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:intellitaxi/core/services/keep_screen_on_service.dart';
import 'package:intellitaxi/core/theme/app_colors.dart';
import 'package:provider/provider.dart';
import 'package:intellitaxi/features/conductor/providers/conductor_home_provider.dart';

/// Switch «Pantalla siempre activa» en el menú del conductor.
class ConductorKeepScreenOnSwitch extends StatefulWidget {
  const ConductorKeepScreenOnSwitch({super.key});

  @override
  State<ConductorKeepScreenOnSwitch> createState() =>
      _ConductorKeepScreenOnSwitchState();
}

class _ConductorKeepScreenOnSwitchState
    extends State<ConductorKeepScreenOnSwitch> {
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

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.darkCard.withValues(alpha: 0.6)
            : AppColors.accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.accent.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Iconsax.mobile_copy,
            color: AppColors.accent,
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Pantalla siempre activa',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'Evita que el teléfono se apague con turno en línea',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark
                        ? Colors.grey.shade400
                        : Colors.grey.shade600,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          if (_loading)
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            Switch.adaptive(
              value: _enabled,
              activeColor: AppColors.accent,
              onChanged: _onChanged,
            ),
        ],
      ),
    );
  }
}
