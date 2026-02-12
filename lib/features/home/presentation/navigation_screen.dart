import 'package:intellitaxi/core/theme/app_colors.dart';
import 'package:intellitaxi/features/auth/data/tab_Item.dart';
import 'package:intellitaxi/features/auth/logic/auth_provider.dart';
import 'package:intellitaxi/features/home/presentation/home_screen.dart';
import 'package:intellitaxi/features/Profile/presentation/profile_screen.dart';
import 'package:intellitaxi/core/services/app_lifecycle_wrapper.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

class NavigationScreen extends StatefulWidget {
  const NavigationScreen({super.key});

  @override
  State<NavigationScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<NavigationScreen> {
  int _selectedIndex = 0;

  final List<TabItem> allTabs = [
    TabItem(
      page: const HomeScreen(),
      navItem: const BottomNavigationBarItem(
        icon: Icon(Iconsax.home_copy),
        label: "Inicio",
      ),
    ),
    // TabItem(
    //   page: const ChatScreen(),
    //   navItem: const BottomNavigationBarItem(
    //     icon: Icon(Iconsax.messages_copy),
    //     label: "Chat",
    //   ),
    // ),
    TabItem(
      page: const ProfileTab(),
      navItem: const BottomNavigationBarItem(
        icon: Icon(Iconsax.user_copy),
        label: "Perfil",
      ),
    ),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final userRoles = auth.roles;

    final visibleTabs = allTabs.where((tab) {
      return tab.allowedRoles.isEmpty ||
          tab.allowedRoles.any((role) => userRoles.contains(role));
    }).toList();

    if (_selectedIndex >= visibleTabs.length) {
      _selectedIndex = 0;
    }

    // Envolver con AppLifecycleWrapper para gestionar servicios activos
    return AppLifecycleWrapper(
      child: Scaffold(
        body: visibleTabs[_selectedIndex].page,
        bottomNavigationBar: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
          selectedItemColor: AppColors.accent,
          unselectedItemColor: Colors.grey,
          showSelectedLabels: true,
          showUnselectedLabels: true,
          selectedLabelStyle: const TextStyle(fontSize: 11),
          unselectedLabelStyle: const TextStyle(fontSize: 11),
          items: visibleTabs.map((tab) => tab.navItem).toList(),
        ),
      ),
    );
  }
}
