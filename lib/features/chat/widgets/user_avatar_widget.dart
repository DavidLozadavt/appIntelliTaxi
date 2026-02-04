import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';

/// Widget que muestra un avatar de usuario con foto o iniciales por defecto
class UserAvatar extends StatelessWidget {
  final String? imageUrl;
  final String userName;
  final double radius;
  final Color? backgroundColor;

  const UserAvatar({
    super.key,
    this.imageUrl,
    required this.userName,
    this.radius = 26,
    this.backgroundColor,
  });

  /// Genera un color único basado en el nombre del usuario
  Color _getColorFromName(String name) {
    final colors = [
      Colors.blue.shade400,
      Colors.green.shade400,
      Colors.orange.shade400,
      Colors.purple.shade400,
      Colors.red.shade400,
      Colors.teal.shade400,
      Colors.pink.shade400,
      Colors.indigo.shade400,
      Colors.cyan.shade400,
      Colors.amber.shade400,
    ];

    int hash = 0;
    for (int i = 0; i < name.length; i++) {
      hash = name.codeUnitAt(i) + ((hash << 5) - hash);
    }

    return colors[hash.abs() % colors.length];
  }

  /// Obtiene las iniciales del nombre (máximo 2 caracteres)
  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.isEmpty) return '?';

    if (parts.length == 1) {
      return parts[0][0].toUpperCase();
    }

    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    // Si hay URL de imagen, intentar cargarla
    if (imageUrl != null && imageUrl!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: CachedNetworkImage(
          imageUrl: imageUrl!,
          width: radius * 2,
          height: radius * 2,
          fit: BoxFit.cover,
          placeholder: (context, url) => Shimmer.fromColors(
            baseColor: Colors.grey.shade300,
            highlightColor: Colors.grey.shade100,
            child: Container(
              width: radius * 2,
              height: radius * 2,
              color: Colors.white,
            ),
          ),
          errorWidget: (context, url, error) => _buildInitialsAvatar(),
        ),
      );
    }

    // Si no hay imagen, mostrar avatar con iniciales
    return _buildInitialsAvatar();
  }

  Widget _buildInitialsAvatar() {
    final color = backgroundColor ?? _getColorFromName(userName);

    return CircleAvatar(
      radius: radius,
      backgroundColor: color,
      child: Text(
        _getInitials(userName),
        style: TextStyle(
          color: Colors.white,
          fontSize: radius * 0.75, // Tamaño proporcional al radio
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
