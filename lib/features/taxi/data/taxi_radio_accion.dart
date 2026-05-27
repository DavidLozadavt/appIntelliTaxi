import 'package:intellitaxi/core/utils/json_payload_helper.dart';

/// Configuración de radio de acción del conductor (`GET/PUT radio-accion`).
class TaxiRadioAccion {
  final bool activo;
  final double? radioKm;
  final double radioEfectivoKm;
  final bool sinLimite;
  final double minKm;
  final double maxKm;
  final double defaultKm;

  const TaxiRadioAccion({
    required this.activo,
    this.radioKm,
    required this.radioEfectivoKm,
    required this.sinLimite,
    this.minKm = 1,
    this.maxKm = 50,
    this.defaultKm = 10,
  });

  static const TaxiRadioAccion sinLimitePorDefecto = TaxiRadioAccion(
    activo: false,
    radioEfectivoKm: 10,
    sinLimite: true,
    defaultKm: 10,
  );

  factory TaxiRadioAccion.fromJson(Map<String, dynamic> json) {
    final payload = _unwrapPayload(json);
    final nested = payload['radio_accion'];
    final data = nested is Map
        ? Map<String, dynamic>.from(nested)
        : payload;

    final activo = data['activo'] == true;
    final radioKmRaw = data['radio_km'];
    final double? radioKm = radioKmRaw == null
        ? null
        : JsonPayloadHelper.parseDouble(radioKmRaw);
    final radioEfectivo = JsonPayloadHelper.parseDouble(
      data['radio_efectivo_km'] ?? data['radio_km'],
      fallback: radioKm ?? 10,
    );
    final sinLimite =
        data['sin_limite'] == true || (!activo && data['sin_limite'] != false);

    return TaxiRadioAccion(
      activo: activo,
      radioKm: radioKm,
      radioEfectivoKm: radioEfectivo,
      sinLimite: sinLimite || !activo,
      minKm: JsonPayloadHelper.parseDouble(data['min_km'], fallback: 1),
      maxKm: JsonPayloadHelper.parseDouble(data['max_km'], fallback: 50),
      defaultKm: JsonPayloadHelper.parseDouble(
        data['default_km'],
        fallback: 10,
      ),
    );
  }

  static Map<String, dynamic> _unwrapPayload(Map<String, dynamic> json) {
    final nested = json['data'];
    if (nested is Map<String, dynamic>) {
      return {...json, ...nested};
    }
    if (nested is Map) {
      return {...json, ...Map<String, dynamic>.from(nested)};
    }
    return json;
  }
}
