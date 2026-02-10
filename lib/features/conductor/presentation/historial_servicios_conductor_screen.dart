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
  String _filtroSeleccionado = 'hoy'; // Filtro por defecto

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

      // Cargar estadísticas solo la primera vez o cuando cambie el filtro
      if (!loadMore) {
        _estadisticas = await _historialService.obtenerEstadisticasConductor(
          conductorId: conductorId,
          filtro: _filtroSeleccionado,
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

  Future<void> _cambiarFiltro(String nuevoFiltro) async {
    if (_filtroSeleccionado == nuevoFiltro) return;

    setState(() {
      _filtroSeleccionado = nuevoFiltro;
      _isLoading = true;
      _error = null;
    });

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final conductorId = authProvider.user?.id;

    if (conductorId == null) return;

    try {
      _estadisticas = await _historialService.obtenerEstadisticasConductor(
        conductorId: conductorId,
        filtro: _filtroSeleccionado,
      );

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
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
      child: Column(
        children: [
          // Filtros de periodo
          _buildFiltrosPeriodo(),

          // KPIs principales (estilo empresarial)
          _buildKPIsPrincipales(),

          // Gráficos y métricas detalladas
          _buildMetricasDetalladas(),

          // Resumen por periodo
          _buildResumenPeriodo(),
        ],
      ),
    );
  }

  // Filtros de periodo
  Widget _buildFiltrosPeriodo() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey.shade900 : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Periodo de análisis',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildChipFiltro('Hoy', 'hoy'),
              _buildChipFiltro('Esta semana', 'semana'),
              _buildChipFiltro('Este mes', 'mes'),
              _buildChipFiltro('Últimos 3 meses', 'ano'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChipFiltro(String label, String filtroValue) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isSelected = _filtroSeleccionado == filtroValue;

    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          _cambiarFiltro(filtroValue);
        }
      },
      backgroundColor: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
      selectedColor: AppColors.accent.withOpacity(0.2),
      checkmarkColor: AppColors.accent,
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        color: isSelected
            ? AppColors.accent
            : (isDark ? Colors.white70 : Colors.black87),
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: isSelected ? AppColors.accent : Colors.transparent,
          width: 1.5,
        ),
      ),
    );
  }

  // KPIs principales estilo empresarial
  Widget _buildKPIsPrincipales() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.accent, AppColors.accent.withOpacity(0.8)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.accent.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Iconsax.chart_1_copy, color: Colors.white, size: 24),
              const SizedBox(width: 8),
              const Text(
                'Rendimiento General',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildKPIItem(
                'Ingresos',
                _estadisticas!.ingresosFormateado,
                Iconsax.money_4_copy,
                '+12%',
              ),
              Container(
                width: 1,
                height: 60,
                color: Colors.white.withOpacity(0.3),
              ),
              _buildKPIItem(
                'Servicios',
                _estadisticas!.totalServicios.toString(),
                Iconsax.car_copy,
                '+8%',
              ),
              Container(
                width: 1,
                height: 60,
                color: Colors.white.withOpacity(0.3),
              ),
              _buildKPIItem(
                'Rating',
                _estadisticas!.promedioCalificacion?.toStringAsFixed(1) ??
                    'N/A',
                Iconsax.star_1_copy,
                '+0.2',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildKPIItem(
    String titulo,
    String valor,
    IconData icon,
    String? tendencia,
  ) {
    return Column(
      children: [
        Icon(icon, color: Colors.white.withOpacity(0.9), size: 28),
        const SizedBox(height: 8),
        Text(
          valor,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          titulo,
          style: TextStyle(
            color: Colors.white.withOpacity(0.9),
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        if (tendencia != null) ...[
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              tendencia,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ],
    );
  }

  // Métricas detalladas
  Widget _buildMetricasDetalladas() {
    return Container(
      margin: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Métricas Detalladas',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white
                  : Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.3,
            children: [
              _buildMetricaCard(
                icon: Iconsax.map_copy,
                titulo: 'Distancia Total',
                valor:
                    '${_estadisticas!.distanciaTotalKm?.toStringAsFixed(1) ?? '0'} km',
                cambio: '+15%',
                isPositivo: true,
                color: const Color(0xFF6366F1),
              ),
              _buildMetricaCard(
                icon: Iconsax.clock_copy,
                titulo: 'Tiempo Promedio',
                valor:
                    '${_estadisticas!.tiempoPromedioMinutos?.toStringAsFixed(0) ?? '0'} min',
                cambio: '-5%',
                isPositivo: true,
                color: const Color(0xFF8B5CF6),
              ),
              _buildMetricaCard(
                icon: Iconsax.routing_2_copy,
                titulo: 'Tarifa Promedio',
                valor:
                    _estadisticas!.totalServicios > 0 &&
                        _estadisticas!.totalIngresos != null
                    ? '\$${(_estadisticas!.totalIngresos! / _estadisticas!.totalServicios).toStringAsFixed(2)}'
                    : '\$0',
                cambio: '+3%',
                isPositivo: true,
                color: const Color(0xFF10B981),
              ),
              _buildMetricaCard(
                icon: Iconsax.activity_copy,
                titulo: 'Tasa Aceptación',
                valor: '95%',
                cambio: '+2%',
                isPositivo: true,
                color: const Color(0xFFF59E0B),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricaCard({
    required IconData icon,
    required String titulo,
    required String valor,
    required String cambio,
    required bool isPositivo,
    required Color color,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey.shade900 : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isPositivo
                      ? Colors.green.withOpacity(0.1)
                      : Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: [
                    Icon(
                      isPositivo ? Icons.arrow_upward : Icons.arrow_downward,
                      size: 10,
                      color: isPositivo ? Colors.green : Colors.red,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      cambio,
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: isPositivo ? Colors.green : Colors.red,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  valor,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: color,
                    letterSpacing: -0.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  titulo,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.grey.shade400 : Colors.black54,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Resumen por periodo
  Widget _buildResumenPeriodo() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey.shade900 : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Iconsax.document_text_copy,
                size: 22,
                color: isDark ? Colors.white : Colors.black87,
              ),
              const SizedBox(width: 8),
              Text(
                'Resumen del Periodo',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildResumenItem(
            'Total de servicios completados',
            _estadisticas!.totalServicios.toString(),
            Iconsax.tick_circle_copy,
            Colors.green,
          ),
          const Divider(height: 24),
          _buildResumenItem(
            'Calificaciones recibidas',
            _estadisticas!.totalCalificaciones?.toString() ?? '0',
            Iconsax.star_1_copy,
            Colors.amber,
          ),
          const Divider(height: 24),
          _buildResumenItem(
            'Distancia recorrida',
            '${_estadisticas!.distanciaTotalKm?.toStringAsFixed(1) ?? '0'} km',
            Iconsax.map_copy,
            Colors.blue,
          ),
          const Divider(height: 24),
          _buildResumenItem(
            'Ingresos generados',
            _estadisticas!.ingresosFormateado,
            Iconsax.money_4_copy,
            Colors.green,
          ),
        ],
      ),
    );
  }

  Widget _buildResumenItem(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.grey.shade400 : Colors.black54,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
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
