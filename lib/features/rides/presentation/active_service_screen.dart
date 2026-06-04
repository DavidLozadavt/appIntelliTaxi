import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:intellitaxi/features/rides/data/servicio_activo_model.dart';
import 'package:intellitaxi/features/rides/providers/active_service_provider.dart';
import 'package:intellitaxi/core/theme/app_colors.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:intellitaxi/shared/widgets/standard_map.dart';
import 'package:intellitaxi/shared/widgets/cancelacion_servicio_dialog.dart';
import 'package:intellitaxi/features/chat/utils/chat_helper.dart';
import 'package:intellitaxi/features/chat/widgets/chat_badge_wrap.dart';
import 'package:intellitaxi/features/auth/providers/auth_provider.dart';
import 'package:intellitaxi/core/utils/phone_launcher.dart';
import 'package:intellitaxi/shared/optimized_image_widgets.dart';

class ActiveServiceScreen extends StatelessWidget {
  final ServicioActivo servicio;
  final VoidCallback? onServiceCompleted;

  const ActiveServiceScreen({
    super.key,
    required this.servicio,
    this.onServiceCompleted,
  });

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ActiveServiceProvider(
        servicio: servicio,
        onServiceCompleted: onServiceCompleted,
      ),
      child: ChatBadgeLifecycle(
        servicioId: servicio.id,
        child: Consumer<ActiveServiceProvider>(
        builder: (context, provider, _) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          final isServiceActive = provider.isServiceActive;
          final servicio = provider.servicio;

          return PopScope(
            canPop: !isServiceActive,
            onPopInvokedWithResult: (didPop, _) {
              if (!didPop && isServiceActive) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'No puedes salir hasta que el servicio termine',
                    ),
                    backgroundColor: AppColors.accent,
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            },
            child: Scaffold(
              appBar: AppBar(
                title: const Text('Servicio Activo'),
                automaticallyImplyLeading: !isServiceActive,
              ),
              body: Stack(
                children: [
                  StandardMap(
                    initialPosition: LatLng(
                      servicio.origenLat,
                      servicio.origenLng,
                    ),
                    zoom: 14,
                    markers: provider.markers,
                    polylines: provider.polylines,
                    onMapCreated: provider.setMapController,
                  ),

                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Container(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.sizeOf(context).height * 0.52,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(20),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 15,
                            offset: const Offset(0, -3),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            margin: const EdgeInsets.only(top: 12),
                            width: 50,
                            height: 5,
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                          Flexible(
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  _buildEstadoCompacto(provider, servicio),
                                  if (servicio.conductor != null) ...[
                                    const SizedBox(height: 12),
                                    _buildBarraConductor(context, servicio),
                                  ],
                                  const SizedBox(height: 12),
                                  _buildRutaUnificada(isDark, servicio),
                                  const SizedBox(height: 10),
                                  _buildViajeChips(isDark, servicio),
                                ],
                              ),
                            ),
                          ),
                          if (isServiceActive &&
                              servicio.idEstado != 5 &&
                              servicio.idEstado != 6)
                            Padding(
                              padding: EdgeInsets.fromLTRB(
                                16,
                                4,
                                16,
                                12 + MediaQuery.paddingOf(context).bottom,
                              ),
                              child: _buildCancelButton(context, provider),
                            )
                          else
                            SizedBox(
                              height: 12 + MediaQuery.paddingOf(context).bottom,
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
      ),
    );
  }

  Widget _buildEstadoCompacto(
    ActiveServiceProvider provider,
    ServicioActivo servicio,
  ) {
    final color = provider.getStateColor();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(_getStateIcon(servicio.idEstado), color: color, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  servicio.estado.estado,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
                Text(
                  provider.getStateMessage(),
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBarraConductor(BuildContext context, ServicioActivo servicio) {
    final conductor = servicio.conductor!;
    final vehiculo = servicio.vehiculo;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            SafeCircleAvatar(
              radius: 24,
              imageUrl: conductor.foto,
              backgroundColor: AppColors.primary,
              fallback: const Icon(
                Iconsax.user_copy,
                color: Colors.white,
                size: 26,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    conductor.nombre,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  if (conductor.calificacion != null)
                    Row(
                      children: [
                        const Icon(Icons.star, color: Colors.amber, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          conductor.calificacion!.toStringAsFixed(1),
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            if (conductor.telefono != null)
              _buildAccionRapida(
                icon: Iconsax.call,
                color: AppColors.green,
                tooltip: 'Llamar',
                onTap: () => _llamarConductor(context, conductor.telefono!),
              ),
            const SizedBox(width: 6),
            _buildAccionRapida(
              icon: Iconsax.messages_copy,
              color: AppColors.accent,
              tooltip: 'Mensaje',
              onTap: () => _abrirChat(context),
              servicioIdBadge: servicio.id,
            ),
          ],
        ),
        if (vehiculo != null) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : Colors.black.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(Iconsax.car_copy, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${vehiculo.marca ?? ''} ${vehiculo.modelo ?? ''} ${vehiculo.color ?? ''}'
                        .trim(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (vehiculo.placa != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.primary),
                    ),
                    child: Text(
                      vehiculo.placa!,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildAccionRapida({
    required IconData icon,
    required Color color,
    required String tooltip,
    required VoidCallback onTap,
    int? servicioIdBadge,
  }) {
    Widget iconWidget = Icon(icon, color: color, size: 24);
    if (servicioIdBadge != null && servicioIdBadge > 0) {
      iconWidget = ChatUnreadBadge(
        servicioId: servicioIdBadge,
        child: iconWidget,
      );
    }

    return Material(
      color: color.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Tooltip(
          message: tooltip,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: iconWidget,
          ),
        ),
      ),
    );
  }

  Widget _buildRutaUnificada(bool isDark, ServicioActivo servicio) {
    final enCurso = servicio.idEstado == 5;
    final recogidaActiva = !enCurso;

    final origenNombre =
        (servicio.origenName != null && servicio.origenName!.trim().isNotEmpty)
        ? servicio.origenName!
        : servicio.origenAddress;
    final destinoNombre =
        (servicio.destinoName != null &&
            servicio.destinoName!.trim().isNotEmpty)
        ? servicio.destinoName!
        : servicio.destinoAddress;

    final origenSubtitulo =
        servicio.origenAddress.trim().isNotEmpty &&
            servicio.origenAddress != origenNombre
        ? servicio.origenAddress
        : '';
    final destinoSubtitulo =
        servicio.destinoAddress.trim().isNotEmpty &&
            servicio.destinoAddress != destinoNombre
        ? servicio.destinoAddress
        : '';

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.06)
            : Colors.black.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: (recogidaActiva ? AppColors.accent : AppColors.green)
              .withValues(alpha: 0.35),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildParadaRuta(
            icon: Iconsax.location_add,
            label: 'RECOGIDA',
            nombre: origenNombre,
            subtitulo: origenSubtitulo,
            color: AppColors.accent,
            activa: recogidaActiva,
            isDark: isDark,
          ),
          Padding(
            padding: const EdgeInsets.only(left: 11, top: 6, bottom: 6),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                width: 2,
                height: 18,
                color: Colors.grey.withValues(alpha: 0.35),
              ),
            ),
          ),
          _buildParadaRuta(
            icon: Iconsax.location,
            label: 'DESTINO',
            nombre: destinoNombre,
            subtitulo: destinoSubtitulo,
            color: AppColors.green,
            activa: enCurso,
            resaltada: true,
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildParadaRuta({
    required IconData icon,
    required String label,
    required String nombre,
    required String subtitulo,
    required Color color,
    required bool activa,
    required bool isDark,
    bool resaltada = false,
  }) {
    final mostrarGrande = activa;
    final bordeVisible = activa || resaltada;

    return Container(
      padding: EdgeInsets.all(bordeVisible ? 12 : 0),
      decoration: bordeVisible
          ? BoxDecoration(
              color: color.withValues(alpha: isDark ? 0.14 : 0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: color.withValues(alpha: activa ? 0.55 : 0.35),
                width: activa ? 2 : 1.2,
              ),
            )
          : null,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: mostrarGrande ? 22 : 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: color,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  nombre,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: mostrarGrande ? 26 : 16,
                    fontWeight: mostrarGrande ? FontWeight.w900 : FontWeight.w700,
                    height: 1.12,
                    color: activa
                        ? (isDark ? Colors.white : Colors.black87)
                        : (isDark ? Colors.grey.shade400 : Colors.grey.shade700),
                  ),
                ),
                if (subtitulo.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitulo,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: mostrarGrande ? 14 : 12,
                      fontWeight: FontWeight.w500,
                      height: 1.25,
                      color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildViajeChips(bool isDark, ServicioActivo servicio) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.04)
            : Colors.black.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          if (servicio.distanciaTexto != null)
            _buildInfoChip(Iconsax.routing_copy, servicio.distanciaTexto!, isDark),
          if (servicio.duracionTexto != null)
            _buildInfoChip(Iconsax.clock_copy, servicio.duracionTexto!, isDark),
          _buildInfoChip(
            Iconsax.dollar_circle_copy,
            '\$${servicio.precioEstimado.toStringAsFixed(0)}',
            isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String text, bool isDark) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: AppColors.accent),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildCancelButton(
    BuildContext context,
    ActiveServiceProvider provider,
  ) {
    return TextButton.icon(
      onPressed: () => _mostrarDialogoCancelacion(context, provider),
      icon: Icon(Iconsax.close_circle, color: Colors.red.shade600, size: 20),
      label: Text(
        'Cancelar servicio',
        style: TextStyle(
          color: Colors.red.shade600,
          fontWeight: FontWeight.w700,
          fontSize: 14,
        ),
      ),
    );
  }

  IconData _getStateIcon(int idEstado) {
    switch (idEstado) {
      case 1:
        return Iconsax.clock_copy;
      case 2:
        return Iconsax.tick_circle_copy;
      case 3:
        return Iconsax.car_copy;
      case 4:
        return Iconsax.location_copy;
      case 5:
        return Iconsax.routing_2_copy;
      case 6:
        return Iconsax.flag_copy;
      case 7:
        return Iconsax.close_circle_copy;
      default:
        return Iconsax.info_circle_copy;
    }
  }

  Future<void> _abrirChat(BuildContext context) async {
    final authProvider = context.read<AuthProvider>();
    await ChatHelper.abrirChat(
      context: context,
      servicioId: servicio.id,
      miUserId: authProvider.userId ?? 0,
    );
  }

  Future<void> _llamarConductor(BuildContext context, String telefono) async {
    await PhoneLauncher.dial(
      telefono,
      context: context,
      emptyMessage: 'No hay teléfono válido del conductor',
    );
  }

  Future<void> _mostrarDialogoCancelacion(
    BuildContext context,
    ActiveServiceProvider provider,
  ) async {
    final seleccion = await CancelacionServicioDialog.mostrar(
      context,
      tipoUsuario: 'pasajero',
    );

    if (seleccion != null) {
      if (!context.mounted) return;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      final success = await provider.cancelarServicio(
        motivoCodigo: seleccion.motivoCodigo,
        motivo: seleccion.motivoTexto,
      );

      if (context.mounted) Navigator.pop(context);

      if (!context.mounted) return;

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Servicio cancelado exitosamente'),
            backgroundColor: AppColors.green,
          ),
        );
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(provider.error ?? 'Error al cancelar'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
