import 'package:intellitaxi/features/chat/widgets/build_user_shimmer.dart';
import 'package:intellitaxi/features/chat/widgets/user_avatar_widget.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intellitaxi/features/auth/logic/auth_provider.dart';
import 'package:intellitaxi/features/chat/data/activacion_chat_model.dart';
import 'package:intellitaxi/features/chat/presentation/chat_detail_screen.dart';

Widget buildUserList(List<ActivationCompanyUser>? users, bool isLoading) {
  if (isLoading) {
    return buildUserShimmer();
  }

  if (users == null || users.isEmpty) {
    return const Center(
      child: Text(
        'No se encontraron usuarios',
        style: TextStyle(fontSize: 16, color: Colors.grey),
      ),
    );
  }

  return ListView.separated(
    itemCount: users.length,
    cacheExtent: 400,
    addAutomaticKeepAlives: false,
    separatorBuilder: (_, __) => Divider(
      height: 1,
      thickness: 0.5,
      color: Colors.grey.shade300,
      indent: 70,
    ),
    itemBuilder: (context, index) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final idActivation = authProvider.user!.persona.id;
      final companyUserId = authProvider.activationId;
      final user = users[index];
      final persona = user.user.persona;
      final nombreCompleto = '${persona.nombre1} ${persona.apellido1}';
      final roles = user.roles.map((r) => r.name).join(', ');

      return InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ChatDetailScreen(
                userName: nombreCompleto,
                userImage:
                    user.user.persona.rutaFotoUrl ??
                    "https://via.placeholder.com/150",
                userId: user.user.id,
                activationId: idActivation,
                activationIdCurrentUser: user.user.persona.id,
                activCompanyUserId: companyUserId.toString(),
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              // Avatar con manejo mejorado
              UserAvatar(
                imageUrl: persona.rutaFotoUrl,
                userName: nombreCompleto,
                radius: 26,
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nombreCompleto,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      roles.isNotEmpty ? "Roles: $roles" : user.user.email,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade700,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
