import 'package:flutter/material.dart';
import 'package:intellitaxi/features/auth/data/auth_model.dart';
import 'package:intellitaxi/features/auth/providers/auth_provider.dart';
import 'package:intellitaxi/features/auth/services/auth_interceptor.dart';
import 'package:intellitaxi/main.dart';
import 'package:provider/provider.dart';

/// Enlaza el interceptor HTTP con [AuthProvider] y la navegación global.
class AuthSessionCoordinator {
  AuthSessionCoordinator._();

  static bool _configured = false;

  static void ensureConfigured() {
    if (_configured) return;
    _configured = true;

    AuthInterceptor.onSessionRefreshed = (AuthResponse response) {
      final ctx = navigatorKey.currentContext;
      if (ctx == null || !ctx.mounted) return;
      ctx.read<AuthProvider>().applyRefreshedSession(response);
    };

    AuthInterceptor.onSessionExpired = () async {
      final ctx = navigatorKey.currentContext;
      if (ctx == null) return;

      final auth = ctx.read<AuthProvider>();
      await auth.clearSessionOnExpiry();

      if (!ctx.mounted) return;
      Navigator.of(ctx).pushNamedAndRemoveUntil('/login', (_) => false);
    };
  }
}
