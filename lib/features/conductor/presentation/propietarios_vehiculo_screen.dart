import 'package:flutter/material.dart';
import 'package:intellitaxi/core/theme/app_colors.dart';
import 'package:intellitaxi/features/conductor/data/propietario_vehiculo_model.dart';
import 'package:intellitaxi/features/conductor/data/vehiculo_conductor_model.dart';
import 'package:intellitaxi/features/conductor/services/conductor_service.dart';

class PropietariosVehiculoScreen extends StatefulWidget {
  final VehiculoConductor vehiculo;

  const PropietariosVehiculoScreen({super.key, required this.vehiculo});

  @override
  State<PropietariosVehiculoScreen> createState() =>
      _PropietariosVehiculoScreenState();
}

class _PropietariosVehiculoScreenState
    extends State<PropietariosVehiculoScreen> {
  final ConductorService _service = ConductorService();
  bool _isLoading = true;
  String? _error;
  List<AfiliacionPropietariosVehiculo> _afiliaciones = [];

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final idAfiliacion = widget.vehiculo.asignacionPrincipal?.idAfiliacion;
    if (idAfiliacion == null || idAfiliacion == 0) {
      setState(() {
        _isLoading = false;
        _error = 'Este vehículo no tiene afiliación registrada';
      });
      return;
    }

    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });
      final afiliaciones = await _service.getPropietariosByAfiliacion(
        idAfiliacion,
      );
      if (!mounted) return;
      setState(() {
        _afiliaciones = afiliaciones;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final tituloVehiculo = [
      widget.vehiculo.marca?.marca ?? '',
      widget.vehiculo.modelo?.modelo ?? '',
      widget.vehiculo.placa,
    ].where((e) => e.trim().isNotEmpty).join(' ');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Propietarios'),
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            onPressed: _cargar,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(_error!, textAlign: TextAlign.center),
              ),
            )
          : RefreshIndicator(
              onRefresh: _cargar,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildVehiculoHeader(tituloVehiculo),
                  const SizedBox(height: 12),
                  if (_afiliaciones.isEmpty)
                    const _EmptyOwners()
                  else
                    ..._afiliaciones.expand(
                      (afiliacion) => [
                        _buildAfiliacionSummary(afiliacion),
                        const SizedBox(height: 12),
                        ...afiliacion.propietarios.map(_buildPropietarioCard),
                      ],
                    ),
                ],
              ),
            ),
    );
  }

  Widget _buildVehiculoHeader(String tituloVehiculo) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          const Icon(Icons.directions_car, color: AppColors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tituloVehiculo,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                Text(
                  'Vinculación: ${widget.vehiculo.estadoVinculacion}',
                  style: TextStyle(
                    color: widget.vehiculo.puedeOperarPorVinculacion
                        ? AppColors.green
                        : Colors.orange,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAfiliacionSummary(AfiliacionPropietariosVehiculo afiliacion) {
    final activa = afiliacion.estado.toUpperCase() == 'ACTIVO';
    final color = activa ? AppColors.green : Colors.orange;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Row(
        children: [
          Icon(
            activa ? Icons.verified_outlined : Icons.warning_amber,
            color: color,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Afiliación ${afiliacion.numero} • ${afiliacion.estado}',
              style: TextStyle(color: color, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPropietarioCard(PropietarioVehiculo propietario) {
    final pivot = propietario.pivot;
    final ubicacion = [
      propietario.ciudadNacimiento,
      propietario.departamentoNacimiento,
    ].where((e) => e != null && e.trim().isNotEmpty).join(', ');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.withValues(alpha: 0.22)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                  backgroundImage:
                      propietario.rutaFotoUrl != null &&
                          propietario.rutaFotoUrl!.isNotEmpty
                      ? NetworkImage(propietario.rutaFotoUrl!)
                      : null,
                  child:
                      propietario.rutaFotoUrl == null ||
                          propietario.rutaFotoUrl!.isEmpty
                      ? Text(
                          propietario.nombre1.isNotEmpty
                              ? propietario.nombre1[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w800,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        propietario.nombreCompleto,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        '${propietario.tipoIdentificacion ?? 'ID'} ${propietario.identificacion}',
                        style: TextStyle(color: Colors.grey.shade700),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (pivot?.porcentaje.isNotEmpty == true)
                  _InfoChip(
                    icon: Icons.percent,
                    label: '${pivot!.porcentaje}% propiedad',
                  ),
                if (pivot?.administrador.isNotEmpty == true)
                  _InfoChip(
                    icon: Icons.manage_accounts_outlined,
                    label: 'Administrador: ${pivot!.administrador}',
                  ),
                if (pivot?.estado.isNotEmpty == true)
                  _InfoChip(
                    icon: Icons.verified_outlined,
                    label: pivot!.estado,
                  ),
                if ((propietario.tipoTitular ?? '').isNotEmpty)
                  _InfoChip(
                    icon: Icons.person_outline,
                    label: propietario.tipoTitular!,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if ((propietario.celular ?? '').isNotEmpty)
              _InfoLine(icon: Icons.phone_outlined, text: propietario.celular!),
            if ((propietario.email ?? '').isNotEmpty)
              _InfoLine(icon: Icons.email_outlined, text: propietario.email!),
            if ((propietario.direccion ?? '').isNotEmpty)
              _InfoLine(
                icon: Icons.home_outlined,
                text: propietario.direccion!,
              ),
            if (ubicacion.isNotEmpty)
              _InfoLine(icon: Icons.location_city_outlined, text: ubicacion),
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.primary),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoLine({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          Icon(icon, size: 17, color: Colors.grey.shade600),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

class _EmptyOwners extends StatelessWidget {
  const _EmptyOwners();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(32),
      child: Center(child: Text('No hay propietarios registrados')),
    );
  }
}
