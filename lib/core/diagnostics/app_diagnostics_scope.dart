import 'dart:async' show unawaited;

import 'package:flutter/widgets.dart';
import 'package:intellitaxi/core/diagnostics/app_diagnostics.dart';
import 'package:intellitaxi/core/utils/app_lifecycle_helper.dart';

/// Observa lifecycle de Flutter y lo registra en [AppDiagnostics].
class AppDiagnosticsScope extends StatefulWidget {
  const AppDiagnosticsScope({super.key, required this.child});

  final Widget child;

  @override
  State<AppDiagnosticsScope> createState() => _AppDiagnosticsScopeState();
}

class _AppDiagnosticsScopeState extends State<AppDiagnosticsScope>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final initial = WidgetsBinding.instance.lifecycleState;
    if (initial != null) {
      AppDiagnostics.handleLifecycle(initial);
      unawaited(AppLifecycleHelper.persistLifecycleState(initial));
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AppDiagnostics.phase('first_frame');
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    AppDiagnostics.handleLifecycle(state);
    unawaited(AppLifecycleHelper.persistLifecycleState(state));
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
