import 'package:flutter/material.dart';
import 'package:intellitaxi/features/rides/data/calificacion_model.dart';
import 'package:intellitaxi/features/rides/services/calificacion_service.dart';
import 'package:intellitaxi/features/rides/widgets/calificacion_widgets.dart';

/// Pantalla para ver el historial de calificaciones de un usuario
class HistorialCalificacionesScreen extends StatefulWidget {
  final int idUsuario;
  final String? tipoCalificacion; // 'CONDUCTOR' o 'PASAJERO'
  final String nombreUsuario;

  const HistorialCalificacionesScreen({
    super.key,
    required this.idUsuario,
    this.tipoCalificacion,
    required this.nombreUsuario,
  });

  @override
  State<HistorialCalificacionesScreen> createState() =>
      _HistorialCalificacionesScreenState();
}

class _HistorialCalificacionesScreenState
    extends State<HistorialCalificacionesScreen> {
  final CalificacionService _calificacionService = CalificacionService();

  List<CalificacionServicio> _calificaciones = [];
  EstadisticasCalificacion? _estadisticas;
  bool _isLoading = true;
  String? _error;
  int _currentPage = 1;
  int _totalPages = 1;

  @override
  void initState() {
    super.initState();
    _cargarCalificaciones();
  }

  Future<void> _cargarCalificaciones({int page = 1}) async {
    if (page == 1) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      final resultado = await _calificacionService.obtenerCalificacionesUsuario(
        idUsuario: widget.idUsuario,
        tipo: widget.tipoCalificacion,
        page: page,
      );

      if (mounted) {
        setState(() {
          _calificaciones =
              resultado['calificaciones'] as List<CalificacionServicio>;
          _estadisticas = resultado['estadisticas'] as EstadisticasCalificacion;
          _currentPage = resultado['current_page'] as int;
          _totalPages = ((resultado['total'] as int) / 20).ceil();
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
        title: Text('Calificaciones de ${widget.nombreUsuario}'),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _buildError()
          : _calificaciones.isEmpty
          ? _buildEmpty()
          : _buildContent(),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
            const SizedBox(height: 16),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _cargarCalificaciones(),
              icon: const Icon(Icons.refresh),
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
          Icon(Icons.star_border, size: 80, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            'Aún no hay calificaciones',
            style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return RefreshIndicator(
      onRefresh: () => _cargarCalificaciones(),
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 16),
        children: [
          // Resumen de estadísticas
          if (_estadisticas != null) _buildEstadisticas(),

          const SizedBox(height: 16),

          // Título de calificaciones
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Todas las calificaciones',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
              ),
            ),
          ),

          const SizedBox(height: 8),

          // Lista de calificaciones
          ..._calificaciones.map((cal) => CalificacionCard(calificacion: cal)),

          // Paginación
          if (_totalPages > 1) _buildPaginacion(),

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildEstadisticas() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.deepOrange.shade400, Colors.deepOrange.shade600],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.deepOrange.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Promedio grande
          Column(
            children: [
              Text(
                _estadisticas!.promedio.toStringAsFixed(1),
                style: const TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const Row(
                children: [
                  Icon(Icons.star, color: Colors.amber, size: 24),
                  Icon(Icons.star, color: Colors.amber, size: 24),
                  Icon(Icons.star, color: Colors.amber, size: 24),
                  Icon(Icons.star, color: Colors.amber, size: 24),
                  Icon(Icons.star, color: Colors.amber, size: 24),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${_estadisticas!.total} calificaciones',
                style: const TextStyle(fontSize: 14, color: Colors.white70),
              ),
            ],
          ),

          const SizedBox(width: 24),

          // Distribución
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildMiniBarraCalificacion(
                  5,
                  _estadisticas!.distribucion['5_estrellas'] ?? 0,
                ),
                _buildMiniBarraCalificacion(
                  4,
                  _estadisticas!.distribucion['4_estrellas'] ?? 0,
                ),
                _buildMiniBarraCalificacion(
                  3,
                  _estadisticas!.distribucion['3_estrellas'] ?? 0,
                ),
                _buildMiniBarraCalificacion(
                  2,
                  _estadisticas!.distribucion['2_estrellas'] ?? 0,
                ),
                _buildMiniBarraCalificacion(
                  1,
                  _estadisticas!.distribucion['1_estrella'] ?? 0,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniBarraCalificacion(int estrellas, int cantidad) {
    final porcentaje = _estadisticas!.total > 0
        ? (cantidad / _estadisticas!.total * 100).toInt()
        : 0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text(
            '$estrellas',
            style: const TextStyle(
              fontSize: 12,
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.star, color: Colors.amber, size: 12),
          const SizedBox(width: 6),
          Expanded(
            child: Container(
              height: 6,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.3),
                borderRadius: BorderRadius.circular(3),
              ),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: porcentaje / 100,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.amber,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '$cantidad',
            style: const TextStyle(fontSize: 11, color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Widget _buildPaginacion() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            onPressed: _currentPage > 1
                ? () => _cargarCalificaciones(page: _currentPage - 1)
                : null,
            icon: const Icon(Icons.chevron_left),
          ),
          Text(
            'Página $_currentPage de $_totalPages',
            style: const TextStyle(fontSize: 14),
          ),
          IconButton(
            onPressed: _currentPage < _totalPages
                ? () => _cargarCalificaciones(page: _currentPage + 1)
                : null,
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }
}
