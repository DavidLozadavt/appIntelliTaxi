import 'package:flutter/widgets.dart';

/// Estado de primer plano de la app.
class AppLifecycleHelper {
  AppLifecycleHelper._();

  static bool isInForeground() {
    final state = WidgetsBinding.instance.lifecycleState;
    return state == null || state == AppLifecycleState.resumed;
  }
}
