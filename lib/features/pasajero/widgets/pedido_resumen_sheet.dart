import 'package:flutter/material.dart';
import 'package:intellitaxi/core/theme/app_colors.dart';
import 'package:intellitaxi/features/pasajero/data/service_pin.dart';

Future<bool> showPedidoResumenSheet({
  required BuildContext context,
  required String serviceType,
  required ServicePin pickup,
  ServicePin? destination,
  String? precioTexto,
}) async {
  final ok = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) {
      final isTaxi = serviceType == 'taxi';
      return Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          4,
          20,
          16 + MediaQuery.paddingOf(ctx).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              isTaxi ? 'Confirmar taxi' : 'Confirmar domicilio',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            _PinResumen(title: 'Recogida', pin: pickup, color: AppColors.green),
            if (destination != null) ...[
              const SizedBox(height: 12),
              _PinResumen(
                title: isTaxi ? 'Destino' : 'Entrega',
                pin: destination,
                color: AppColors.primary,
              ),
            ],
            if (precioTexto != null && precioTexto.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Precio: $precioTexto',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
            ] else ...[
              const SizedBox(height: 12),
              const Text(
                'El valor se calcula con taxímetro.',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(52),
              ),
              child: const Text(
                'Confirmar pedido',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Seguir ajustando'),
            ),
          ],
        ),
      );
    },
  );
  return ok == true;
}

class _PinResumen extends StatelessWidget {
  const _PinResumen({
    required this.title,
    required this.pin,
    required this.color,
  });

  final String title;
  final ServicePin pin;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.place, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
              Text(
                pin.barrioNombre,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
              if (pin.referencia.trim().isNotEmpty)
                Text(pin.referencia.trim()),
            ],
          ),
        ),
      ],
    );
  }
}
