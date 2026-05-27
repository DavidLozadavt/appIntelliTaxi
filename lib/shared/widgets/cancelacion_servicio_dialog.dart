import 'package:flutter/material.dart';
import 'package:intellitaxi/core/theme/app_colors.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

class CancelacionServicioDialog extends StatefulWidget {
  final String tipoUsuario;

  const CancelacionServicioDialog({super.key, required this.tipoUsuario});

  @override
  State<CancelacionServicioDialog> createState() =>
      _CancelacionServicioDialogState();

  static Future<String?> mostrar(
    BuildContext context, {
    required String tipoUsuario,
  }) {
    final esConductor = tipoUsuario == 'conductor';
    return showGeneralDialog<String?>(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'Cancelar servicio',
      barrierColor: esConductor
          ? Colors.black.withValues(alpha: 0.88)
          : Colors.black.withValues(alpha: 0.55),
      transitionDuration: Duration(milliseconds: esConductor ? 140 : 280),
      pageBuilder: (context, _, _) =>
          CancelacionServicioDialog(tipoUsuario: tipoUsuario),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curve = esConductor ? Curves.easeOutCubic : Curves.easeOutBack;
        return FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: curve),
          child: ScaleTransition(
            scale: Tween<double>(begin: esConductor ? 0.96 : 0.88, end: 1)
                .animate(CurvedAnimation(parent: animation, curve: curve)),
            child: child,
          ),
        );
      },
    );
  }
}

class _CancelacionServicioDialogState extends State<CancelacionServicioDialog> {
  String? _motivoSeleccionado;
  final TextEditingController _otroMotivoController = TextEditingController();

  bool get _esConductor => widget.tipoUsuario == 'conductor';

  List<String> get _motivosPredefinidos {
    if (widget.tipoUsuario == 'pasajero') {
      return [
        'Ya no necesito el servicio',
        'El conductor está tardando mucho',
        'Cambié de planes',
        'Otro motivo',
      ];
    } else {
      return [
        'Problema con el vehículo',
        'Emergencia personal',
        'Pasajero no responde',
        'Otro motivo',
      ];
    }
  }

  void _confirmarCancelacion() {
    if (_motivoSeleccionado == null) {
      _mostrarError('Por favor selecciona un motivo');
      return;
    }

    if (_motivoSeleccionado == 'Otro motivo' &&
        _otroMotivoController.text.trim().isEmpty) {
      _mostrarError('Por favor especifica el motivo');
      return;
    }

    final motivoFinal = _motivoSeleccionado == 'Otro motivo'
        ? _otroMotivoController.text.trim()
        : _motivoSeleccionado!;

    Navigator.pop(context, motivoFinal);
  }

