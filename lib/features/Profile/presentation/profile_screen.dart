
import 'package:intellitaxi/features/Profile/presentation/profile_body_screen.dart';
import 'package:intellitaxi/features/auth/logic/auth_provider.dart';
import 'package:intellitaxi/shared/loading_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    Future.microtask(
      () => Provider.of<AuthProvider>(
        context,
        listen: false,
      ).loadUserFromStorage(),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.user;

    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final persona = user.persona;
    final company = authProvider.authData?.company;
    final userRoles = authProvider.roles;

    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(
            title: const Text(
              "Perfil",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.power_settings_new),
                onPressed: () async {
                  await authProvider.logout();
                  if (mounted) {
                    Navigator.pushReplacementNamed(context, '/login');
                  }
                },
              ),
            ],
         
          ),
          body: ProfileBodyScreen(
            company: company,
            persona: persona,
            userRoles: userRoles,
          ),
        ),

        if (authProvider.isLoading)
          const Positioned.fill(
            child: LoadingScreen(message: "Cerrando sesión..."),
          ),
      ],
    );
  }
}
