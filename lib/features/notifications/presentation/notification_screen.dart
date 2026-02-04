import 'package:intellitaxi/core/permissions/permissions_service.dart';
import 'package:intellitaxi/features/notifications/logic/notification_provider.dart';
import 'package:intellitaxi/shared/empty_state_widget.dart';
import 'package:intellitaxi/shared/loading_screen.dart';
import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final PermissionsService _permissionsService = PermissionsService();
  bool _hasPermission = true;

  @override
  void initState() {
    super.initState();
    _checkPermission();
  }

  Future<void> _checkPermission() async {
    final granted = await Permission.notification.isGranted;
    if (!granted) {
      final result = await _permissionsService.requestNotificationPermission();
      setState(() {
        _hasPermission = result;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<NotificationProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Notifications",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: !_hasPermission
          ? const Center(
              child: Text(
                "Debes habilitar los permisos de notificaciones\npara poder ver esta sección.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            )
          : provider.isLoading
          ? const LoadingScreen(message: "Cargando notificaciones...")
          : provider.notifications.isEmpty
          ? EmptyStateWidget(
              icon: Iconsax.notification_bing_copy,
              title: "No hay notificaciones",
              subtitle: "Cuando recibas notificaciones aparecerán aquí",
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: provider.notifications.length,
              itemExtent: 76,
              cacheExtent: 500,
              addAutomaticKeepAlives: false,
              itemBuilder: (context, index) {
                final notif = provider.notifications[index];
                return ListTile(
                  leading: CircleAvatar(
                    radius: 20,
                    backgroundColor: Colors.brown.shade50,
                    child: ClipOval(
                      child: Image.network(
                        notif.personaRemitente?.rutaFotoUrl ??
                            "https://via.placeholder.com/50",
                        width: 40, // debe ser igual al diámetro del avatar
                        height: 40,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),

                  title: Text(notif.asunto ?? "Sin asunto"),
                  subtitle: Text(notif.empresa?.razonSocial ?? "Sin empresa"),
                );
              },
            ),
    );
  }
}