  void _mostrarError(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor: Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  void dispose() {
    _otroMotivoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Colores adaptativos del tema
    final cardColor = isDark ? AppColors.darkCard : Colors.white;
    final backgroundColor = isDark
        ? AppColors.darkSurface
        : Colors.grey.shade50;
    final textColor = isDark ? AppColors.darkOnSurface : Colors.black87;
    final borderColor = isDark ? Colors.grey.shade800 : Colors.grey.shade300;

    final pad = _esConductor ? 16.0 : 24.0;

    return Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_esConductor ? 18 : 24),
        ),
        elevation: _esConductor ? 16 : 10,
        child: Container(
          constraints: BoxConstraints(maxWidth: _esConductor ? 420 : 500),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(_esConductor ? 18 : 24),
            color: cardColor,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: EdgeInsets.all(pad),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkCard : Colors.red.shade50,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(_esConductor ? 18 : 24),
                    topRight: Radius.circular(_esConductor ? 18 : 24),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: cardColor,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.red.withValues(alpha: 0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(
                        Iconsax.danger,
                        color: Colors.red.shade600,
                        size: _esConductor ? 24 : 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Cancelar servicio',
                            style: TextStyle(
                              fontSize: _esConductor ? 18 : 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '¿Por qué deseas cancelar?',
                            style: TextStyle(
                              fontSize: _esConductor ? 13 : 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              Flexible(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(pad),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ..._motivosPredefinidos.asMap().entries.map((entry) {
                        final index = entry.key;
                        final motivo = entry.value;
                        final isSelected = _motivoSeleccionado == motivo;
                        final isLast = index == _motivosPredefinidos.length - 1;

                        final tile = Container(
                            margin: EdgeInsets.only(
                              bottom: isLast ? 0 : (_esConductor ? 8 : 12),
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () {
                                  setState(() {
                                    _motivoSeleccionado = motivo;
                                  });
                                },
                                borderRadius: BorderRadius.circular(
                                  _esConductor ? 12 : 16,
                                ),
                                child: AnimatedContainer(
                                  duration: Duration(
                                    milliseconds: _esConductor ? 100 : 200,
                                  ),
                                  padding: EdgeInsets.all(
                                    _esConductor ? 12 : 16,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? AppColors.accent.withValues(
                                            alpha: 0.1,
                                          )
                                        : backgroundColor,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: isSelected
                                          ? AppColors.accent
                                          : borderColor,
                                      width: isSelected ? 2 : 1,
                                    ),
                                    boxShadow: isSelected
                                        ? [
                                            BoxShadow(
                                              color: AppColors.accent
                                                  .withValues(alpha: 0.2),
                                              blurRadius: 8,
                                              offset: const Offset(0, 4),
                                            ),
                                          ]
                                        : [],
                                  ),
                                  child: Row(
                                    children: [
                                      AnimatedContainer(
                                        duration: Duration(
                                          milliseconds: _esConductor ? 100 : 200,
                                        ),
                                        width: 24,
                                        height: 24,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: isSelected
                                                ? AppColors.accent
                                                : Colors.grey.shade400,
                                            width: 2,
                                          ),
                                          color: isSelected
                                              ? AppColors.accent
                                              : Colors.transparent,
                                        ),
                                        child: isSelected
                                            ? const Icon(
                                                Icons.check,
                                                size: 16,
                                                color: Colors.white,
                                              )
                                            : null,
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Text(
                                          motivo,
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: isSelected
                                                ? FontWeight.w600
                                                : FontWeight.normal,
                                            color: isSelected
                                                ? AppColors.accent
                                                : textColor,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );

                        if (_esConductor) return tile;

                        return TweenAnimationBuilder<double>(
                          duration: Duration(milliseconds: 200 + (index * 50)),
                          tween: Tween(begin: 0.0, end: 1.0),
                          builder: (context, value, child) {
                            return Transform.translate(
                              offset: Offset(0, 20 * (1 - value)),
                              child: Opacity(opacity: value, child: child),
                            );
                          },
                          child: tile,
                        );
                      }),

                      if (_motivoSeleccionado == 'Otro motivo') ...[
                        SizedBox(height: _esConductor ? 10 : 14),
                        if (_esConductor)
                          _buildOtroMotivoField(
                            backgroundColor: backgroundColor,
                            textColor: textColor,
                            isDark: isDark,
                          )
                        else
                          TweenAnimationBuilder<double>(
                            duration: const Duration(milliseconds: 220),
                            tween: Tween(begin: 0.0, end: 1.0),
                            builder: (context, value, child) {
                              return Opacity(opacity: value, child: child);
                            },
                            child: _buildOtroMotivoField(
                              backgroundColor: backgroundColor,
                              textColor: textColor,
                              isDark: isDark,
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
              ),

              Container(
                padding: EdgeInsets.all(pad),
                decoration: BoxDecoration(
                  color: backgroundColor,
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(_esConductor ? 18 : 24),
                    bottomRight: Radius.circular(_esConductor ? 18 : 24),
                  ),
                  border: Border(top: BorderSide(color: Colors.grey.shade200)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: EdgeInsets.symmetric(
                            vertical: _esConductor ? 12 : 16,
                          ),
                          side: BorderSide(color: Colors.grey.shade400),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Volver',
                          style: TextStyle(
                            fontSize: _esConductor ? 15 : 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: _confirmarCancelacion,
                        style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.symmetric(
                            vertical: _esConductor ? 12 : 16,
                          ),
                          backgroundColor: Colors.red.shade600,
                          foregroundColor: Colors.white,
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Iconsax.close_circle,
                              size: _esConductor ? 18 : 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Confirmar',
                              style: TextStyle(
                                fontSize: _esConductor ? 15 : 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
  }

  Widget _buildOtroMotivoField({
    required Color backgroundColor,
    required Color textColor,
    required bool isDark,
  }) {
    final radius = _esConductor ? 12.0 : 14.0;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: isDark ? 0.12 : 0.08),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: AppColors.accent, width: 1.5),
      ),
      padding: EdgeInsets.fromLTRB(
        _esConductor ? 12 : 14,
        _esConductor ? 10 : 12,
        _esConductor ? 12 : 14,
        _esConductor ? 8 : 10,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Describe el motivo',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.accent,
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _otroMotivoController,
            autofocus: true,
            maxLines: 2,
            minLines: 2,
            maxLength: 150,
            style: TextStyle(fontSize: 15, color: textColor, height: 1.35),
            decoration: InputDecoration(
              isDense: true,
              hintText: 'Ej. tráfico, dirección incorrecta…',
              hintStyle: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.grey[500] : Colors.grey[600],
              ),
              filled: true,
              fillColor: backgroundColor,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                  color: AppColors.accent.withValues(alpha: 0.5),
                  width: 1,
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              counterStyle: TextStyle(
                fontSize: 11,
                color: isDark ? Colors.grey[600] : Colors.grey[500],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
