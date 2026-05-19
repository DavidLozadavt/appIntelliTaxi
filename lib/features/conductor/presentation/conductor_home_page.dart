import 'package:flutter/material.dart';
// import 'package:intellitaxi/features/conductor/widgets/conductor_status_widget.dart';

class ConductorHomePage extends StatefulWidget {
  final int idVehiculo;

  const ConductorHomePage({super.key, required this.idVehiculo});

  @override
  State<ConductorHomePage> createState() => _ConductorHomePageState();
}

class _ConductorHomePageState extends State<ConductorHomePage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Panel de Conductor'),
        centerTitle: true,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 20),

            // Widget de control de estado
            // ConductorStatusWidget(idVehiculo: widget.idVehiculo),

            const SizedBox(height: 20),

            // Información adicional
            _buildInfoCard(
              context,
              title: '📍 ¿Cómo funciona?',
              items: [
                'Al iniciar turno se registra tu ubicación inicial',
                'Tu ubicación se envía cada 5 segundos',
                'Los pasajeros verán tu ubicación en tiempo real',
                'Al finalizar turno se detiene el envío automático',
              ],
            ),

            const SizedBox(height: 10),

            _buildInfoCard(
              context,
              title: '⚡ Consejos',
              items: [
                'Mantén el GPS activado para mayor precisión',
                'Conecta tu teléfono al cargador del auto',
                'Verifica que tengas buena conexión a internet',
                'Desconéctate cuando termines tu jornada',
              ],
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(
    BuildContext context, {
    required String title,
    required List<String> items,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            ...items.map(
              (item) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('• ', style: TextStyle(fontSize: 16)),
                    Expanded(
                      child: Text(
                        item,
                        style: TextStyle(color: Colors.grey[700], height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
