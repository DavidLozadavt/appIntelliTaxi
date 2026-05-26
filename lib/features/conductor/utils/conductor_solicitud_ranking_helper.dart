import 'package:intellitaxi/core/utils/json_payload_helper.dart';

/// Priorización de solicitudes en cola del conductor.
class ConductorSolicitudRankingHelper {
  ConductorSolicitudRankingHelper._();

  static double calcularScore(Map<String, dynamic> solicitud) {
    final distanciaMetros =
        solicitud['distanciaMetros'] ?? solicitud['distancia_metros'];
    final distanciaValor = solicitud['distancia_km'] ??
        solicitud['distancia'] ??
        (distanciaMetros != null
            ? (JsonPayloadHelper.parseDouble(distanciaMetros) / 1000.0)
            : null);
    final distanciaKm =
        JsonPayloadHelper.parseDouble(distanciaValor, fallback: 999.0);

    final precio = JsonPayloadHelper.parseDouble(
      solicitud['precio_estimado'] ??
          solicitud['precioEstimado'] ??
          solicitud['precio'] ??
          solicitud['precio_ofertado'],
    );

    final createdAtRaw = solicitud['created_at'] ??
        solicitud['createdAt'] ??
        solicitud['fechaServicio'] ??
        solicitud['timestamp'];
    final createdAt = DateTime.tryParse(createdAtRaw?.toString() ?? '');
    final segundosDesdeCreacion = createdAt == null
        ? 0
        : DateTime.now().difference(createdAt).inSeconds.clamp(0, 300);
    final scoreDistancia = (100 - (distanciaKm * 10)).clamp(0, 100);
    final scorePrecio = (precio / 1000).clamp(0, 100);
    final scoreRecencia = (300 - segundosDesdeCreacion).toDouble() / 10.0;

    return (scoreDistancia * 0.55) +
        (scorePrecio * 0.35) +
        (scoreRecencia * 0.10);
  }
}
