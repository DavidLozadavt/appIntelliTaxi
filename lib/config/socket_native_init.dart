import '../config/app_config.dart';

/// Parámetros nativos extra para Soketi / Laravel WebSockets (no expuestos por el plugin Dart).
class SocketNativeInit {
  SocketNativeInit._();

  static bool get hasCustomEndpoint =>
      AppConfig.socketHost.trim().isNotEmpty;

  /// Mapa para `MethodChannel.invokeMethod('init', …)` tras el `init()` del plugin.
  static Map<String, dynamic> customEndpointOverrides({
    required String apiKey,
    required String cluster,
    String? authEndpoint,
    bool authorizer = false,
  }) {
    final host = AppConfig.socketHost.trim();
    if (host.isEmpty) {
      return {
        'apiKey': apiKey,
        'cluster': cluster,
        'authEndpoint': ?authEndpoint,
        if (authorizer) 'authorizer': true,
      };
    }

    final port = AppConfig.socketPort;
    final useTls = AppConfig.socketUseTls;

    return {
      'apiKey': apiKey,
      'host': host,
      'useTLS': useTls,
      if (!useTls) 'wsPort': port,
      if (useTls) 'wssPort': port,
      'authEndpoint': ?authEndpoint,
      if (authorizer) 'authorizer': true,
    };
  }
}
