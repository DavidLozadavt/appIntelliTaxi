import 'package:flutter/material.dart';
import 'package:intellitaxi/core/dio_client.dart';
import 'package:intellitaxi/core/theme/app_colors.dart';
import 'package:intellitaxi/features/taxi/data/motivos_cancelacion.dart';
import 'package:intellitaxi/features/taxi/services/taxi_servicio_cancelacion_service.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

/// Flujo: confirmar → cancelar directo o motivo opcional (chips / texto).
class CancelacionServicioDialog {
  CancelacionServicioDialog._();

  /// `null` = el usuario no confirmó. Vacío = cancelación directa (solo `servicio_id`).
  static Future<CancelacionServicioSeleccion?> mostrar(
    BuildContext context, {
    required String tipoUsuario,
  }) async {
    final catalogFuture =
        TaxiServicioCancelacionService(DioClient.getInstance()).obtenerMotivos();

    final confirmar = await _mostrarConfirmacion(context, tipoUsuario);
    if (confirmar == null || !context.mounted) return null;

    if (confirmar == _ConfirmacionAccion.cancelarDirecto) {
      return const CancelacionServicioSeleccion();
    }

    final catalog = await catalogFuture;
    if (!context.mounted) return null;

    return _mostrarMotivoOpcional(
      context,
      catalog: catalog,
      tipoUsuario: tipoUsuario,
    );
  }

  static Future<_ConfirmacionAccion?> _mostrarConfirmacion(
    BuildContext context,
    String tipoUsuario,
  ) {
    final esConductor = tipoUsuario == 'conductor';
    return showDialog<_ConfirmacionAccion>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Row(
            children: [
              Icon(Iconsax.danger, color: Colors.red.shade600, size: 26),
              const SizedBox(width: 12),
              const Expanded(child: Text('¿Cancelar viaje?')),
            ],
          ),
          content: Text(
            esConductor
                ? 'El servicio se cancelará de inmediato. Puedes indicar un motivo opcional.'
                : 'Tu solicitud se cancelará de inmediato. Puedes indicar un motivo opcional.',
            style: TextStyle(
              fontSize: 15,
              color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
              height: 1.4,
            ),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          actions: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FilledButton(
                  onPressed: () =>
                      Navigator.pop(ctx, _ConfirmacionAccion.cancelarDirecto),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.red.shade600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Sí, cancelar',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () =>
                      Navigator.pop(ctx, _ConfirmacionAccion.indicarMotivo),
                  child: const Text('Indicar motivo (opcional)'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(
                    'Volver',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  static Future<CancelacionServicioSeleccion?> _mostrarMotivoOpcional(
    BuildContext context, {
    required MotivosCancelacionCatalog catalog,
    required String tipoUsuario,
  }) {
    return showModalBottomSheet<CancelacionServicioSeleccion>(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      showDragHandle: true,
      builder: (ctx) => _MotivoCancelacionSheet(
        catalog: catalog,
        tipoUsuario: tipoUsuario,
      ),
    ).then((value) => value ?? const CancelacionServicioSeleccion());
  }
}

enum _ConfirmacionAccion { cancelarDirecto, indicarMotivo }

class _MotivoCancelacionSheet extends StatefulWidget {
  const _MotivoCancelacionSheet({
    required this.catalog,
    required this.tipoUsuario,
  });

  final MotivosCancelacionCatalog catalog;
  final String tipoUsuario;

  @override
  State<_MotivoCancelacionSheet> createState() => _MotivoCancelacionSheetState();
}

class _MotivoCancelacionSheetState extends State<_MotivoCancelacionSheet> {
  String? _codigoSeleccionado;
  final TextEditingController _textoLibre = TextEditingController();

  @override
  void dispose() {
    _textoLibre.dispose();
    super.dispose();
  }

  void _omitir() {
    Navigator.pop(context, const CancelacionServicioSeleccion());
  }

  void _confirmarConMotivo() {
    final texto = _textoLibre.text.trim();
    if (texto.isNotEmpty) {
      Navigator.pop(
        context,
        CancelacionServicioSeleccion(motivoTexto: texto),
      );
      return;
    }
    final codigo = _codigoSeleccionado?.trim();
    if (codigo != null && codigo.isNotEmpty) {
      Navigator.pop(
        context,
        CancelacionServicioSeleccion(motivoCodigo: codigo),
      );
      return;
    }
    _omitir();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottom = MediaQuery.paddingOf(context).bottom;
    final motivos = widget.catalog.motivos;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 8, 20, 16 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '¿Motivo? (opcional)',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            'Si cierras o omites, se cancela como «${widget.catalog.textoSinMotivo}».',
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 16),
          if (motivos.isNotEmpty)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: motivos.map((m) {
                final selected = _codigoSeleccionado == m.codigo;
                return FilterChip(
                  label: Text(m.etiqueta),
                  selected: selected,
                  onSelected: (on) {
                    setState(() {
                      _codigoSeleccionado = on ? m.codigo : null;
                      if (on) _textoLibre.clear();
                    });
                  },
                  selectedColor: AppColors.accent.withValues(alpha: 0.2),
                  checkmarkColor: AppColors.accent,
                );
              }).toList(),
            )
          else
            Text(
              'No hay motivos predefinidos. Puedes escribir uno o cancelar sin motivo.',
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
              ),
            ),
          const SizedBox(height: 14),
          TextField(
            controller: _textoLibre,
            maxLines: 2,
            maxLength: 150,
            onChanged: (_) {
              if (_textoLibre.text.trim().isNotEmpty) {
                setState(() => _codigoSeleccionado = null);
              }
            },
            decoration: InputDecoration(
              labelText: 'Otro motivo (texto libre)',
              hintText: 'Ej. ya no necesito el viaje',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              isDense: true,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _confirmarConMotivo,
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Cancelar con motivo'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: _omitir,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(widget.catalog.textoSinMotivo),
          ),
        ],
      ),
    );
  }
}
