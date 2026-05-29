import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intellitaxi/core/diagnostics/app_diagnostics.dart';
import 'package:intellitaxi/core/diagnostics/native_diagnostics_helper.dart';
import 'package:intellitaxi/core/theme/app_colors.dart';

/// Pantalla para soporte: ver y copiar eventos de arranque / lifecycle.
class AppDiagnosticsScreen extends StatefulWidget {
  const AppDiagnosticsScreen({super.key});

  @override
  State<AppDiagnosticsScreen> createState() => _AppDiagnosticsScreenState();
}

class _AppDiagnosticsScreenState extends State<AppDiagnosticsScreen> {
  String _report = 'Cargando…';
  bool _loading = true;
  bool _batteryOptimized = true;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    var batteryOk = true;
    try {
      final native = await NativeDiagnosticsHelper.fetchSnapshot();
      final raw = native['ignoringBatteryOptimizations']?.toLowerCase();
      batteryOk = raw == 'true';
    } catch (_) {}

    final text = await AppDiagnostics.buildReport();
    if (!mounted) return;
    setState(() {
      _report = text;
      _batteryOptimized = batteryOk;
      _loading = false;
    });
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: _report));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Diagnóstico copiado al portapapeles')),
    );
  }

  Future<void> _openBatterySettings() async {
    await NativeDiagnosticsHelper.openBatteryOptimizationSettings();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'En Oppo/Samsung elige «Sin restricciones» o «Permitir en segundo plano»',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Diagnóstico de la app'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _loading ? null : _refresh,
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar',
          ),
          IconButton(
            onPressed: _loading ? null : _copy,
            icon: const Icon(Icons.copy),
            tooltip: 'Copiar todo',
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Si la app se cierra sola, copia este texto y envíalo a soporte '
                  'justo después de que ocurra.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                if (!_batteryOptimized) ...[
                  const SizedBox(height: 12),
                  Material(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'La batería está restringida. En Oppo/ColorOS suele '
                            'cerrar apps de conductores.',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(height: 8),
                          FilledButton(
                            onPressed: _openBatterySettings,
                            child: const Text('Abrir ajustes de batería'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    child: SelectableText(
                      _report,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11,
                        height: 1.35,
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
