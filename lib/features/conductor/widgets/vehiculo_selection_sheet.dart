import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:intellitaxi/core/theme/app_colors.dart';
import 'package:intellitaxi/features/conductor/data/vehiculo_conductor_model.dart';

class VehiculoSelectionSheet extends StatefulWidget {
  final List<VehiculoConductor> vehiculos;
  final Map<int, int> vencidosPorVehiculo;
  final int maxVencidosBloqueo;
  final Function(VehiculoConductor) onVehiculoSelected;

  const VehiculoSelectionSheet({
    super.key,
    required this.vehiculos,
    this.vencidosPorVehiculo = const {},
    this.maxVencidosBloqueo = 2,
    required this.onVehiculoSelected,
  });

  @override
  State<VehiculoSelectionSheet> createState() => _VehiculoSelectionSheetState();
}

class _VehiculoSelectionSheetState extends State<VehiculoSelectionSheet> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final backgroundColor = isDarkMode ? AppColors.darkCard : Colors.white;
    final textColor = isDarkMode ? AppColors.darkOnSurface : Colors.black87;
    final subtextColor = isDarkMode
        ? AppColors.darkOnSurface.withValues(alpha: 0.72)
        : Colors.black54;

    final orderedVehiculos = _orderedVehiculos();
    final disponibles = orderedVehiculos
        .where((vehiculo) => !_isBloqueado(vehiculo))
        .toList();
    final bloqueados = orderedVehiculos
        .where((vehiculo) => _isBloqueado(vehiculo))
        .toList();

    return SafeArea(
      top: false,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.50,
        ),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(28),
            topRight: Radius.circular(28),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 52,
              height: 5,
              decoration: BoxDecoration(
                color: isDarkMode ? Colors.grey.shade700 : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            _buildHeader(context, textColor, subtextColor, isDarkMode),
            const SizedBox(height: 5),
            _buildSummaryRow(
              isDarkMode: isDarkMode,
              disponibles: disponibles.length,
              bloqueados: bloqueados.length,
              total: orderedVehiculos.length,
            ),
            const SizedBox(height: 8),
            Flexible(
              child: widget.vehiculos.isEmpty
                  ? _buildEmptyState()
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      children: [
                        if (disponibles.isNotEmpty) ...[
                          _buildSectionTitle(
                            title: 'Listos para iniciar turno',
                            subtitle:
                                'Toca cualquiera para empezar mas rapido.',
                            color: AppColors.primary,
                          ),
                          const SizedBox(height: 8),
                          ...disponibles.map(
                            (vehiculo) =>
                                _buildVehiculoCard(context, vehiculo),
                          ),
                        ],
                        if (bloqueados.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          _buildSectionTitle(
                            title: 'No disponibles ahora',
                            subtitle:
                                'Tienen documentos vencidos o restricciones.',
                            color: Colors.orange,
                          ),
                          const SizedBox(height: 8),
                          ...bloqueados.map(
                            (vehiculo) =>
                                _buildVehiculoCard(context, vehiculo),
                          ),
                        ],
                      ],
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    backgroundColor: isDarkMode
                        ? Colors.white.withValues(alpha: 0.04)
                        : AppColors.primary.withValues(alpha: 0.06),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    'Cerrar',
                    style: TextStyle(
                      color: isDarkMode
                          ? Colors.grey.shade300
                          : AppColors.primary,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    Color textColor,
    Color subtextColor,
    bool isDarkMode,
  ) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.accent.withValues(alpha: isDarkMode ? 0.18 : 0.10),
            AppColors.secondary.withValues(alpha: isDarkMode ? 0.14 : 0.07),
          ],
        ),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(28),
          topRight: Radius.circular(28),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.primary, AppColors.secondary],
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.28),
                  blurRadius: 12,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: const Icon(
              Iconsax.car_copy,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Selecciona tu vehiculo',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: textColor,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Elige el vehiculo con el que quieres iniciar turno.',
                  style: TextStyle(
                    fontSize: 13,
                    color: subtextColor,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow({
    required bool isDarkMode,
    required int disponibles,
    required int bloqueados,
    required int total,
  }) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildInfoChip(
            label: '$disponibles listos',
            color: AppColors.primary,
            isDarkMode: isDarkMode,
          ),
          const SizedBox(width: 8),
          _buildInfoChip(
            label: '$bloqueados bloqueados',
            color: bloqueados > 0 ? Colors.orange : Colors.grey,
            isDarkMode: isDarkMode,
          ),
          const SizedBox(width: 8),
          _buildInfoChip(
            label: '$total en lista',
            color: AppColors.secondary,
            isDarkMode: isDarkMode,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip({
    required String label,
    required Color color,
    required bool isDarkMode,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDarkMode ? 0.18 : 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.16)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  Widget _buildSectionTitle({
    required String title,
    required String subtitle,
    required Color color,
  }) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, right: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(fontSize: 12, color: color.withValues(alpha: 0.8)),
          ),
        ],
      ),
    );
  }

  Widget _buildVehiculoCard(BuildContext context, VehiculoConductor vehiculo) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDarkMode ? AppColors.darkOnSurface : Colors.black87;
    final subtextColor = isDarkMode
        ? Colors.grey.shade400
        : Colors.grey.shade600;
    final vencidos = widget.vencidosPorVehiculo[vehiculo.id] ?? 0;
    final bloqueado = _isBloqueado(vehiculo);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: bloqueado
              ? (isDarkMode
                    ? [
                        Colors.orange.withValues(alpha: 0.14),
                        Colors.red.withValues(alpha: 0.08),
                      ]
                    : [
                        Colors.orange.withValues(alpha: 0.08),
                        Colors.red.withValues(alpha: 0.04),
                      ])
              : (isDarkMode
                    ? [
                        AppColors.darkCard,
                        AppColors.secondary.withValues(alpha: 0.10),
                      ]
                    : [
                        Colors.white,
                        AppColors.primary.withValues(alpha: 0.03),
                      ]),
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: bloqueado
              ? Colors.orange.withValues(alpha: 0.38)
              : AppColors.primary.withValues(alpha: isDarkMode ? 0.32 : 0.16),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: bloqueado
                ? Colors.orange.withValues(alpha: 0.10)
                : AppColors.primary.withValues(alpha: isDarkMode ? 0.14 : 0.08),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: bloqueado
              ? null
              : () {
                  Navigator.pop(context);
                  widget.onVehiculoSelected(vehiculo);
                },
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: isDarkMode
                        ? Colors.white.withValues(alpha: 0.06)
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: vehiculo.rutaUrl != null && vehiculo.rutaUrl!.isNotEmpty
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Image.network(
                            vehiculo.rutaUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => _buildCarPlaceholder(),
                          ),
                        )
                      : _buildCarPlaceholder(),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    vehiculo.placa,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                      letterSpacing: 1.0,
                                    ),
                                  ),
                                ),
                                _buildStatusBadge(
                                  bloqueado: bloqueado,
                                  vencidos: vencidos,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            bloqueado
                                ? Icons.lock_outline_rounded
                                : Iconsax.arrow_right_3_copy,
                            size: 18,
                            color: bloqueado ? Colors.orange : AppColors.primary,
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '${vehiculo.marca?.marca ?? 'Vehiculo'} ${vehiculo.modelo?.modelo ?? ''}'
                            .trim(),
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _buildMetaPill(
                            icon: Iconsax.info_circle_copy,
                            label: vehiculo.tipoVehiculo?.tipo ?? 'Sin tipo',
                            color: subtextColor,
                            isDarkMode: isDarkMode,
                          ),
                          _buildMetaPill(
                            icon: Iconsax.profile_2user_copy,
                            label: '${vehiculo.numPuestos} puestos',
                            color: subtextColor,
                            isDarkMode: isDarkMode,
                          ),
                          if ((vehiculo.color ?? '').trim().isNotEmpty)
                            _buildMetaPill(
                              icon: Icons.palette_outlined,
                              label: vehiculo.color!.trim(),
                              color: subtextColor,
                              isDarkMode: isDarkMode,
                            ),
                        ],
                      ),
                      if (!bloqueado) ...[
                        const SizedBox(height: 10),
                        Text(
                          'Toca para iniciar turno con este vehiculo',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary.withValues(alpha: 0.86),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge({required bool bloqueado, required int vencidos}) {
    final color = bloqueado ? Colors.orange : AppColors.green;
    final background = bloqueado
        ? Colors.orange.withValues(alpha: 0.14)
        : AppColors.green.withValues(alpha: 0.14);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        bloqueado
            ? '$vencidos doc. vencido${vencidos == 1 ? '' : 's'}'
            : 'Disponible',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }

  Widget _buildMetaPill({
    required IconData icon,
    required String label,
    required Color color,
    required bool isDarkMode,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: isDarkMode
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.black.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCarPlaceholder() {
    return Icon(Iconsax.car_copy, size: 36, color: Colors.grey.shade400);
  }

  Widget _buildEmptyState() {
    return Builder(
      builder: (context) {
        final isDarkMode = Theme.of(context).brightness == Brightness.dark;
        final textColor = isDarkMode ? AppColors.darkOnSurface : Colors.black87;
        final subtextColor = isDarkMode
            ? Colors.grey.shade500
            : Colors.grey.shade600;

        return Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Iconsax.car_copy,
                  size: 64,
                  color: isDarkMode
                      ? Colors.grey.shade700
                      : Colors.grey.shade300,
                ),
                const SizedBox(height: 16),
                Text(
                  'No tienes vehiculos asignados',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Contacta con tu administrador para asignarte un vehiculo.',
                  style: TextStyle(fontSize: 14, color: subtextColor),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  bool _isBloqueado(VehiculoConductor vehiculo) {
    final vencidos = widget.vencidosPorVehiculo[vehiculo.id] ?? 0;
    return vencidos >= widget.maxVencidosBloqueo;
  }

  List<VehiculoConductor> _orderedVehiculos() {
    final sorted = [...widget.vehiculos]
      ..sort((a, b) {
        final bloqueadoA = _isBloqueado(a);
        final bloqueadoB = _isBloqueado(b);
        if (bloqueadoA != bloqueadoB) {
          return bloqueadoA ? 1 : -1;
        }
        return a.placa.compareTo(b.placa);
      });
    return sorted;
  }
}
