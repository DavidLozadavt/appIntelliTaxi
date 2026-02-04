import 'package:flutter/material.dart';

class TabItem {
  final Widget page;
  final BottomNavigationBarItem navItem;
  final List<String> allowedRoles;

  TabItem({
    required this.page,
    required this.navItem,
    this.allowedRoles = const [], 
  });
}
