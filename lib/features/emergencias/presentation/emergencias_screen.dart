import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';

import 'package:intellitaxi/features/auth/providers/auth_provider.dart';
import 'package:intellitaxi/features/conductor/providers/conductor_home_provider.dart';
import '../providers/emergencia_provider.dart';

class EmergenciasScreen extends StatefulWidget {
  const EmergenciasScreen({super.key});

  @override
  State<EmergenciasScreen> createState() => _EmergenciasScreenState();
}

class _EmergenciasScreenState extends State<EmergenciasScreen> {
  static const List<Map<String, dynamic>> _tiposEmergencia = [
    {
      'titulo': 'Robo',
      'icon': Icons.gpp_bad,
      'color': Colors.red,
      'tipo': 'ROBO',
      'descripcion': 'Posible robo o situación de riesgo de seguridad',
    },
    {
      'titulo': 'Accidente',
      'icon': Icons.car_crash,
      'color': Colors.orange,
      'tipo': 'ACCIDENTE',
      'descripcion': 'Accidente reportado desde la app del conductor',
    },
    {
      'titulo': 'Emergencia médica',
      'icon': Icons.medical_services,
      'color': Colors.blue,
      'tipo': 'EMERGENCIAMEDICA',
      'descripcion': 'Emergencia médica durante el turno',
    },
    {
      'titulo': 'Cliente agresivo',
      'icon': Icons.warning_amber_rounded,
      'color': Colors.deepOrange,
      'tipo': 'CLIENTEAGRESIVO',
      'descripcion': 'Cliente agresivo o comportamiento peligroso',
    },
    {
      'titulo': 'Falla mecánica',
      'icon': Icons.build_circle,
      'color': Colors.amber,
      'tipo': 'FALLAMECANICA',
      'descripcion': 'Falla mecánica del vehículo durante el turno',
    },
  ];

  Future<void> _enviarEmergencia(Map<String, dynamic> item) async {
    final emergenciaProvider = context.read<EmergenciaProvider>();
    if (emergenciaProvider.isLoading) return;
    if (emergenciaProvider.estaEnEmergencia) {
      _showSnackBar('Ya tienes una emergencia activa', Colors.orange);
      return;
    }

    final authProvider = context.read<AuthProvider>();
    final conductorProvider = context.read<ConductorHomeProvider>();
    final conductorId = authProvider.user?.id;
    final turno = conductorProvider.turnoActivo;
    final vehiculo = conductorProvider.vehiculoSeleccionado;

    if (conductorId == null) {
      _showSnackBar('No se pudo identificar al conductor', Colors.red);
      return;
    }

    if (turno == null) {
      _showSnackBar(
        'Debes tener un turno activo para reportar emergencia',
        Colors.red,
      );
      return;
    }

    final position = await _obtenerUbicacion(conductorProvider);
    if (!mounted) return;

    if (position == null) {
      _showSnackBar('No se pudo obtener tu ubicación actual', Colors.red);
      return;
    }

    final ok = await emergenciaProvider.enviarEmergencia(
      idConductor: conductorId,
      idVehiculo: vehiculo?.id ?? turno.idVehiculo,
      idTurno: turno.id,
      lat: position.latitude,
      lng: position.longitude,
      tipo: item['tipo'] as String,
      descripcion: item['descripcion'] as String,
      silenciosa: true,
    );

    if (!mounted) return;

    _showSnackBar(
      ok ? 'Emergencia enviada a la central' : 'Error al enviar emergencia',
      ok ? Colors.green : Colors.red,
    );
  }

  Future<void> _confirmarFinalizarEmergencia() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Finalizar emergencia'),
          content: const Text(
            '¿Confirmas que la situación de emergencia ya fue atendida?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Finalizar'),
            ),
          ],
        );
      },
    );

    if (confirmar != true || !mounted) return;

    final ok = await context
        .read<EmergenciaProvider>()
        .finalizarEmergenciaActiva();
    if (!mounted) return;

    _showSnackBar(
      ok
          ? 'Emergencia finalizada'
          : context.read<EmergenciaProvider>().lastError ??
                'No se pudo finalizar la emergencia',
      ok ? Colors.green : Colors.red,
    );
  }

  Future<Position?> _obtenerUbicacion(
    ConductorHomeProvider conductorProvider,
  ) async {
    final cached = conductorProvider.currentPosition;
    if (cached != null) return cached;

    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 6),
        ),
      );
    } catch (_) {
      return null;
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        content: Text(message),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final emergenciaProvider = context.watch<EmergenciaProvider>();
    final conductorProvider = context.watch<ConductorHomeProvider>();
    final turno = conductorProvider.turnoActivo;
    final vehiculo = conductorProvider.vehiculoSeleccionado;
    final emergenciaRapida = _tiposEmergencia.first;

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Emergencias',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? [Colors.red.shade900, Colors.red.shade600]
                    : [Colors.red, Colors.redAccent],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.red.withValues(alpha: 0.25),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              children: [
                Icon(
                  emergenciaProvider.estaEnEmergencia
                      ? Icons.emergency_share
                      : Icons.sos,
                  color: Colors.white,
                  size: 64,
                ),
                const SizedBox(height: 12),
                Text(
                  emergenciaProvider.estaEnEmergencia
                      ? 'Emergencia activa'
                      : 'Reporte rápido',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  emergenciaProvider.estaEnEmergencia
                      ? 'La central ya recibió tu alerta.'
                      : 'Se enviarán tu turno, vehículo y ubicación actual.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontSize: 15),
                ),
                const SizedBox(height: 14),
                _InfoLine(
                  text: turno == null
                      ? 'Sin turno activo'
                      : 'Turno #${turno.id} • Vehículo ${vehiculo?.placa ?? turno.idVehiculo}',
                ),
              ],
            ),
          ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _tiposEmergencia.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
                childAspectRatio: 1,
              ),
              itemBuilder: (context, index) {
                final item = _tiposEmergencia[index];
                final color = item['color'] as Color;

                return InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap:
                      emergenciaProvider.isLoading ||
                          emergenciaProvider.estaEnEmergencia
                      ? null
                      : () => _enviarEmergencia(item),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    decoration: BoxDecoration(
                      color: theme.cardColor,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: color.withValues(alpha: 0.16)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(item['icon'] as IconData, color: color),
                        ),
                        const SizedBox(height: 14),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: Text(
                            item['titulo'] as String,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
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
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              height: 62,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: emergenciaProvider.estaEnEmergencia
                      ? Colors.green
                      : Colors.red,
                  foregroundColor: Colors.white,
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                onPressed: emergenciaProvider.isLoading
                    ? null
                    : emergenciaProvider.estaEnEmergencia
                    ? _confirmarFinalizarEmergencia
                    : () => _enviarEmergencia(emergenciaRapida),
                icon: emergenciaProvider.isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                    : Icon(
                        emergenciaProvider.estaEnEmergencia
                            ? Icons.check_circle
                            : Icons.sos,
                        size: 28,
                      ),
                label: Text(
                  emergenciaProvider.estaEnEmergencia
                      ? 'FINALIZAR EMERGENCIA'
                      : 'EMERGENCIA RÁPIDA',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  final String text;

  const _InfoLine({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
