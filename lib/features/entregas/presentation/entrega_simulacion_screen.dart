import 'dart:async';
import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:intellitaxi/core/theme/app_colors.dart';

/// Pantalla de simulacion de una entrega para demo/presentacion al cliente.
class EntregaSimulacionScreen extends StatefulWidget {
  final String tipoServicio; // 'ciudad' o 'intercity'

  const EntregaSimulacionScreen({super.key, required this.tipoServicio});

  @override
  State<EntregaSimulacionScreen> createState() =>
      _EntregaSimulacionScreenState();
}

class _EntregaSimulacionScreenState extends State<EntregaSimulacionScreen>
    with TickerProviderStateMixin {
  int _currentStep = 0;
  bool _isProcessing = false;
  Timer? _progressTimer;
  double _progressValue = 0.0;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  final List<_SimulacionStep> _steps = [
    _SimulacionStep(
      title: 'Solicitud creada',
      subtitle: 'El cliente ha solicitado una entrega',
      icon: Iconsax.document_text_copy,
      detail: 'Paquete: Caja mediana (5kg)',
    ),
    _SimulacionStep(
      title: 'Conductor asignado',
      subtitle: 'Se ha asignado un conductor cercano',
      icon: Iconsax.user_tick_copy,
      detail: 'Carlos M. - Toyota Hilux (Blanca)',
    ),
    _SimulacionStep(
      title: 'En camino a recoger',
      subtitle: 'El conductor se dirige al punto de recogida',
      icon: Iconsax.car_copy,
      detail: 'Tiempo estimado: 8 min',
    ),
    _SimulacionStep(
      title: 'Paquete recogido',
      subtitle: 'El conductor ha recogido el paquete',
      icon: Iconsax.box_tick_copy,
      detail: 'Verificacion: Paquete en buen estado',
    ),
    _SimulacionStep(
      title: 'En transito',
      subtitle: 'El paquete va en camino al destino',
      icon: Iconsax.truck_fast_copy,
      detail: 'Distancia restante: 4.2 km',
    ),
    _SimulacionStep(
      title: 'Entregado',
      subtitle: 'El paquete ha sido entregado exitosamente',
      icon: Iconsax.tick_circle_copy,
      detail: 'Recibido por: Maria Lopez',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _progressTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  void _advanceStep() {
    if (_isProcessing || _currentStep >= _steps.length - 1) return;
    setState(() => _isProcessing = true);
    _progressValue = 0.0;

    _progressTimer = Timer.periodic(const Duration(milliseconds: 30), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _progressValue += 0.02;
      });
      if (_progressValue >= 1.0) {
        timer.cancel();
        setState(() {
          _currentStep++;
          _isProcessing = false;
          _progressValue = 0.0;
        });
      }
    });
  }

  void _resetSimulation() {
    _progressTimer?.cancel();
    setState(() {
      _currentStep = 0;
      _isProcessing = false;
      _progressValue = 0.0;
    });
  }

  bool get _isCompleted => _currentStep == _steps.length - 1;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final esCiudad = widget.tipoServicio == 'ciudad';

    return Scaffold(
      appBar: AppBar(
        title: Text(
          esCiudad ? 'Demo: Entrega Local' : 'Demo: Entrega Intercity',
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
        ),
        centerTitle: true,
        elevation: 0,
        actions: [
          if (_currentStep > 0)
            IconButton(
              icon: const Icon(Iconsax.refresh_copy, size: 22),
              tooltip: 'Reiniciar',
              onPressed: _resetSimulation,
            ),
        ],
      ),
      body: Column(
        children: [
          // Header con info de la entrega
          _buildHeader(isDark, esCiudad),

          // Timeline de pasos
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              itemCount: _steps.length,
              itemBuilder: (context, index) =>
                  _buildStepItem(index, isDark),
            ),
          ),

          // Boton de avance
          _buildBottomAction(isDark),
        ],
      ),
    );
  }

  Widget _buildHeader(bool isDark, bool esCiudad) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: _isCompleted
              ? [AppColors.green, AppColors.green.withValues(alpha: 0.8)]
              : [AppColors.primary, AppColors.secondary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: (_isCompleted ? AppColors.green : AppColors.primary)
                .withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          // Icono animado
          ScaleTransition(
            scale: _isCompleted || _isProcessing
                ? _pulseAnimation
                : const AlwaysStoppedAnimation(1.0),
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                _isCompleted ? Iconsax.tick_circle_copy : Iconsax.box_1_copy,
                color: Colors.white,
                size: 28,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isCompleted ? 'Entrega completada' : 'Simulacion en curso',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _isCompleted
                      ? 'Todos los pasos finalizados'
                      : esCiudad
                          ? 'Av. Central 123 → Calle 5 Norte 456'
                          : 'Ciudad A → Ciudad B (85 km)',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
                const SizedBox(height: 8),
                // Barra de progreso general
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (_currentStep + (_isProcessing ? _progressValue : 0))
                        / (_steps.length - 1),
                    backgroundColor: Colors.white.withValues(alpha: 0.2),
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(Colors.white),
                    minHeight: 4,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Paso ${_currentStep + 1} de ${_steps.length}',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white.withValues(alpha: 0.7),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepItem(int index, bool isDark) {
    final step = _steps[index];
    final isActive = index == _currentStep;
    final isCompleted = index < _currentStep;
    final isPending = index > _currentStep;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Timeline vertical
        SizedBox(
          width: 40,
          child: Column(
            children: [
              // Circulo del paso
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: isActive ? 36 : 28,
                height: isActive ? 36 : 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isCompleted
                      ? AppColors.green
                      : isActive
                          ? AppColors.accent
                          : isDark
                              ? AppColors.darkCard
                              : Colors.grey.shade200,
                  border: isActive
                      ? Border.all(
                          color: AppColors.accent.withValues(alpha: 0.3),
                          width: 3,
                        )
                      : null,
                  boxShadow: isActive
                      ? [
                          BoxShadow(
                            color: AppColors.accent.withValues(alpha: 0.3),
                            blurRadius: 8,
                          ),
                        ]
                      : null,
                ),
                child: Icon(
                  isCompleted ? Icons.check_rounded : step.icon,
                  size: isActive ? 18 : 14,
                  color: isCompleted || isActive
                      ? Colors.white
                      : Colors.grey.shade400,
                ),
              ),
              // Linea conectora
              if (index < _steps.length - 1)
                Container(
                  width: 2.5,
                  height: 50,
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(2),
                    color: isCompleted
                        ? AppColors.green.withValues(alpha: 0.5)
                        : isDark
                            ? Colors.white.withValues(alpha: 0.08)
                            : Colors.grey.shade200,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        // Contenido del paso
        Expanded(
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 300),
            opacity: isPending ? 0.4 : 1.0,
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isActive
                    ? (isDark
                        ? AppColors.accent.withValues(alpha: 0.12)
                        : AppColors.accent.withValues(alpha: 0.06))
                    : isDark
                        ? AppColors.darkCard
                        : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isActive
                      ? AppColors.accent.withValues(alpha: 0.25)
                      : isCompleted
                          ? AppColors.green.withValues(alpha: 0.2)
                          : isDark
                              ? Colors.white.withValues(alpha: 0.06)
                              : Colors.grey.shade100,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          step.title,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: isCompleted
                                ? AppColors.green
                                : isActive
                                    ? AppColors.accent
                                    : isDark
                                        ? Colors.white
                                        : Colors.black87,
                          ),
                        ),
                      ),
                      if (isCompleted)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.green.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'Listo',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: AppColors.green,
                            ),
                          ),
                        ),
                      if (isActive && _isProcessing)
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              AppColors.accent,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    step.subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white60 : Colors.black54,
                    ),
                  ),
                  if (isActive || isCompleted) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.06)
                            : Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Iconsax.info_circle_copy,
                            size: 14,
                            color:
                                isDark ? Colors.white54 : Colors.grey.shade600,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              step.detail,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: isDark
                                    ? Colors.white70
                                    : Colors.grey.shade700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomAction(bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed:
                _isProcessing ? null : (_isCompleted ? _resetSimulation : _advanceStep),
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  _isCompleted ? AppColors.green : AppColors.primary,
              foregroundColor: Colors.white,
              disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 0,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_isProcessing) ...[
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Procesando...',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ] else if (_isCompleted) ...[
                  const Icon(Iconsax.refresh_copy, size: 20),
                  const SizedBox(width: 10),
                  const Text(
                    'Reiniciar simulacion',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ] else ...[
                  const Text(
                    'Siguiente paso',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Iconsax.arrow_right_1_copy, size: 20),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SimulacionStep {
  final String title;
  final String subtitle;
  final IconData icon;
  final String detail;

  const _SimulacionStep({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.detail,
  });
}
