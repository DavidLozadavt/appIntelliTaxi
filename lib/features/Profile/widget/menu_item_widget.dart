  import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

Widget menuItem(String title, IconData icon, VoidCallback onTap) {
    return ListTile(
      title: Text(title),
      trailing: const Icon(Iconsax.arrow_right_3_copy, size: 16),
      leading: Icon(icon, color: Colors.brown),
      onTap: onTap,
    );
  }