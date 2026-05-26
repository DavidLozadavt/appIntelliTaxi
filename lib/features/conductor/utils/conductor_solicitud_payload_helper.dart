import 'package:intellitaxi/config/app_config.dart';
import 'package:intellitaxi/core/utils/json_payload_helper.dart';
import 'package:intellitaxi/features/conductor/conductor_constants.dart';
import 'package:intellitaxi/features/conductor/utils/solicitud_display_helper.dart';

/// Normalización de solicitudes recibidas por Pusher / sync API.
class ConductorSolicitudPayloadHelper {
  ConductorSolicitudPayloadHelper._();

  static Map<String, dynamic> parsePayload(dynamic data) =>
      JsonPayloadHelper.parseAndMerge(data);

  static String? obtenerSolicitudId(Map<String, dynamic> solicitud) {
    final rawId = solicitud['_local_id'] ??
        solicitud['solicitud_id'] ??
        solicitud['solicitudId'] ??
        solicitud['servicio_id'] ??
        solicitud['servicioId'] ??
        solicitud['id'] ??
        solicitud['ride_id'] ??
        solicitud['request_id'] ??
        solicitud['temp_id'];
    return rawId?.toString();
  }

  static String generarSolicitudTemporalId() =>
      'temp_${DateTime.now().microsecondsSinceEpoch}';

  static int resolverTtlSegundos(Map<String, dynamic> solicitud) {
    final ttlRaw = solicitud['ttl_segundos'] ??
        solicitud['ttl'] ??
        solicitud['tiempo_restante'];
    final ttl = int.tryParse(ttlRaw?.toString() ?? '');
    if (ttl == null || ttl <= 0) return kOportunidadConductorSegundos;
    return ttl > kOportunidadConductorSegundos
        ? kOportunidadConductorSegundos
        : ttl;
  }

  static String? resolverFotoPasajero(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final foto = value.trim();
    if (foto.startsWith('http://') || foto.startsWith('https://')) return foto;

    final base = Uri.parse(AppConfig.baseUrl);
    final origin =
        '${base.scheme}://${base.host}${base.hasPort ? ':${base.port}' : ''}';
    if (foto.startsWith('/')) return '$origin$foto';
    return '$origin/$foto';
  }

  static Map<String, dynamic> normalizarSolicitud(
    Map<String, dynamic> raw, {
    bool isDirectOffer = false,
  }) {
    final base = isDirectOffer
        ? normalizarOfertaDirecta(raw)
        : SolicitudDisplayHelper.normalizeSolicitudMap(raw);
    final barrio = SolicitudDisplayHelper.barrioFromPayload(base);
    if (barrio != null) {
      base['origen_barrio'] = barrio;
    }
    return base;
  }

  static Map<String, dynamic> normalizarOfertaDirecta(Map<String, dynamic> raw) {
    final merged = SolicitudDisplayHelper.normalizeSolicitudMap(raw);
    final solicitudId = merged['solicitud_id'] ?? merged['id'];
    return {
      ...merged,
      'solicitud_id': solicitudId,
      'servicio_id': solicitudId,
      'id': solicitudId,
      'pasajero_id': merged['pasajero_id'],
      'pasajero_nombre': merged['pasajero_nombre'] ?? 'Pasajero',
      'pasajero_foto': resolverFotoPasajero(merged['pasajero_foto']?.toString()),
      'origen': SolicitudDisplayHelper.pickupName(merged),
      'destino': SolicitudDisplayHelper.destinationName(merged),
      'origen_name': merged['origen_name'],
      'origen_address': merged['origen_address'],
      'destino_name': merged['destino_name'],
      'destino_address': merged['destino_address'],
      'origen_barrio': merged['origen_barrio'] ?? merged['barrio'],
      'origen_lat': merged['origen_lat'],
      'origen_lng': merged['origen_lng'],
      'destino_lat': merged['destino_lat'],
      'destino_lng': merged['destino_lng'],
      'precio_ofertado':
          merged['precio_ofrecido'] ?? merged['precio_ofertado'] ?? 0,
      'distancia': merged['distancia'],
      'duracion_estimada': merged['duracion_estimada'],
      'mensaje': merged['mensaje'],
      'status': 'oferta_directa',
      'clase_vehiculo': 'taxi',
      'timestamp': merged['timestamp'] ?? DateTime.now().toIso8601String(),
      'ttl_segundos': merged['ttl_segundos'] ?? kOportunidadConductorSegundos,
    };
  }

  static bool hasMeaningfulPlaceName(String? value) {
    if (value == null || value.trim().isEmpty) return false;
    return !SolicitudDisplayHelper.isPlaceholderPickup(value) &&
        !SolicitudDisplayHelper.isPlaceholderDestino(value);
  }

  static bool hasMeaningfulAddress(String? value) {
    if (value == null || value.trim().isEmpty) return false;
    if (SolicitudDisplayHelper.isPlaceholderPickup(value)) return false;
    if (SolicitudDisplayHelper.isPlaceholderDestino(value)) return false;
    return true;
  }

  static String? servicioIdFromTomadaPayload(Map<String, dynamic> raw) {
    final servicioId = raw['servicio_id'] ?? raw['solicitud_id'] ?? raw['id'];
    return servicioId?.toString();
  }
}
