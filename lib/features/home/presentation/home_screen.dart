import 'package:intellitaxi/features/home/presentation/custom_drawer.dart';
import 'package:intellitaxi/features/conductor/presentation/home_conductor.dart';
import 'package:intellitaxi/features/pasajero/presentation/home_pasajero_screen.dart';
import 'package:intellitaxi/features/profile/presentation/profile_screen.dart';
import 'package:intellitaxi/core/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../auth/providers/auth_provider.dart';
import 'package:intellitaxi/core/services/app_logger.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _roleDialogShown = false;
  bool _welcomeShown = false;

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
          AppLogger.d('⚠️ HomeScreen: Usuario es NULL');
          return const Center(child: CircularProgressIndicator());
        }

        final roles = authProvider.roles;
        final activeRole = authProvider.activeRole;
        AppLogger.d('👤 HomeScreen: Usuario ID: ${user.id}');
        AppLogger.d('👤 HomeScreen: Nombre: ${user.nombreCompleto}');
        AppLogger.d('🎭 HomeScreen: Roles: $roles');
        AppLogger.d('🎯 HomeScreen: Rol activo: $activeRole');

        if (authProvider.canSwitchRole &&
            authProvider.activeRole == null &&
            !_roleDialogShown) {
          _roleDialogShown = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            _mostrarSelectorRol(context, authProvider, canDismiss: false);
          });
        }

        if (!_welcomeShown &&
            (!authProvider.canSwitchRole || authProvider.activeRole != null)) {
          _welcomeShown = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            // _mostrarSaludoBienvenida(user.persona.nombre1);
          });
        }

        Widget body;

        // Verificar rol activo/conductor
        if (activeRole == AuthProvider.roleConductor ||
            (!authProvider.canSwitchRole && authProvider.hasConductorRole)) {
          AppLogger.d('✅ HomeScreen: Mostrando pantalla de CONDUCTOR');
          body = const HomeConductor(stories: []);
        }
        // Verificar rol activo/pasajero
        else if (activeRole == AuthProvider.rolePasajero ||
            (!authProvider.canSwitchRole && authProvider.hasPasajeroRole)) {
          AppLogger.d('✅ HomeScreen: Mostrando pantalla de PASAJERO');
          body = const HomePasajero(stories: []);
        }
        // Tiene ambos roles y aún no selecciona
        else if (authProvider.canSwitchRole && activeRole == null) {
          body = const Center(child: CircularProgressIndicator());
        }
        // Si no tiene ninguno de estos roles
        else {
          AppLogger.d('⚠️ HomeScreen: Rol NO reconocido');
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
                    // IconButton(
                    //   icon:  Icon(Icons.emergency, color: Colors.red.shade400),
                    //   onPressed: () =>
                    //       Navigator.pushNamed(context, '/emergencias'),
                    // ),
                    IconButton(
                      icon: const Icon(Icons.notifications_none),
                      onPressed: () =>
                          Navigator.pushNamed(context, '/notifications'),
                    ),
                    if (authProvider.canSwitchRole)
                      IconButton(
                        tooltip: 'Cambiar rol',
                        icon: const Icon(Icons.swap_horiz),
                        onPressed: () {
                          _mostrarSelectorRol(
                            context,
                            authProvider,
                            canDismiss: true,
                          );
                        },
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

  // void _mostrarSaludoBienvenida(String nombre) {
  //   final nombreLimpio = nombre.trim();
  //   final saludo = nombreLimpio.isEmpty
  //       ? 'Hola de nuevo. Qué bueno verte por aquí.'
  //       : 'Hola de nuevo, $nombreLimpio. Qué bueno verte por aquí.';

  //   ScaffoldMessenger.of(context)
  //     ..clearSnackBars()
  //     ..showSnackBar(
  //       SnackBar(
  //         content: Text(
  //           saludo,
  //           style: const TextStyle(fontWeight: FontWeight.w700),
  //         ),
  //         behavior: SnackBarBehavior.floating,
  //         backgroundColor: AppColors.primary,
  //         duration: const Duration(seconds: 3),
  //         shape: RoundedRectangleBorder(
  //           borderRadius: BorderRadius.circular(12),
  //         ),
  //         margin: const EdgeInsets.fromLTRB(16, 0, 16, 18),
  //       ),
  //     );
  // }

  Future<void> _mostrarSelectorRol(
    BuildContext context,
    AuthProvider authProvider, {
    required bool canDismiss,
  }) async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      isDismissible: canDismiss,
      enableDrag: canDismiss,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final activeRole = authProvider.activeRole;

        Widget buildRoleCard({
          required String role,
          required String title,
          required String subtitle,
          required IconData icon,
        }) {
          final isActive = activeRole == role;
          return InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => Navigator.pop(context, role),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: isDark ? AppColors.darkCard : Colors.white,
                border: Border.all(
                  color: isActive ? AppColors.accent : Colors.grey.shade300,
                  width: isActive ? 2 : 1,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: AppColors.accent),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white70 : Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isActive)
                    Icon(Icons.check_circle, color: AppColors.accent),
                ],
              ),
            ),
          );
        }

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.16),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 44,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade400,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Elige tu modo',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Puedes cambiarlo cuando quieras.',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.white70 : Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 16),
                    buildRoleCard(
                      role: AuthProvider.rolePasajero,
                      title: 'Pasajero',
                      subtitle: 'Solicitar viaje y gestionar servicios.',
                      icon: Icons.person_outline,
                    ),
                    const SizedBox(height: 12),
                    buildRoleCard(
                      role: AuthProvider.roleConductor,
                      title: 'Conductor',
                      subtitle: 'Recibir solicitudes y trabajar en turno.',
                      icon: Icons.local_taxi_outlined,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );

    _roleDialogShown = false;
    if (selected != null) {
      await authProvider.setActiveRole(selected);
    }
  }
}
