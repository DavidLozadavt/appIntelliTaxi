import 'package:intellitaxi/features/auth/data/auth_model.dart';
import 'package:flutter/material.dart';

class CuentaTab extends StatelessWidget {
  final Persona persona;
  const CuentaTab({super.key, required this.persona});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Divider(height: 2),

          if (persona.email != null)
            ListTile(
              leading: const Icon(Icons.email, color: Colors.orange),
              title: const Text("Correo"),
              subtitle: Text(persona.email!),
            ),

          if (persona.celular != null)
            ListTile(
              leading: const Icon(Icons.phone, color: Colors.blue),
              title: const Text("Teléfono"),
              subtitle: Text(persona.celular!),
            ),

          // if (persona.direccion != null)
          //   ListTile(
          //     leading: const Icon(Icons.location_on, color: Colors.red),
          //     title: const Text("Dirección",),
          //     subtitle: Text(persona.direccion!),
          //   ),
        ],
      ),
    );
  }
}
