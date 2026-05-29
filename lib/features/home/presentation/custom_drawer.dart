import 'package:intellitaxi/core/theme/theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:intellitaxi/features/auth/data/drawer_item.dart';
import 'package:intellitaxi/features/auth/providers/auth_provider.dart';
import 'package:intellitaxi/core/theme/app_colors.dart';

class CustomDrawer extends StatelessWidget {
  const CustomDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    // final company = auth.company;
    final userRoles = auth.activeRole != null ? [auth.activeRole!] : auth.roles;

    final themeProvider = context.watch<ThemeProvider>();

    final allDrawerItems = [
      // Opciones de historial y calificaciones para conductor
      DrawerItem(
        title: 'Mis Servicios Terminados',
        icon: Iconsax.task_square_copy,
        route: '/historial-conductor',
        allowedRoles: [AuthProvider.roleConductor],
      ),
      // DrawerItem(
      //   title: 'Entregas',
      //   icon: Iconsax.box_1_copy,
      //   route: '/entregas',
      //   allowedRoles: [AuthProvider.roleConductor],
      // ),
      DrawerItem(
        title: 'Mis Calificaciones',
        icon: Iconsax.star_1_copy,
        route: '/calificaciones-conductor',
        allowedRoles: [AuthProvider.roleConductor],
      ),
      // Opciones de historial y calificaciones para pasajero
      DrawerItem(
        title: 'Mis Viajes',
        icon: Iconsax.routing_2_copy,
        route: '/historial-pasajero',
        allowedRoles: [AuthProvider.rolePasajero],
      ),
      DrawerItem(
        title: 'Mis Calificaciones',
        icon: Iconsax.star_1_copy,
        route: '/calificaciones-pasajero',
        allowedRoles: [AuthProvider.rolePasajero],
      ),
      // Opciones existentes
      // DrawerItem(
      //   title: 'Horas Extras',
      //   icon: Iconsax.clock_copy,
      //   route: '/horas-extras',
      //   allowedRoles: ["Admin", "MOTORISTA", "CONDUCTOR", "ADMINISTRADOR"],
      // ),
      // DrawerItem(
      //   title: 'Mis Deducciones',
      //   icon: Iconsax.note_2_copy,
      //   route: '/mis-deducciones',
      //   allowedRoles: ["MOTORISTA", "CONDUCTOR", "ADMINISTRADOR"],
      // ),
      DrawerItem(
        title: 'Mis Sanciones',
        icon: Iconsax.warning_2_copy,
        route: '/mis-sanciones',
        allowedRoles: [AuthProvider.roleConductor],
      ),
      DrawerItem(
        title: 'Mis Documentos',
        icon: Iconsax.document_text_copy,
        route: '/mis-documentos',
        allowedRoles: ["MOTORISTA", AuthProvider.roleConductor],
      ),
      DrawerItem(
        title: 'Mis Vehículos',
        icon: Iconsax.car_copy,
        route: '/mis-vehiculos',
        allowedRoles: [AuthProvider.roleConductor],
      ),
      DrawerItem(
        title: 'Ajustes',
        icon: Iconsax.setting_2_copy,
        route: '/conductor-ajustes',
        allowedRoles: [AuthProvider.roleConductor],
      ),
      // DrawerItem(
      //   title: 'Diagnóstico de la app',
      //   icon: Iconsax.health_copy,
      //   route: '/app-diagnostics',
      //   allowedRoles: const [],
      // ),
      // DrawerItem(
      //   title: 'Kanban',
      //   icon: Iconsax.element_4_copy,
      //   route: '/kanban',
      //   allowedRoles: [],
      // ),
      // DrawerItem(
      //   title: '🎨 Iconos Iconsax',
      //   icon: Iconsax.brush_1_copy,
      //   route: '/test-iconsax',
      //   allowedRoles: [],
      // ),
    ];

    final visibleDrawerItems = allDrawerItems.where((item) {
      return item.allowedRoles.isEmpty ||
          item.allowedRoles.any((role) => userRoles.contains(role));
    }).toList();

