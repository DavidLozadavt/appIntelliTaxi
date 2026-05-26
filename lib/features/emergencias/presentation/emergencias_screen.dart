import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';

import 'package:intellitaxi/features/auth/providers/auth_provider.dart';
import 'package:intellitaxi/features/conductor/providers/conductor_home_provider.dart';
import '../providers/emergencia_provider.dart';

/// Emergencia en un solo paso: ubicación a central y flota.
class EmergenciasScreen extends StatefulWidget {
  const EmergenciasScreen({super.key});

  @override
  State<EmergenciasScreen> createState() => _EmergenciasScreenState();
}

class _EmergenciasScreenState extends State<EmergenciasScreen> {
  String? _ubicacionLegible;

  Future<void> _enviarApoyo() async {
    final emergenciaProvider = context.read<EmergenciaProvider>();
    if (emergenciaProvider.isLoading) return;
    if (emergenciaProvider.estaEnEmergencia) {
      _showSnackBar('Ya tienes una emergencia activa', Colors.orange);
      return;
    }

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.sos, color: Colors.red, size: 40),
        title: const Text('¿Necesitas apoyo?'),
        content: const Text(
          'Se enviará tu ubicación actual a la central y a los conductores cercanos.',
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sí, enviar'),
          ),
        ],
      ),
    );

    if (confirmar != true || !mounted) return;

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
      _showSnackBar('Activa un turno para pedir apoyo', Colors.red);
      return;
    }

    final position = await _obtenerUbicacion(conductorProvider);
    if (!mounted) return;
    if (position == null) {
      _showSnackBar('No se pudo obtener tu ubicación', Colors.red);
      return;
    }

    final ok = await emergenciaProvider.enviarApoyoRapido(
      idConductor: conductorId,
      idVehiculo: vehiculo?.id ?? turno.idVehiculo,
      idTurno: turno.id,
      lat: position.latitude,
      lng: position.longitude,
      placa: vehiculo?.placa,
    );

    if (!mounted) return;

    if (ok) {
      setState(() {
        _ubicacionLegible =
            '${position.latitude.toStringAsFixed(5)}, ${position.longitude.toStringAsFixed(5)}';
      });
    }

    _showSnackBar(
      ok
          ? 'Apoyo enviado. Tu ubicación fue compartida.'
          : emergenciaProvider.lastError ?? 'Error al enviar',
      ok ? Colors.green : Colors.red,
    );
  }

  Future<void> _confirmarFinalizarEmergencia() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Finalizar emergencia'),
          content: const Text('¿La situación ya fue atendida?'),
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
                'No se pudo finalizar',
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
    final enEmergencia = emergenciaProvider.estaEnEmergencia;

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Pedir apoyo',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: LinearGradient(
                    colors: isDark
                        ? [Colors.red.shade900, Colors.red.shade700]
                        : [Colors.red.shade700, Colors.red.shade500],
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      enEmergencia ? Icons.emergency_share : Icons.sos,
                      color: Colors.white,
                      size: 56,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      enEmergencia
                          ? 'Apoyo en curso'
                          : 'Un toque para pedir apoyo',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      enEmergencia
                          ? 'La central y otros conductores recibieron tu ubicación.'
                          : 'Sin categorías: solo avisamos dónde estás y que necesitas ayuda.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white70, fontSize: 15),
                    ),
                    if (turno != null) ...[
                      const SizedBox(height: 14),
                      Text(
                        'Turno #${turno.id} · ${vehiculo?.placa ?? 'Vehículo ${turno.idVehiculo}'}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                    if (_ubicacionLegible != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        _ubicacionLegible!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const Spacer(),
              SizedBox(
                height: 64,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: enEmergencia ? Colors.green : Colors.red,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 4,
                  ),
                  onPressed: emergenciaProvider.isLoading
                      ? null
                      : enEmergencia
                      ? _confirmarFinalizarEmergencia
                      : _enviarApoyo,
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
                          enEmergencia ? Icons.check_circle : Icons.sos,
                          size: 28,
                        ),
                  label: Text(
                    enEmergencia ? 'FINALIZAR EMERGENCIA' : 'NECESITO APOYO',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 17,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
