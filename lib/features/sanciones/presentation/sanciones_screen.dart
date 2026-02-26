import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:intellitaxi/core/theme/app_colors.dart';
import 'package:intellitaxi/features/sanciones/data/sancion_model.dart';
import 'package:intellitaxi/features/sanciones/services/sancion_service.dart';
import 'package:intellitaxi/shared/empty_state_widget.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class SancionesScreen extends StatefulWidget {
  const SancionesScreen({super.key});

  @override
  State<SancionesScreen> createState() => _SancionesScreenState();
}

class _SancionesScreenState extends State<SancionesScreen> {
  final SancionService _sancionService = SancionService();
  List<Sancion> _sanciones = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargarSanciones();
  }

  Future<void> _cargarSanciones() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final sanciones = await _sancionService.getMisSanciones();
      if (mounted) {
        setState(() {
          _sanciones = sanciones;
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

  // --- Cálculos de riesgo ---

  List<Sancion> get _sancionesActivas =>
      _sanciones.where((s) => s.estaActiva).toList();

  double get _porcentajeRiesgo {
    final activas = _sancionesActivas;
    if (activas.isEmpty) return 0.0;

    double puntos = 0;
    for (final s in activas) {
      switch (s.gravedad.toUpperCase()) {
        case 'GRAVE':
          puntos += 4;
          break;
        case 'ALTO':
          puntos += 2;
          break;
        case 'BAJO':
        default:
          puntos += 1;
          break;
      }
    }
    return (puntos / 10).clamp(0.0, 1.0);
  }

  String get _nivelRiesgo {
    final p = _porcentajeRiesgo;
    if (p == 0) return 'Sin sanciones activas';
    if (p <= 0.2) return 'Precaución';
    if (p <= 0.5) return 'Advertencia';
    return 'Peligro de bloqueo';
  }

  String get _descripcionRiesgo {
    final p = _porcentajeRiesgo;
    final activas = _sancionesActivas.length;
    if (p == 0) return 'No tienes sanciones activas. ¡Sigue así!';
    if (p <= 0.2) {
      return 'Tienes $activas sanción(es) activa(s). Mantén un buen comportamiento.';
    }
    if (p <= 0.5) {
      return 'Tienes $activas sanción(es) activa(s). Mejora tu conducta para evitar bloqueos.';
    }
    return 'Tienes $activas sanción(es) activa(s). Estás cerca de ser bloqueado.';
  }

  Color get _colorRiesgo {
    final p = _porcentajeRiesgo;
    if (p == 0) return AppColors.green;
    if (p <= 0.2) return Colors.amber;
    if (p <= 0.5) return Colors.orange;
    return Colors.red;
  }

  IconData get _iconoRiesgo {
    final p = _porcentajeRiesgo;
    if (p == 0) return Iconsax.shield_tick_copy;
    if (p <= 0.2) return Iconsax.info_circle_copy;
    if (p <= 0.5) return Iconsax.warning_2_copy;
    return Iconsax.danger_copy;
  }

  // --- UI ---

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Mis Sanciones',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Iconsax.refresh_copy),
            onPressed: _cargarSanciones,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _buildError(isDark)
          : _sanciones.isEmpty
          ? EmptyStateWidget(
              icon: Iconsax.shield_tick_copy,
              title: 'Sin sanciones',
              subtitle: 'No tienes ninguna sanción registrada. ¡Excelente!',
            )
          : RefreshIndicator(
              onRefresh: _cargarSanciones,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildBarraAdvertencia(isDark),
                  const SizedBox(height: 20),
                  // Título de sección
                  Row(
                    children: [
                      Icon(
                        Iconsax.document_text_copy,
                        size: 18,
                        color: isDark
                            ? Colors.grey.shade400
                            : Colors.grey.shade700,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Historial de sanciones (${_sanciones.length})',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? Colors.grey.shade300
                              : Colors.grey.shade800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Lista de sanciones
                  ...List.generate(
                    _sanciones.length,
                    (index) => _buildSancionCard(_sanciones[index], isDark),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildError(bool isDark) {
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
              style: TextStyle(
                fontSize: 16,
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _cargarSanciones,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBarraAdvertencia(bool isDark) {
    final color = _colorRiesgo;
    final porcentaje = _porcentajeRiesgo;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: color.withValues(alpha: 0.3), width: 1.5),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            colors: [
              color.withValues(alpha: 0.05),
              color.withValues(alpha: 0.12),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Encabezado con icono y nivel
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(_iconoRiesgo, color: color, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _nivelRiesgo,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${_sancionesActivas.length} de ${_sanciones.length} sanción(es) activa(s)',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? Colors.grey.shade400
                              : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Barra de progreso
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: porcentaje,
                minHeight: 10,
                backgroundColor: isDark
                    ? Colors.grey.shade800
                    : Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
            const SizedBox(height: 8),
            // Escala de la barra
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Bajo',
                  style: TextStyle(
                    fontSize: 10,
                    color: isDark ? Colors.grey.shade500 : Colors.grey.shade500,
                  ),
                ),
                Text(
                  'Bloqueo',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.grey.shade500 : Colors.grey.shade500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Descripción
            Text(
              _descripcionRiesgo,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSancionCard(Sancion sancion, bool isDark) {
    final gravedadColor = _getGravedadColor(sancion.gravedad);
    final gravedadIcon = _getGravedadIcon(sancion.gravedad);
    final estaActiva = sancion.estaActiva;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: estaActiva
              ? gravedadColor.withValues(alpha: 0.3)
              : Colors.grey.shade300,
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Gravedad + Estado
            Row(
              children: [
                // Icono de gravedad
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: gravedadColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(gravedadIcon, color: gravedadColor, size: 22),
                ),
                const SizedBox(width: 12),
                // Chip de gravedad
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: gravedadColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: gravedadColor.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    sancion.gravedad.toUpperCase(),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: gravedadColor,
                    ),
                  ),
                ),
                const Spacer(),
                // Badge activa/finalizada
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: estaActiva
                        ? Colors.red.withValues(alpha: 0.1)
                        : AppColors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        estaActiva ? Icons.circle : Icons.check_circle_outline,
                        size: 8,
                        color: estaActiva ? Colors.red : AppColors.green,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        estaActiva ? 'Activa' : 'Finalizada',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: estaActiva ? Colors.red : AppColors.green,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Observaciones
            if (sancion.observaciones != null &&
                sancion.observaciones!.isNotEmpty) ...[
              Text(
                sancion.observaciones!,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.grey.shade300 : Colors.grey.shade800,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 14),
            ],

            const Divider(height: 1),
            const SizedBox(height: 12),

            // Fechas
            Row(
              children: [
                Expanded(
                  child: _buildInfoRow(
                    icon: Iconsax.calendar_copy,
                    label: 'Desde',
                    value: _formatFecha(sancion.fecha),
                    isDark: isDark,
                  ),
                ),
                Expanded(
                  child: _buildInfoRow(
                    icon: Iconsax.calendar_tick_copy,
                    label: 'Hasta',
                    value: sancion.fechaFin != null
                        ? _formatFecha(sancion.fechaFin)
                        : 'Indefinida',
                    isDark: isDark,
                    valueColor: sancion.fechaFin == null ? Colors.red : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Registrado por
            if (sancion.registradoPor != null) ...[
              Row(
                children: [
                  Icon(
                    Iconsax.user_copy,
                    size: 14,
                    color: isDark ? Colors.grey.shade500 : Colors.grey.shade500,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Registrado por: ',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark
                          ? Colors.grey.shade500
                          : Colors.grey.shade500,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      sancion.registradoPor!.nombreCompleto,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? Colors.grey.shade400
                            : Colors.grey.shade700,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],

            // Documento adjunto
            if (sancion.urlDoc != null && sancion.urlDoc!.isNotEmpty) ...[
              const SizedBox(height: 10),
              InkWell(
                onTap: () => _abrirDocumento(sancion.urlDoc!),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppColors.accent.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Iconsax.document_download_copy,
                        size: 16,
                        color: AppColors.accent,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Ver documento adjunto',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.accent,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    required bool isDark,
    Color? valueColor,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          size: 14,
          color: isDark ? Colors.grey.shade500 : Colors.grey.shade500,
        ),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: isDark ? Colors.grey.shade500 : Colors.grey.shade500,
              ),
            ),
            Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color:
                    valueColor ??
                    (isDark ? Colors.grey.shade300 : Colors.grey.shade800),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // --- Helpers ---

  Color _getGravedadColor(String gravedad) {
    switch (gravedad.toUpperCase()) {
      case 'GRAVE':
        return Colors.red;
      case 'ALTO':
        return Colors.orange;
      case 'BAJO':
      default:
        return Colors.blue;
    }
  }

  IconData _getGravedadIcon(String gravedad) {
    switch (gravedad.toUpperCase()) {
      case 'GRAVE':
        return Iconsax.danger_copy;
      case 'ALTO':
        return Iconsax.warning_2_copy;
      case 'BAJO':
      default:
        return Iconsax.info_circle_copy;
    }
  }

  String _formatFecha(String? fecha) {
    if (fecha == null) return 'N/A';
    try {
      final date = DateTime.parse(fecha);
      return DateFormat('dd MMM yyyy', 'es').format(date);
    } catch (_) {
      return fecha;
    }
  }

  Future<void> _abrirDocumento(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo abrir el documento'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
