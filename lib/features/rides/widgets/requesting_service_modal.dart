import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intellitaxi/core/theme/app_colors.dart';

class RequestingServiceModal extends StatefulWidget {
  final bool isDelivery;
  final String origin;
  final String destination;
  final String distance;
  final String duration;
  final String price;

  const RequestingServiceModal({
    super.key,
    required this.isDelivery,
    required this.origin,
    required this.destination,
    required this.distance,
    required this.duration,
    required this.price,
  });

  @override
  State<RequestingServiceModal> createState() => _RequestingServiceModalState();
}

class _RequestingServiceModalState extends State<RequestingServiceModal>
    with TickerProviderStateMixin {
  Timer? _timer;
  final ValueNotifier<int> _remainingSeconds = ValueNotifier(120);
  final ValueNotifier<int> _dotCount = ValueNotifier(0);
  
  late AnimationController _pulseController;
  late AnimationController _rotateController;
  late AnimationController _scaleController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _rotateAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    
    // Animación de pulso para el icono
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Animación de rotación suave
    _rotateController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat();
    
    _rotateAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _rotateController, curve: Curves.linear),
    );

    // Animación de escala para entrada
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    
    _scaleAnimation = CurvedAnimation(
      parent: _scaleController,
      curve: Curves.easeOutBack,
    );
    
    _scaleController.forward();

    // Timer
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _remainingSeconds.value--;
      _dotCount.value = (_dotCount.value + 1) % 4;
      
      if (_remainingSeconds.value <= 0) {
        timer.cancel();
        if (mounted) {
          Navigator.pop(context);
        }
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _remainingSeconds.dispose();
    _dotCount.dispose();
    _pulseController.dispose();
    _rotateController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = widget.isDelivery ? Colors.green : AppColors.accent;

    return WillPopScope(
      onWillPop: () async => true,
      child: Dialog(
        backgroundColor: Colors.transparent,
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.85,
              maxWidth: 400,
            ),
            margin: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isDark
                      ? [Colors.grey.shade900, Colors.grey.shade800]
                      : [Colors.white, Colors.grey.shade50],
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Icono animado con pulso y anillos
                  _buildAnimatedIcon(primaryColor),
                  
                  const SizedBox(height: 32),

                  // Texto principal con fade in
                  TweenAnimationBuilder<double>(
                    duration: const Duration(milliseconds: 600),
                    tween: Tween(begin: 0.0, end: 1.0),
                    builder: (context, value, child) {
                      return Opacity(
                        opacity: value,
                        child: Transform.translate(
                          offset: Offset(0, 20 * (1 - value)),
                          child: child,
                        ),
                      );
                    },
                    child: Text(
                      'Solicitando servicio',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  
                  const SizedBox(height: 12),
                  
                  TweenAnimationBuilder<double>(
                    duration: const Duration(milliseconds: 800),
                    tween: Tween(begin: 0.0, end: 1.0),
                    builder: (context, value, child) {
                      return Opacity(
                        opacity: value,
                        child: child,
                      );
                    },
                    child: Text(
                      widget.isDelivery
                          ? 'Buscando el mejor conductor\npara tu domicilio'
                          : 'Conectando con conductores\ncercanos a tu ubicación',
                      style: TextStyle(
                        fontSize: 15,
                        color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                        height: 1.4,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  
                  const SizedBox(height: 40),

                  // Barra de progreso circular animada
                  _buildProgressIndicator(primaryColor),
                  
                  const SizedBox(height: 32),

                  // Contador con efecto
                  _buildTimer(primaryColor, isDark),
                  
                  const SizedBox(height: 20),

                  // Indicador de puntos
                  _buildDotIndicator(primaryColor, isDark),
                  
                  const SizedBox(height: 24),

                  // Botón cancelar con hover
                  _buildCancelButton(isDark),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedIcon(Color primaryColor) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Anillos pulsantes
        AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (context, child) {
            return Container(
              width: 80 * _pulseAnimation.value,
              height: 80 * _pulseAnimation.value,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: primaryColor.withOpacity(0.3 / _pulseAnimation.value),
                  width: 2,
                ),
              ),
            );
          },
        ),
        
        // Segundo anillo con delay
        AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (context, child) {
            final delayedValue = (_pulseAnimation.value - 1.0) * 0.5 + 1.0;
            return Container(
              width: 80 * delayedValue.clamp(1.0, 1.15),
              height: 80 * delayedValue.clamp(1.0, 1.15),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: primaryColor.withOpacity(
                    0.2 / delayedValue.clamp(1.0, 1.15),
                  ),
                  width: 2,
                ),
              ),
            );
          },
        ),
        
        // Icono principal con pulso
        AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _pulseAnimation.value,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: primaryColor,
                  boxShadow: [
                    BoxShadow(
                      color: primaryColor.withOpacity(0.4),
                      blurRadius: 15 * _pulseAnimation.value,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Icon(
                  widget.isDelivery
                      ? Icons.shopping_bag_rounded
                      : Icons.local_taxi_rounded,
                  size: 40,
                  color: Colors.white,
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildProgressIndicator(Color primaryColor) {
    return SizedBox(
      width: 120,
      height: 120,
      child: ValueListenableBuilder<int>(
        valueListenable: _remainingSeconds,
        builder: (context, seconds, child) {
          final progress = seconds / 120;
          return Stack(
            alignment: Alignment.center,
            children: [
              // Círculo de fondo
              SizedBox(
                width: 120,
                height: 120,
                child: CircularProgressIndicator(
                  value: 1.0,
                  strokeWidth: 6,
                  valueColor: AlwaysStoppedAnimation(
                    primaryColor.withOpacity(0.1),
                  ),
                ),
              ),
              // Círculo de progreso animado
              RotationTransition(
                turns: _rotateAnimation,
                child: SizedBox(
                  width: 120,
                  height: 120,
                  child: CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 6,
                    valueColor: AlwaysStoppedAnimation(primaryColor),
                    strokeCap: StrokeCap.round,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTimer(Color primaryColor, bool isDark) {
    return ValueListenableBuilder<int>(
      valueListenable: _remainingSeconds,
      builder: (context, seconds, child) {
        return TweenAnimationBuilder<double>(
          key: ValueKey(seconds),
          duration: const Duration(milliseconds: 300),
          tween: Tween(begin: 0.8, end: 1.0),
          curve: Curves.elasticOut,
          builder: (context, scale, child) {
            return Transform.scale(
              scale: scale,
              child: Text(
                '${(seconds / 60).floor()}:${(seconds % 60).toString().padLeft(2, '0')}',
                style: TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  color: primaryColor,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDotIndicator(Color primaryColor, bool isDark) {
    return ValueListenableBuilder<int>(
      valueListenable: _dotCount,
      builder: (context, dots, child) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Buscando conductor',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
              ),
            ),
            const SizedBox(width: 8),
            ...List.generate(3, (index) {
              return TweenAnimationBuilder<double>(
                key: ValueKey('$dots-$index'),
                duration: const Duration(milliseconds: 300),
                tween: Tween(
                  begin: index <= dots ? 0.3 : 1.0,
                  end: index <= dots ? 1.0 : 0.3,
                ),
                curve: Curves.easeInOut,
                builder: (context, opacity, child) {
                  return Opacity(
                    opacity: opacity,
                    child: Text(
                      '•',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: primaryColor,
                      ),
                    ),
                  );
                },
              );
            }),
          ],
        );
      },
    );
  }

  Widget _buildCancelButton(bool isDark) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: TextButton(
        onPressed: () => Navigator.pop(context),
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(
            horizontal: 32,
            vertical: 12,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(
          'Cancelar solicitud',
          style: TextStyle(
            color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}