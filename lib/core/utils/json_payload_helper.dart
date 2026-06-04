import 'dart:convert';

/// Utilidades para decodificar payloads de API, Pusher y sockets.
class JsonPayloadHelper {
  JsonPayloadHelper._();

  /// Fusiona `data`, `solicitud` y `servicio` anidados en un solo mapa.
  static Map<String, dynamic> parseAndMerge(dynamic data) {
    Map<String, dynamic> payload;
    if (data is String) {
      payload = json.decode(data) as Map<String, dynamic>;
    } else if (data is Map<String, dynamic>) {
      payload = data;
    } else if (data is Map) {
      payload = Map<String, dynamic>.from(data);
    } else {
      throw Exception('Payload no soportado: ${data.runtimeType}');
    }

    final merged = Map<String, dynamic>.from(payload);
    for (final key in const ['data', 'solicitud', 'servicio']) {
      final nested = payload[key];
      if (nested is Map) {
        merged.addAll(Map<String, dynamic>.from(nested));
      } else if (nested is String && nested.trim().isNotEmpty) {
        try {
          final decoded = json.decode(nested);
          if (decoded is Map) {
            merged.addAll(Map<String, dynamic>.from(decoded));
          }
        } catch (_) {
          // No es JSON; se ignora.
        }
      }
    }
    return merged;
  }

  static double parseDouble(dynamic value, {double fallback = 0.0}) {
    if (value is num) return value.toDouble();
    if (value is String) {
      return double.tryParse(value.replaceAll(',', '.')) ?? fallback;
    }
    return fallback;
  }

  static int? parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    return int.tryParse(value.toString());
  }
}
