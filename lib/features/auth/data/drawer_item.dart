import 'package:flutter/material.dart';

class DrawerItem {
  final String title;
  final IconData icon;
  final String route;
  final List<String> allowedRoles;

  DrawerItem({
    required this.title,
    required this.icon,
    required this.route,
    this.allowedRoles = const [],
  });
}