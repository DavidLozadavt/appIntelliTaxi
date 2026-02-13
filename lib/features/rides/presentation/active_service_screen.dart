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
import 'package:intellitaxi/features/auth/logic/auth_provider.dart';
import 'dart:async';

class ActiveServiceScreen extends StatelessWidget {
  final ServicioActivo servicio;
  final VoidCallback? onServiceCompleted;

  const ActiveServiceScreen({
    super.key,
    required this.servicio,
    this.onServiceCompleted,
  });

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

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ActiveServiceProvider(
        servicio: servicio,
        onServiceCompleted: onServiceCompleted,
      ),
      child: Consumer<ActiveServiceProvider>(
        builder: (context, provider, _) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          final isServiceActive = provider.isServiceActive;

          return PopScope(
            canPop: !isServiceActive,
            onPopInvoked: (didPop) {
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
                title: Text('Servicio #${servicio.id}'),
                automaticallyImplyLeading: !isServiceActive,
                actions: [
                  // Botón de chat - solo si el servicio está activo
                  if (isServiceActive)
                    Builder(
                      builder: (context) {
                        final authProvider = Provider.of<AuthProvider>(
                          context,
                          listen: false,
                        );
                        return ChatHelper.botonAppBarChat(
                          context: context,
                          servicioId: servicio.id,
                          miUserId: authProvider.userId ?? 0,
                        );
                      },
                    ),
                ],
              ),
              body: Stack(
                children: [
                  // Mapa
                  StandardMap(
                    initialPosition: LatLng(
                      servicio.origenLat,
                      servicio.origenLng,
                    ),
                    zoom: 14,
                    markers: provider.markers,
                    polylines: provider.polylines,
                    onMapCreated: (controller) {
                      provider.setMapController(controller);
                    },
                  ),

                  // Panel inferior con información
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Container(
                      decoration: BoxDecoration(
                        color: isDark ? Colors.grey.shade900 : Colors.white,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(24),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 10,
                            offset: const Offset(0, -4),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Handle
                          Container(
                            margin: const EdgeInsets.only(top: 12),
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),

                          const SizedBox(height: 16),

                          // Estado del servicio
                          _buildStateCard(provider),

                          if (servicio.conductor != null) ...[
                            const SizedBox(height: 16),
                            _buildConductorInfo(),
                          ],

                          const SizedBox(height: 16),
                          _buildTripInfo(),

                          // Botón de cancelar
                          if (isServiceActive &&
                              servicio.idEstado != 5 &&
                              servicio.idEstado != 6) ...[
                            const SizedBox(height: 16),
                            _buildCancelButton(context, provider),
                          ],

                          const SizedBox(height: 20),
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
    );
  }

  Widget _buildStateCard(ActiveServiceProvider provider) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: provider.getStateColor().withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: provider.getStateColor().withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(
            _getStateIcon(servicio.idEstado),
            color: provider.getStateColor(),
            size: 32,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  servicio.estado.estado,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: provider.getStateColor(),
                  ),
                ),
                Text(
                  provider.getStateMessage(),
                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConductorInfo() {
    final conductor = servicio.conductor!;
    final vehiculo = servicio.vehiculo;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: AppColors.accent,
                child: conductor.foto != null
                    ? ClipOval(
                        child: Image.network(
                          conductor.foto!,
                          width: 60,
                          height: 60,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(
                            Iconsax.user_copy,
                            color: Colors.white,
                            size: 30,
                          ),
                        ),
                      )
                    : const Icon(
                        Iconsax.user_copy,
                        color: Colors.white,
                        size: 30,
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      conductor.nombre,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (conductor.calificacion != null)
                      Row(
                        children: [
                          const Icon(Icons.star, color: Colors.amber, size: 16),
                          const SizedBox(width: 4),
                          Text(
                            conductor.calificacion!.toStringAsFixed(1),
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              if (conductor.telefono != null)
                IconButton(
                  onPressed: () {
                    // TODO: Llamar al conductor
                  },
                  icon: const Icon(Iconsax.call_copy, color: AppColors.accent),
                ),
            ],
          ),
          if (vehiculo != null) ...[
            const Divider(height: 24),
            Row(
              children: [
                const Icon(Iconsax.car_copy, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${vehiculo.marca ?? ''} ${vehiculo.modelo ?? ''} ${vehiculo.color ?? ''}'
                        .trim(),
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
                if (vehiculo.placa != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.primary),
                    ),
                    child: Text(
                      vehiculo.placa!,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTripInfo() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          // Origen
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 2),
                width: 12,
                height: 12,
                decoration: const BoxDecoration(
                  color: AppColors.green,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Origen',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    Text(
                      servicio.origenAddress,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          Container(
            margin: const EdgeInsets.only(left: 5),
            width: 2,
            height: 20,
            color: AppColors.primary.withOpacity(0.3),
          ),

          // Destino
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 2),
                width: 12,
                height: 12,
                decoration: const BoxDecoration(
                  color: AppColors.accent,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Destino',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    Text(
                      servicio.destinoAddress,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const Divider(height: 24),

          // Info adicional
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              if (servicio.distanciaTexto != null)
                _buildInfoChip(Iconsax.routing_copy, servicio.distanciaTexto!),
              if (servicio.duracionTexto != null)
                _buildInfoChip(Iconsax.clock_copy, servicio.duracionTexto!),
              _buildInfoChip(
                Iconsax.dollar_circle_copy,
                '\$${servicio.precioEstimado.toStringAsFixed(0)}',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: AppColors.accent),
        const SizedBox(width: 4),
        Text(
          text,
          style: const TextStyle(
            fontSize: 13,
            color: Colors.black87,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildCancelButton(
    BuildContext context,
    ActiveServiceProvider provider,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.red.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _mostrarDialogoCancelacion(context, provider),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.red.shade50, Colors.red.shade100],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.red.shade300, width: 1.5),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Iconsax.close_circle_copy,
                  color: Colors.red.shade700,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  'Cancelar servicio',
                  style: TextStyle(
                    color: Colors.red.shade700,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _mostrarDialogoCancelacion(
    BuildContext context,
    ActiveServiceProvider provider,
  ) async {
    final resultado = await CancelacionServicioDialog.mostrar(
      context,
      tipoUsuario: 'pasajero',
    );

    if (resultado != null && resultado.isNotEmpty) {
      if (!context.mounted) return;

      // Mostrar loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      // Llamar al provider para cancelar
      final success = await provider.cancelarServicio(resultado);

      // Cerrar loading
      if (context.mounted) Navigator.pop(context);

      if (!context.mounted) return;

      if (success) {
        // Mostrar mensaje de éxito
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Servicio cancelado exitosamente'),
            backgroundColor: AppColors.green,
          ),
        );

        // Cerrar pantalla
        Navigator.pop(context);
      } else {
        // Mostrar error
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
