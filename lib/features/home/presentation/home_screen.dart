import 'package:intellitaxi/features/home/presentation/custom_drawer.dart';
import 'package:intellitaxi/features/conductor/presentation/home_conductor.dart';
import 'package:intellitaxi/features/pasajero/home_pasajero.dart';
import 'package:intellitaxi/features/Profile/presentation/profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../auth/logic/auth_provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    // Inicialización si es necesaria
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        final user = authProvider.user;

        if (user == null) {
          print('⚠️ HomeScreen: Usuario es NULL');
          return const Center(child: CircularProgressIndicator());
        }

        final roles = authProvider.roles;
        print('👤 HomeScreen: Usuario ID: ${user.id}');
        print('👤 HomeScreen: Nombre: ${user.nombreCompleto}');
        print('🎭 HomeScreen: Roles: $roles');

        Widget body;

        // Verificar rol de conductor (driver)
        if (roles.any(
          (r) => ['CONDUCTOR', 'MOTORISTA', 'DRIVER', 'Admin'].contains(r),
        )) {
          print('✅ HomeScreen: Mostrando pantalla de CONDUCTOR');
          body = const HomeConductor(stories: []);
        }
        // Verificar rol de pasajero (passenger)
        else if (roles.any(
          (r) => [
            'PASAJERO',
            'PASSENGER',
            'CLIENTE',
            'AUXILIAR CONTAB',
          ].contains(r),
        )) {
          print('✅ HomeScreen: Mostrando pantalla de PASAJERO');
          body = const HomePasajero(stories: []);
        }
        // Si no tiene ninguno de estos roles
        else {
          print('⚠️ HomeScreen: Rol NO reconocido');
          body = const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: Colors.orange),
                SizedBox(height: 16),
                Text(
                  "Rol no reconocido",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text(
                  "Por favor contacta con soporte",
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(
            // backgroundColor: Colors.white,
            elevation: 0,
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Hola,", style: TextStyle(fontSize: 14)),
                      Text(
                        user.persona.nombre1,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.notifications_none),
                      onPressed: () =>
                          Navigator.pushNamed(context, '/notifications'),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ProfileTab(),
                          ),
                        );
                      },
                      child: CircleAvatar(
                        radius: 18,
                        backgroundColor: Colors.blue.shade100,
                        backgroundImage:
                            user.persona.rutaFotoUrl != null &&
                                user.persona.rutaFotoUrl!.isNotEmpty
                            ? NetworkImage(user.persona.rutaFotoUrl!)
                            : null,
                        onBackgroundImageError: user.persona.rutaFotoUrl != null
                            ? (exception, stackTrace) {
                                debugPrint(
                                  '⚠️ Error cargando avatar: $exception',
                                );
                              }
                            : null,
                        child:
                            (user.persona.rutaFotoUrl == null ||
                                user.persona.rutaFotoUrl!.isEmpty)
                            ? Text(
                                user.persona.nombre1.isNotEmpty
                                    ? user.persona.nombre1[0].toUpperCase()
                                    : '?',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              )
                            : null,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          drawer: const CustomDrawer(),
          body: body,
        );
      },
    );
  }
}
