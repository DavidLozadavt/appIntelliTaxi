import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intellitaxi/core/services/app_lifecycle_manager.dart';
import 'package:intellitaxi/features/auth/providers/auth_provider.dart';

/// Widget que envuelve la navegación principal y gestiona el lifecycle
/// Restaura automáticamente servicios activos al volver del background
class AppLifecycleWrapper extends StatefulWidget {
  final Widget child;

  const AppLifecycleWrapper({super.key, required this.child});

  @override
  State<AppLifecycleWrapper> createState() => _AppLifecycleWrapperState();
}

class _AppLifecycleWrapperState extends State<AppLifecycleWrapper> {
  AppLifecycleManager? _lifecycleManager;
  AuthProvider? _authProvider;
  bool _didAuthTriggeredCheck = false;

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

    _authProvider = Provider.of<AuthProvider>(context, listen: false);

    _lifecycleManager = AppLifecycleManager(
      context: context,
      authProvider: _authProvider!,
    );

    _lifecycleManager!.initialize();
    _authProvider!.addListener(_onAuthChanged);

    // Servicio activo al cold start: lo verifica Home (pasajero/conductor).
    // Lifecycle solo al volver del background (didChangeAppLifecycleState.resumed).
  }

  void _onAuthChanged() {
    if (!mounted || _lifecycleManager == null || _authProvider == null) return;
    if (_didAuthTriggeredCheck) return;

    if (_authProvider!.user != null) {
      _didAuthTriggeredCheck = true;
      // Tras login el destino (Home) ya consulta servicio activo.
    }
  }

  @override
  void dispose() {
    _authProvider?.removeListener(_onAuthChanged);
    _lifecycleManager?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