    return Drawer(
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      child: Column(
        children: [
          // HEADER mejorado
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primary, AppColors.accent],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.accent.withValues(alpha: 0.3),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    // Avatar con sombra
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 15,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: CircleAvatar(
                        radius: 30,
                        backgroundColor: Colors.white,
                        child: CircleAvatar(
                          radius: 27,
                          backgroundImage: NetworkImage(
                            auth.user!.persona.rutaFotoUrl!,
                          ),
                          onBackgroundImageError: (_, _) =>
                              const Icon(Icons.person, size: 35),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Info del usuario
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Nombre
                          Text(
                            "${auth.user!.persona.nombre1} ${auth.user!.persona.apellido1}",
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              shadows: [
                                Shadow(color: Colors.black26, blurRadius: 8),
                              ],
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                          const SizedBox(height: 4),
                          // Roles con icono
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Iconsax.shield_tick_copy,
                                size: 14,
                                color: Colors.white.withValues(alpha: 0.9),
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  auth.roles.isNotEmpty
                                      ? auth.roles.join(", ")
                                      : "Sin rol",
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.white.withValues(alpha: 0.9),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 2,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 8),

          // Modo descanso y switches movidos a Ajustes (/conductor-ajustes).

          // ITEMS mejorados (scrollable)
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                ...visibleDrawerItems.map(
                  (item) => Container(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListTile(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.accent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          item.icon,
                          color: AppColors.accent,
                          size: 22,
                        ),
                      ),
                      title: Text(
                        item.title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      trailing: Icon(
                        Iconsax.arrow_right_3_copy,
                        size: 18,
                        color: Colors.grey.shade400,
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.pushNamed(context, item.route);
                      },
                    ),
                  ),
                ),

                if (auth.canSwitchRole)
                  Container(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListTile(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.accent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.swap_horiz,
                          color: AppColors.accent,
                          size: 22,
                        ),
                      ),
                      title: const Text(
                        'Cambiar rol',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        'Actual: ${auth.activeRole ?? 'SIN SELECCIONAR'}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      trailing: Icon(
                        Iconsax.arrow_right_3_copy,
                        size: 18,
                        color: Colors.grey.shade400,
                      ),
                      onTap: () async {
                        final selected = await showModalBottomSheet<String>(
                          context: context,
                          backgroundColor: Colors.transparent,
                          builder: (context) {
                            final isDark =
                                Theme.of(context).brightness == Brightness.dark;
                            final activeRole = auth.activeRole;

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
                                    color: isDark
                                        ? AppColors.darkCard
                                        : Colors.white,
                                    border: Border.all(
                                      color: isActive
                                          ? AppColors.accent
                                          : Colors.grey.shade300,
                                      width: isActive ? 2 : 1,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 44,
                                        height: 44,
                                        decoration: BoxDecoration(
                                          color: AppColors.accent.withValues(
                                            alpha: 0.15,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        child: Icon(
                                          icon,
                                          color: AppColors.accent,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              title,
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w700,
                                                color: isDark
                                                    ? Colors.white
                                                    : Colors.black87,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              subtitle,
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: isDark
                                                    ? Colors.white70
                                                    : Colors.black54,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (isActive)
                                        const Icon(
                                          Icons.check_circle,
                                          color: AppColors.accent,
                                        ),
                                    ],
                                  ),
                                ),
                              );
                            }

                            return SafeArea(
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  16,
                                  16,
                                  12,
                                ),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? AppColors.darkSurface
                                        : Colors.white,
                                    borderRadius: BorderRadius.circular(24),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(
                                          alpha: 0.16,
                                        ),
                                        blurRadius: 20,
                                        offset: const Offset(0, 8),
                                      ),
                                    ],
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(20),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Center(
                                          child: Container(
                                            width: 44,
                                            height: 4,
                                            decoration: BoxDecoration(
                                              color: Colors.grey.shade400,
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 16),
                                        Text(
                                          'Cambiar modo de uso',
                                          style: TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.w800,
                                            color: isDark
                                                ? Colors.white
                                                : Colors.black87,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          'Selecciona cómo quieres continuar.',
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: isDark
                                                ? Colors.white70
                                                : Colors.black54,
                                          ),
                                        ),
                                        const SizedBox(height: 16),
                                        buildRoleCard(
                                          role: AuthProvider.rolePasajero,
                                          title: 'Pasajero',
                                          subtitle:
                                              'Solicitar viaje y gestionar servicios.',
                                          icon: Icons.person_outline,
                                        ),
                                        const SizedBox(height: 12),
                                        buildRoleCard(
                                          role: AuthProvider.roleConductor,
                                          title: 'Conductor',
                                          subtitle:
                                              'Recibir solicitudes y trabajar en turno.',
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

                        if (selected != null) {
                          await auth.setActiveRole(selected);
                        }

                        if (context.mounted) {
                          Navigator.pop(context);
                        }
                      },
                    ),
                  ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Divider(color: Colors.grey.shade300, thickness: 1),
          ),

          // Container(
          //   margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          //   decoration: BoxDecoration(borderRadius: BorderRadius.circular(12)),
          //   child: ListTile(
          //     shape: RoundedRectangleBorder(
          //       borderRadius: BorderRadius.circular(12),
          //     ),
          //     leading: Container(
          //       padding: const EdgeInsets.all(8),
          //       decoration: BoxDecoration(
          //         color: AppColors.accent.withValues(alpha: 0.15),
          //         borderRadius: BorderRadius.circular(10),
          //       ),
          //       child: const Icon(
          //         Iconsax.document_text_copy,
          //         color: AppColors.accent,
          //         size: 22,
          //       ),
          //     ),
          //     title: const Text(
          //       'Política de privacidad',
          //       style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          //     ),
          //     trailing: Icon(
          //       Iconsax.arrow_right_3_copy,
          //       size: 18,
          //       color: Colors.grey.shade400,
          //     ),
          //     onTap: () {
          //       Navigator.pop(context);
          //       Navigator.pushNamed(context, '/politica-privacidad');
          //     },
          //   ),
          // ),

          // Botón Dark/Light mode mejorado
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  themeProvider.themeMode == ThemeMode.dark
                      ? Iconsax.sun_1_copy
                      : Iconsax.moon_copy,
                  color: AppColors.accent,
                  size: 22,
                ),
              ),
              title: Text(
                themeProvider.themeMode == ThemeMode.dark
                    ? "Modo Claro"
                    : "Modo Oscuro",
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              trailing: Icon(
                Iconsax.arrow_right_3_copy,
                size: 18,
                color: Colors.grey.shade400,
              ),
              onTap: () {
                themeProvider.toggleTheme();
              },
            ),
          ),

          // Cerrar sesión mejorado
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Iconsax.logout_copy,
                  color: Colors.redAccent,
                  size: 22,
                ),
              ),
              title: const Text(
                "Cerrar sesión",
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.redAccent,
                ),
              ),
              trailing: const Icon(
                Iconsax.arrow_right_3_copy,
                size: 18,
                color: Colors.redAccent,
              ),
              onTap: () {
                auth.logout();
                Navigator.pushReplacementNamed(context, '/login');
              },
            ),
          ),

          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
