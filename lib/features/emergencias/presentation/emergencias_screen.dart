import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:intellitaxi/features/conductor/providers/conductor_home_provider.dart';
import 'package:intellitaxi/features/emergencias/providers/emergencia_provider.dart';
import 'package:intellitaxi/features/emergencias/utils/emergencia_quick_report.dart';

/// Emergencia en un toque: el front envía lat/lng; el backend geocodifica y avisa.
class EmergenciasScreen extends StatefulWidget {
  const EmergenciasScreen({super.key});

  @override
  State<EmergenciasScreen> createState() => _EmergenciasScreenState();
}

class _EmergenciasScreenState extends State<EmergenciasScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<EmergenciaProvider>().cargarEmergenciasActivas();
    });
  }

  Future<void> _enviarApoyo() async {
    final result = await EmergenciaQuickReport.enviar(context: context);
    if (!mounted || !result.ok) return;
    setState(() {});
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

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: ok ? Colors.green : Colors.red,
        behavior: SnackBarBehavior.floating,
        content: Text(
          ok
              ? 'Emergencia finalizada'
              : context.read<EmergenciaProvider>().lastError ??
                    'No se pudo finalizar',
        ),
      ),
    );
  }

  String? _ubicacionMostrada(EmergenciaProvider emergenciaProvider) {
    final e = emergenciaProvider.ultimaEmergencia;
    if (e == null) return null;
    if (e.direccionCompleta != null && e.direccionCompleta!.trim().isNotEmpty) {
      return e.direccionCompleta;
    }
    if (e.barrio != null && e.barrio!.trim().isNotEmpty) {
      return e.barrio;
    }
    return '${e.lat.toStringAsFixed(5)}, ${e.lng.toStringAsFixed(5)}';
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
    final ubicacion = _ubicacionMostrada(emergenciaProvider);
    final gpsListo = conductorProvider.currentPosition != null;

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
                      enEmergencia ? 'Apoyo en curso' : 'Un toque para pedir apoyo',
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
                          ? 'La central y la flota recibieron tus coordenadas.'
                          : 'Enviamos tu GPS al instante. La dirección la calcula el servidor.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white70, fontSize: 15),
                    ),
                    if (!enEmergencia) ...[
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            gpsListo ? Icons.gps_fixed : Icons.gps_not_fixed,
                            color: Colors.white70,
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            gpsListo
                                ? 'GPS listo'
                                : 'Se usará la última ubicación conocida',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
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
                    if (ubicacion != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        ubicacion,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                    if (enEmergencia &&
                        emergenciaProvider.ultimaEmergencia != null &&
                        emergenciaProvider.ultimaEmergencia!.id > 0) ...[
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: () async {
                          final url =
                              emergenciaProvider.ultimaEmergencia!.urlMaps;
                          final uri = Uri.parse(url);
                          if (await canLaunchUrl(uri)) {
                            await launchUrl(
                              uri,
                              mode: LaunchMode.externalApplication,
                            );
                          }
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white70),
                        ),
                        icon: const Icon(Icons.navigation),
                        label: const Text('Ver en mapa'),
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
