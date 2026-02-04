  import 'package:flutter/material.dart';

Widget menuItem(String title, IconData icon, VoidCallback onTap) {
    return ListTile(
      title: Text(title),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      leading: Icon(icon, color: Colors.brown),
      onTap: onTap,
    );
  }