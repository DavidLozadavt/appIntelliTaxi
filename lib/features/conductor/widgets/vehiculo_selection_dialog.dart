import 'package:flutter/material.dart';
import 'package:intellitaxi/features/conductor/data/vehiculo_conductor_model.dart';

/// Diálogo para seleccionar un vehículo antes de iniciar turno
class VehiculoSelectionDialog extends StatelessWidget {
  final List<VehiculoConductor> vehiculos;
  final Function(VehiculoConductor) onVehiculoSelected;

  const VehiculoSelectionDialog({
    super.key,
    required this.vehiculos,
    required this.onVehiculoSelected,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Selecciona un vehículo'),
      content: SizedBox(
        width: double.maxFinite,
        child: vehiculos.isEmpty
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Text(
                    'No tienes vehículos registrados',
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            : ListView.separated(
                shrinkWrap: true,
                itemCount: vehiculos.length,
                separatorBuilder: (context, index) => const Divider(),
                itemBuilder: (context, index) {
                  final vehiculo = vehiculos[index];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.deepOrange.withOpacity(0.2),
                      child: const Icon(
                        Icons.directions_car,
                        color: Colors.deepOrange,
                      ),
                    ),
                    title: Text(
                      vehiculo.placa,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      '${vehiculo.marca} ${vehiculo.modelo}\n${vehiculo.color}',
                    ),
                    isThreeLine: true,
                    onTap: () {
                      Navigator.pop(context);
                      onVehiculoSelected(vehiculo);
                    },
                  );
                },
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
      ],
    );
  }
}
