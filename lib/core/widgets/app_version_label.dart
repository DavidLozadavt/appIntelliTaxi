import 'package:flutter/material.dart';
import 'package:intellitaxi/core/app_version.dart';

/// Etiqueta discreta con la versión de la app (desde [PackageInfo] / pubspec).
class AppVersionLabel extends StatelessWidget {
  const AppVersionLabel({super.key, this.prefix = 'Versión '});

  final String prefix;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = isDark ? Colors.white38 : Colors.black38;

    return FutureBuilder<String>(
      future: AppVersion.displayLabel,
      builder: (context, snapshot) {
        final label = snapshot.data;
        if (label == null) return const SizedBox.shrink();

        return Text(
          '$prefix$label',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: color),
        );
      },
    );
  }
}
