import 'package:flutter/material.dart';
import 'package:intellitaxi/core/theme/app_colors.dart';
import 'package:provider/provider.dart';
import 'package:intellitaxi/features/auth/logic/auth_provider.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:intellitaxi/features/rides/data/historial_servicio_model.dart';
import 'package:intellitaxi/features/rides/services/historial_servicio_service.dart';
import 'package:intellitaxi/features/rides/presentation/historial_calificaciones_screen.dart';
import 'package:intl/intl.dart';

/// Pantalla de historial de servicios para el conductor
class HistorialServiciosConductorScreen extends StatefulWidget {
  const HistorialServiciosConductorScreen({super.key});

  @override
  State<HistorialServiciosConductorScreen> createState() =>
      _HistorialServiciosConductorScreenState();
}

class _HistorialServiciosConductorScreenState
    extends State<HistorialServiciosConductorScreen>
    with SingleTickerProviderStateMixin {
  final HistorialServicioService _historialService = HistorialServicioService();

  late TabController _tabController;
  List<HistorialServicio> _servicios = [];
  EstadisticasServicios? _estadisticas;
  PaginacionInfo? _paginacion;
  bool _isLoading = true;
  bool _isLoadingMore = false;
  String? _error;
  int _currentPage = 1;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _cargarDatos();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _cargarDatos({bool loadMore = false}) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final conductorId = authProvider.user?.id;

    if (conductorId == null) {
      setState(() {
        _error = 'No se pudo obtener el ID del conductor';
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
      // Cargar historial
      final historial = await _historialService.obtenerHistorialConductor(
        conductorId: conductorId,
        page: loadMore ? _currentPage + 1 : 1,
      );

      // Cargar estadísticas solo la primera vez
      if (!loadMore && _estadisticas == null) {
        _estadisticas = await _historialService.obtenerEstadisticasConductor(
          conductorId: conductorId,
        );
      }

      if (mounted) {
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
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
          _isLoadingMore = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Mis Servicios',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.accent,
          indicatorWeight: 3,
          labelColor: AppColors.accent,
          unselectedLabelColor: Colors.grey,
          tabs: const [
            Tab(icon: Icon(Iconsax.clock_copy), text: 'Historial'),
            Tab(icon: Icon(Iconsax.chart_copy), text: 'Estadísticas'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Iconsax.star_copy),
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
                    tipoCalificacion: 'CONDUCTOR',
                    nombreUsuario: authProvider.user!.nombreCompleto,
                  ),
                ),
              );
            },
            tooltip: 'Ver mis calificaciones',
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildHistorialTab(), _buildEstadisticasTab()],
      ),
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
        padding: const EdgeInsets.all(16),
        itemCount:
            _servicios.length + (_paginacion?.hasNextPage == true ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _servicios.length) {
            return _buildLoadMoreButton();
          }
          return _buildServicioCard(_servicios[index]);
        },
      ),
    );
  }

  Widget _buildServicioCard(HistorialServicio servicio) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200, width: 0.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Fecha y precio
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Iconsax.calendar_copy,
                        size: 16,
                        color: Colors.blue.shade700,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      _formatearFecha(servicio.fechaServicio),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Ruta con diseño mejorado
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                // color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200, width: 0.5),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    children: [
                      Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: Colors.green.shade400,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.green.shade200,
                              blurRadius: 4,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Icon(
                            Iconsax.record_circle_copy,
                            size: 6,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      Container(
                        width: 2,
                        height: 50,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.green.shade300,
                              Colors.red.shade300,
                            ],
                          ),
                        ),
                      ),
                      Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: Colors.red.shade400,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.red.shade200,
                              blurRadius: 4,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Icon(
                            Iconsax.location_copy,
                            size: 8,
                            color: Colors.white,
                          ),
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
                            color: Colors.grey.shade600,
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
                            color: Colors.grey.shade600,
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

            const SizedBox(height: 20),

            // Información adicional
            Row(
              children: [
                if (servicio.distancia != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.purple.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Iconsax.ruler_copy,
                          size: 14,
                          color: Colors.purple.shade700,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          servicio.distancia!,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.purple.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Iconsax.clock_copy,
                        size: 14,
                        color: Colors.orange.shade700,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        servicio.duracionTexto,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.orange.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),
            Divider(height: 1, color: Colors.grey.shade200),
            const SizedBox(height: 20),

            // Pasajero y calificación con foto
            Row(
              children: [
                // Foto de perfil
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.grey.shade300, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: CircleAvatar(
                    radius: 26,
                    backgroundColor: Colors.grey.shade100,
                    backgroundImage: servicio.persona?.fotoPerfil != null
                        ? NetworkImage(servicio.persona!.fotoPerfil!)
                        : null,
                    child: servicio.persona?.fotoPerfil == null
                        ? Icon(
                            Iconsax.user_copy,
                            color: Colors.grey.shade600,
                            size: 28,
                          )
                        : null,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pasajero',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey.shade600,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        servicio.persona?.nombre ?? 'Pasajero',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (servicio.persona?.telefono != null) ...[
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(
                              Iconsax.call_copy,
                              size: 12,
                              color: Colors.grey.shade500,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              servicio.persona!.telefono!,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
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
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.amber.shade300, Colors.amber.shade500],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.amber.shade200,
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Iconsax.star_1_copy,
                          color: Colors.white,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          servicio.calificacion!.puntuacion.toString(),
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Text(
                    'Sin calificar',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade500,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEstadisticasTab() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_estadisticas == null) {
      return const Center(child: Text('No hay estadísticas disponibles'));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.1,
        children: [
          _buildEstadisticaCard(
            icon: Iconsax.car_copy,
            titulo: 'Servicios',
            valor: _estadisticas!.totalServicios.toString(),
            color: Colors.blue,
          ),
          _buildEstadisticaCard(
            icon: Iconsax.money_copy,
            titulo: 'Ingresos',
            valor: _estadisticas!.ingresosFormateado,
            color: Colors.green,
          ),
          if (_estadisticas!.promedioCalificacion != null)
            _buildEstadisticaCard(
              icon: Iconsax.star_1_copy,
              titulo: 'Calificación',
              valor: _estadisticas!.promedioCalificacion!.toStringAsFixed(1),
              subtitulo: '${_estadisticas!.totalCalificaciones}',
              color: Colors.amber,
            ),
          if (_estadisticas!.distanciaTotalKm != null)
            _buildEstadisticaCard(
              icon: Iconsax.map_copy,
              titulo: 'Distancia',
              valor:
                  '${_estadisticas!.distanciaTotalKm!.toStringAsFixed(0)} km',
              color: Colors.purple,
            ),
          if (_estadisticas!.tiempoPromedioMinutos != null)
            _buildEstadisticaCard(
              icon: Iconsax.clock_copy,
              titulo: 'Tiempo',
              valor:
                  '${_estadisticas!.tiempoPromedioMinutos!.toStringAsFixed(0)} min',
              color: Colors.orange,
            ),
        ],
      ),
    );
  }

  Widget _buildEstadisticaCard({
    required IconData icon,
    required String titulo,
    required String valor,
    String? subtitulo,
    required Color color,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color.withOpacity(0.08), color.withOpacity(0.03)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2), width: 1),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [color.withOpacity(0.2), color.withOpacity(0.3)],
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.3),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(height: 8),
            Text(
              titulo,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                valor,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: color,
                  letterSpacing: -0.5,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            if (subtitulo != null) ...[
              const SizedBox(height: 2),
              Text(
                subtitulo,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade500,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLoadMoreButton() {
    if (_isLoadingMore) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: OutlinedButton(
        onPressed: () => _cargarDatos(loadMore: true),
        child: const Text('Cargar más servicios'),
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
            'Aún no tienes servicios completados',
            style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  String _formatearFecha(DateTime fecha) {
    final ahora = DateTime.now();
    final diferencia = ahora.difference(fecha);

    if (diferencia.inDays == 0) {
      return 'Hoy ${DateFormat('HH:mm').format(fecha)}';
    } else if (diferencia.inDays == 1) {
      return 'Ayer ${DateFormat('HH:mm').format(fecha)}';
    } else if (diferencia.inDays < 7) {
      return DateFormat('EEEE HH:mm', 'es').format(fecha);
    } else {
      return DateFormat('dd MMM yyyy HH:mm', 'es').format(fecha);
    }
  }
}
