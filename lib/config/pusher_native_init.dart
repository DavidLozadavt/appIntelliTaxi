import '../config/app_config.dart';

/// Parámetros nativos extra para Soketi / Laravel WebSockets (no expuestos por el plugin Dart).
class PusherNativeInit {
  PusherNativeInit._();

  static bool get hasCustomEndpoint =>
      AppConfig.pusherHost.trim().isNotEmpty;

  /// Mapa para `MethodChannel.invokeMethod('init', …)` tras el `init()` del plugin.
  static Map<String, dynamic> customEndpointOverrides({
    required String apiKey,
    required String cluster,
    String? authEndpoint,
    bool authorizer = false,
  }) {
    final host = AppConfig.pusherHost.trim();
    if (host.isEmpty) {
      return {
        'apiKey': apiKey,
        'cluster': cluster,
        if (authEndpoint != null) 'authEndpoint': authEndpoint,
        if (authorizer) 'authorizer': true,
      };
    }

    final port = AppConfig.pusherPort;
    final useTls = AppConfig.pusherUseTls;

    return {
      'apiKey': apiKey,
      'host': host,
      'useTLS': useTls,
      if (!useTls) 'wsPort': port,
      if (useTls) 'wssPort': port,
      if (authEndpoint != null) 'authEndpoint': authEndpoint,
      if (authorizer) 'authorizer': true,
    };
  }
}
