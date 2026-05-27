import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intellitaxi/features/conductor/providers/conductor_home_provider.dart';
import 'package:intellitaxi/features/conductor/widgets/conductor_radio_accion_bar.dart';

/// Barra inferior fija: solo radio de acción (km).
class ConductorPendientesDock extends StatelessWidget {
  const ConductorPendientesDock({super.key});

  static double alturaEstimada(
    BuildContext context, {
    bool radioSliderVisible = false,
  }) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    final compact = MediaQuery.sizeOf(context).height < 680;
    final base = radioSliderVisible
        ? (compact ? 70.0 : 76.0)
        : (compact ? 40.0 : 44.0);
    return base + bottom;
  }

  @override
  Widget build(BuildContext context) {
    final home = context.watch<ConductorHomeProvider>();

    final visible = home.isOnline &&
        !home.enServicio &&
        !home.enDescanso &&
        home.tieneTurnoActivo;

    if (!visible) return const SizedBox.shrink();

    return const Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: ConductorRadioAccionBar(),
    );
  }
}
