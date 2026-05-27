import 'dart:async';

import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:intellitaxi/core/theme/app_colors.dart';
import 'package:provider/provider.dart';
import 'package:intellitaxi/features/conductor/providers/conductor_home_provider.dart';

/// Barra compacta de radio (km) para la parte inferior del mapa.
class ConductorRadioAccionBar extends StatefulWidget {
  const ConductorRadioAccionBar({super.key});

  @override
  State<ConductorRadioAccionBar> createState() => _ConductorRadioAccionBarState();
}

class _ConductorRadioAccionBarState extends State<ConductorRadioAccionBar> {
  Timer? _debounce;
  late bool _activo;
  late double _km;

  @override
  void initState() {
    super.initState();
    final config = context.read<ConductorHomeProvider>().radioAccion;
    _activo = config.activo && !config.sinLimite;
    _km = config.radioKm ?? config.radioEfectivoKm;
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _programarGuardado(ConductorHomeProvider provider) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () async {
      if (!mounted) return;
      final error = await provider.guardarRadioAccion(
        activo: _activo,
        radioKm: _activo ? _km : null,
      );
      if (!mounted || error == null) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), behavior: SnackBarBehavior.floating),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Consumer<ConductorHomeProvider>(
      builder: (context, provider, _) {
        final config = provider.radioAccion;
        final min = config.minKm;
        final max = config.maxKm;

        return Material(
          color: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF1A1A1A)
              : Colors.white,
          child: Container(
            padding: EdgeInsets.fromLTRB(10, 4, 10, 4 + bottomInset),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: Colors.black.withValues(alpha: 0.08)),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Icon(
                      Iconsax.routing,
                      size: 15,
                      color: AppColors.accent,
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        _activo
                            ? 'Radio ${_km.round()} km'
                            : 'Sin límite',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (provider.guardandoRadioAccion)
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else
                      Transform.scale(
                        scale: 0.78,
                        child: Switch.adaptive(
                          value: _activo,
                          onChanged: (v) {
                            setState(() => _activo = v);
                            _programarGuardado(provider);
                          },
                        ),
                      ),
                  ],
                ),
                if (_activo)
                  SizedBox(
                    height: 26,
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 2,
                        thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 6,
                        ),
                        overlayShape: const RoundSliderOverlayShape(
                          overlayRadius: 10,
                        ),
                      ),
                      child: Slider(
                        value: _km.clamp(min, max),
                        min: min,
                        max: max,
                        divisions: (max - min).round().clamp(1, 49),
                        onChanged: provider.guardandoRadioAccion
                            ? null
                            : (v) {
                                setState(() => _km = v);
                                _programarGuardado(provider);
                              },
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
