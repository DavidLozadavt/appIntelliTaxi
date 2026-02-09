import 'package:intellitaxi/core/theme/theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:intellitaxi/features/auth/data/drawer_item.dart';
import 'package:intellitaxi/features/auth/logic/auth_provider.dart';
import 'package:intellitaxi/core/theme/app_colors.dart';

class CustomDrawer extends StatelessWidget {
  const CustomDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    // final company = auth.company;
    final userRoles = auth.roles;

    final themeProvider = context.watch<ThemeProvider>();

    final allDrawerItems = [
      // Opciones de historial y calificaciones para conductor
      DrawerItem(
        title: 'Mis Servicios Terminados',
        icon: Iconsax.task_square_copy,
        route: '/historial-conductor',
        allowedRoles: ["CONDUCTOR"],
      ),
      DrawerItem(
        title: 'Mis Calificaciones',
        icon: Iconsax.star_1_copy,
        route: '/calificaciones-conductor',
        allowedRoles: ["CONDUCTOR"],
      ),
      // Opciones de historial y calificaciones para pasajero
      DrawerItem(
        title: 'Mis Viajes',
        icon: Iconsax.routing_2_copy,
        route: '/historial-pasajero',
        allowedRoles: ["PASAJERO"],
      ),
      DrawerItem(
        title: 'Mis Calificaciones',
        icon: Iconsax.star_1_copy,
        route: '/calificaciones-pasajero',
        allowedRoles: ["PASAJERO"],
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
        title: 'Mis Documentos',
        icon: Iconsax.document_text_copy,
        route: '/mis-documentos',
        allowedRoles: ["MOTORISTA", "CONDUCTOR"],
      ),
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
                  color: AppColors.accent.withOpacity(0.3),
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
                            color: Colors.black.withOpacity(0.3),
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
                          onBackgroundImageError: (_, __) =>
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
                                color: Colors.white.withOpacity(0.9),
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
                                    color: Colors.white.withOpacity(0.9),
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

          // ITEMS mejorados
          ...visibleDrawerItems.map(
            (item) => Container(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
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
                    color: AppColors.accent.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(item.icon, color: AppColors.accent, size: 22),
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

          const Spacer(),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Divider(color: Colors.grey.shade300, thickness: 1),
          ),

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
                  color: AppColors.accent.withOpacity(0.15),
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
                  color: Colors.red.withOpacity(0.1),
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
