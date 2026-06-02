import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:intl/intl.dart';
import 'package:intellitaxi/core/theme/app_colors.dart';
import 'package:intellitaxi/features/auth/providers/auth_provider.dart';
import 'package:intellitaxi/features/pasajero/services/repeat_trip_service.dart';
import 'package:intellitaxi/features/rides/data/historial_servicio_model.dart';
import 'package:intellitaxi/features/rides/presentation/historial_calificaciones_screen.dart';
import 'package:intellitaxi/features/rides/services/historial_servicio_service.dart';
import 'package:provider/provider.dart';
import 'package:intellitaxi/shared/optimized_image_widgets.dart';

class HistorialServiciosPasajeroScreen extends StatefulWidget {
  const HistorialServiciosPasajeroScreen({super.key});

  @override
  State<HistorialServiciosPasajeroScreen> createState() =>
      _HistorialServiciosPasajeroScreenState();
}

class _HistorialServiciosPasajeroScreenState
    extends State<HistorialServiciosPasajeroScreen> {
  final HistorialServicioService _historialService = HistorialServicioService();
  final ScrollController _scrollController = ScrollController();

  List<HistorialServicio> _servicios = [];
  PaginacionInfo? _paginacion;
  bool _isLoading = true;
  bool _isLoadingMore = false;
  String? _error;
  int _currentPage = 1;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _cargarDatos();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    if (_isLoading || _isLoadingMore || _paginacion?.hasNextPage != true) {
      return;
    }

    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 220) {
      _cargarDatos(loadMore: true);
    }
  }

  Future<void> _cargarDatos({bool loadMore = false}) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final pasajeroId = authProvider.user?.id;

    if (pasajeroId == null) {
      setState(() {
        _error = 'No se pudo obtener el ID del pasajero';
        _isLoading = false;
      });
      return;
    }

    if (loadMore) {
      setState(() => _isLoadingMore = true);
    } else {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      final historial = await _historialService.obtenerHistorialPasajero(
        pasajeroId: pasajeroId,
        page: loadMore ? _currentPage + 1 : 1,
      );

      if (!mounted) return;

      setState(() {
        if (loadMore) {
          _servicios.addAll(historial.servicios);
          _currentPage++;
        } else {
          _servicios = historial.servicios;
          _currentPage = 1;
        }
        _paginacion = historial.paginacion;
        _isLoading = false;
        _isLoadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
        _isLoadingMore = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Mis Viajes',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Iconsax.star_1_copy),
            onPressed: () {
              final authProvider = Provider.of<AuthProvider>(
                context,
                listen: false,
              );
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => HistorialCalificacionesScreen(
                    idUsuario: authProvider.user!.id,
                    tipoCalificacion: 'PASAJERO',
                    nombreUsuario: authProvider.user!.nombreCompleto,
                  ),
                ),
              );
            },
            tooltip: 'Ver mis calificaciones',
          ),
        ],
      ),
      body: _buildHistorialTab(),
    );
  }

  Widget _buildHistorialTab() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return _buildError();
    }

    if (_servicios.isEmpty) {
      return _buildEmpty();
    }

    return RefreshIndicator(
      onRefresh: () => _cargarDatos(),
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        itemCount: _servicios.length + 2,
        itemBuilder: (context, index) {
          if (index == 0) {
            return _buildOverviewCard();
          }

          final servicioIndex = index - 1;
          if (servicioIndex < _servicios.length) {
            return _buildServicioCard(_servicios[servicioIndex]);
          }

          return _buildPaginationFooter();
        },
      ),
    );
  }

  Widget _buildOverviewCard() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.07)
        : Colors.grey.shade200;
    final mutedText = isDark ? Colors.grey.shade400 : Colors.grey.shade600;
    final cardColor = isDark ? AppColors.darkCard : Colors.white;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Iconsax.clock_copy,
              color: AppColors.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_paginacion?.total ?? _servicios.length} viajes registrados',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Desliza para revisar tu historial reciente.',
                  style: TextStyle(fontSize: 13, color: mutedText),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServicioCard(HistorialServicio servicio) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cardColor = isDark ? AppColors.darkCard : Colors.white;
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.07)
        : Colors.grey.shade200;
    final mutedText = isDark ? Colors.grey.shade400 : Colors.grey.shade600;
    final softSurface = isDark
        ? Colors.white.withValues(alpha: 0.03)
        : Colors.grey.shade50;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Iconsax.calendar_copy,
                          size: 16,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _formatearFecha(servicio.fechaServicio),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: mutedText,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                _buildEstadoBadge(servicio),
              ],
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: softSurface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderColor),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: const BoxDecoration(
                          color: AppColors.green,
                          shape: BoxShape.circle,
                        ),
                      ),
                      Container(
                        width: 2,
                        height: 52,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              AppColors.green,
                              AppColors.primary.withValues(alpha: 0.65),
                            ],
                          ),
                        ),
                      ),
                      Container(
                        width: 12,
                        height: 12,
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Origen',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: mutedText,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          servicio.origen.nombreODireccion,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            height: 1.3,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Destino',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: mutedText,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          servicio.destino.nombreODireccion,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            height: 1.3,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (servicio.distancia != null)
                  _buildInfoPill(
                    icon: Iconsax.ruler_copy,
                    text: servicio.distancia!,
                    textColor: mutedText,
                    backgroundColor: softSurface,
                  ),
                _buildInfoPill(
                  icon: Iconsax.clock_copy,
                  text: servicio.duracionTexto,
                  textColor: mutedText,
                  backgroundColor: softSurface,
                ),
                _buildInfoPill(
                  icon: Iconsax.wallet_3_copy,
                  text: servicio.precioFinalFormateado,
                  textColor: AppColors.primary,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.10),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Divider(height: 1, color: borderColor),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: borderColor, width: 1.5),
                  ),
                  child: SafeCircleAvatar(
                    radius: 26,
                    imageUrl: servicio.persona?.fotoPerfil,
                    backgroundColor: softSurface,
                    fallback: Icon(
                      Iconsax.user_copy,
                      color: mutedText,
                      size: 28,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Conductor',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: mutedText,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        servicio.persona?.nombre ?? 'Conductor',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (servicio.vehiculo != null) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Iconsax.car_copy,
                              size: 12,
                              color: mutedText,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                '${servicio.vehiculo!.marca} ${servicio.vehiculo!.modelo} • ${servicio.vehiculo!.placa}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: mutedText,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                if (servicio.calificacion != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3E6B3),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Iconsax.star_1_copy,
                          color: Color(0xFF7A5A00),
                          size: 15,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          servicio.calificacion!.puntuacion.toString(),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF7A5A00),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: softSurface,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Sin calificar',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: mutedText,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _repetirViaje(servicio),
                icon: const Icon(Iconsax.repeat_copy, size: 18),
                label: const Text(
                  'Repetir este viaje',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.2,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoPill({
    required IconData icon,
    required String text,
    required Color textColor,
    required Color backgroundColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: textColor),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEstadoBadge(HistorialServicio servicio) {
    final isCancelado = servicio.isCancelado;
    final backgroundColor = isCancelado
        ? Colors.red.withValues(alpha: 0.10)
        : AppColors.green.withValues(alpha: 0.10);
    final foregroundColor = isCancelado ? Colors.red.shade700 : AppColors.green;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        isCancelado ? 'Cancelado' : 'Finalizado',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: foregroundColor,
        ),
      ),
    );
  }

  Widget _buildPaginationFooter() {
    if (_isLoadingMore) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(0, 6, 0, 24),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_paginacion?.hasNextPage == true) {
      return const SizedBox(height: 24);
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 6, 0, 24),
      child: Center(
        child: Text(
          'No hay mas viajes para mostrar',
          style: TextStyle(
            fontSize: 12,
            color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
          ),
        ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Iconsax.info_circle_copy,
              size: 64,
              color: Colors.red.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _cargarDatos(),
              icon: const Icon(Iconsax.refresh_copy),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Iconsax.clock_copy, size: 80, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            'Aun no has realizado viajes',
            style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  void _repetirViaje(HistorialServicio servicio) {
    final origen = servicio.origen;
    final destino = servicio.destino;

    if (destino.lat == null || destino.lng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Este viaje no tiene destino valido para repetir'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final payload = <String, dynamic>{
      'origen': {
        'name': origen.nombreODireccion,
        'address': origen.direccion,
        'lat': origen.lat,
        'lng': origen.lng,
        'isCurrentLocation': false,
      },
      'destino': {
        'name': destino.nombreODireccion,
        'address': destino.direccion,
        'lat': destino.lat,
        'lng': destino.lng,
        'isCurrentLocation': false,
      },
    };

    RepeatTripService.instance.setPendingTrip(payload);
    Navigator.of(context).pop();
  }

  String _formatearFecha(DateTime fecha) {
    final ahora = DateTime.now();
    final diferencia = ahora.difference(fecha);

    if (diferencia.inDays == 0) {
      return 'Hoy ${DateFormat('h:mm a', 'es').format(fecha)}';
    } else if (diferencia.inDays == 1) {
      return 'Ayer ${DateFormat('h:mm a', 'es').format(fecha)}';
    } else if (diferencia.inDays < 7) {
      return DateFormat('EEEE h:mm a', 'es').format(fecha);
    } else {
      return DateFormat('dd MMM yyyy h:mm a', 'es').format(fecha);
    }
  }
}
