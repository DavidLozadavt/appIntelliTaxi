import 'package:intellitaxi/core/theme/app_colors.dart';
import 'package:intellitaxi/features/auth/data/auth_model.dart';
import 'package:intellitaxi/features/auth/logic/auth_provider.dart';
import 'package:intellitaxi/features/Profile/presentation/edit_profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:provider/provider.dart';

class ProfileBodyScreen extends StatelessWidget {
  final Company? company;
  final Persona persona;
  final List<String> userRoles;

  const ProfileBodyScreen({
    super.key,
    required this.company,
    required this.persona,
    required this.userRoles,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Header con foto de perfil mejorado
          Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              // Banner con gradiente
              Container(
                height: 180,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: LinearGradient(
                    colors: [AppColors.primary, AppColors.accent],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.accent.withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    color: Colors.white.withOpacity(0.2),
                    padding: const EdgeInsets.all(20),
                    child: Image.network(
                      company?.rutaLogoUrl ??
                          "https://via.placeholder.com/300x150",
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) =>
                          const Center(
                            child: Icon(
                              Iconsax.building_copy,
                              size: 60,
                              color: Colors.white,
                            ),
                          ),
                    ),
                  ),
                ),
              ),
              // Avatar con borde elegante
              Positioned(
                bottom: -50,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey.shade900 : Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.accent, width: 3),
                    ),
                    child: ClipOval(
                      child: Image.network(
                        persona.rutaFotoUrl ??
                            "https://via.placeholder.com/150",
                        width: 100,
                        height: 100,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          width: 100,
                          height: 100,
                          color: Colors.grey.shade300,
                          child: const Icon(Iconsax.user_copy, size: 50),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 65),

          // Nombre con estilo
          Text(
            "${persona.nombre1} ${persona.nombre2 ?? ''} ${persona.apellido1} ${persona.apellido2 ?? ''}",
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 24),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),

          // Botón de editar perfil
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 60),
            child: ElevatedButton.icon(
              onPressed: () async {
                final authProvider = Provider.of<AuthProvider>(
                  context,
                  listen: false,
                );
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => EditProfileScreen(
                      persona: persona,
                      user: authProvider.user!,
                    ),
                  ),
                );

                // Si se actualizó el perfil, recargar datos
                if (result == true) {
                  await authProvider.loadUserFromStorage();
                }
              },
              icon: const Icon(Iconsax.edit_copy, size: 18),
              label: const Text('Editar Perfil'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                elevation: 4,
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Roles con chip design
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.accent.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Iconsax.shield_tick_copy,
                  size: 18,
                  color: AppColors.accent,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    userRoles.isNotEmpty
                        ? userRoles.join(", ")
                        : "No roles asignados",
                    style: TextStyle(
                      color: AppColors.accent,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),

          if (company != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Iconsax.building_copy,
                    size: 16,
                    color: Colors.grey.shade600,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      company!.razonSocial,
                      style: TextStyle(
                        fontStyle: FontStyle.italic,
                        color: Colors.grey.shade600,
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 32),

          // Título de sección mejorado
          Row(
            children: [
              Container(
                width: 4,
                height: 24,
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                "Información de Contacto",
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),

          _infoTile(
            Iconsax.sms_copy,
            "Correo Electrónico",
            persona.email ?? "No disponible",
            isDark,
          ),
          _infoTile(
            Iconsax.call_copy,
            "Teléfono",
            persona.celular ?? "No disponible",
            isDark,
          ),
          _infoTile(
            Iconsax.location_copy,
            "Dirección",
            persona.direccion ?? "No disponible",
            isDark,
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _infoTile(IconData icon, String label, String value, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: isDark
            ? Colors.grey.shade800.withOpacity(0.5)
            : Colors.grey.shade50,
        border: Border.all(
          color: isDark ? Colors.grey.shade700 : Colors.grey.shade200,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.accent.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.accent, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
