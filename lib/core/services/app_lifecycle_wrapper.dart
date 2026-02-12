import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intellitaxi/core/services/app_lifecycle_manager.dart';
import 'package:intellitaxi/features/auth/logic/auth_provider.dart';

/// Widget que envuelve la navegación principal y gestiona el lifecycle
/// Restaura automáticamente servicios activos al volver del background
class AppLifecycleWrapper extends StatefulWidget {
  final Widget child;

  const AppLifecycleWrapper({
    super.key,
    required this.child,
  });

  @override
  State<AppLifecycleWrapper> createState() => _AppLifecycleWrapperState();
}

class _AppLifecycleWrapperState extends State<AppLifecycleWrapper> {
  AppLifecycleManager? _lifecycleManager;

  @override
  void initState() {
    super.initState();
    
    // Inicializar el lifecycle manager después del primer frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeLifecycleManager();
    });
  }

  void _initializeLifecycleManager() {
    if (!mounted) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    _lifecycleManager = AppLifecycleManager(
      context: context,
      authProvider: authProvider,
    );

    _lifecycleManager!.initialize();

    // Verificar si hay un servicio activo al iniciar
    _lifecycleManager!.checkActiveService();
  }

  @override
  void dispose() {
    _lifecycleManager?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
