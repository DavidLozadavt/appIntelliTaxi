import 'package:intellitaxi/core/geo/barrios/barrio.dart';

enum PinOrigen { gps, ajusteManual }

class ServicePin {
  ServicePin({
    required this.lat,
    required this.lng,
    this.precisionGpsM,
    this.origen = PinOrigen.gps,
    this.resolve,
    this.elegido,
    this.confirmadoPorUsuario = false,
  });

  double lat;
  double lng;
  double? precisionGpsM;
  PinOrigen origen;
  BarrioResolveResult? resolve;
  Barrio? elegido;
  bool confirmadoPorUsuario;

  static const double gpsReadyMeters = 30;

  bool get gpsListo =>
      origen == PinOrigen.ajusteManual ||
      (precisionGpsM != null && precisionGpsM! <= gpsReadyMeters);

  Barrio? get barrioEfectivo => elegido ?? resolve?.match;

  String get barrioNombre {
    final barrio = barrioEfectivo;
    if (barrio != null) return barrio.nombre;
    return 'Barrio por confirmar';
  }

  bool get barrioPorConfirmar => barrioEfectivo == null;

  bool get necesitaElegirBarrio {
    if (confirmadoPorUsuario) return false;
    final kind = resolve?.kind;
    return kind == BarrioResolveKind.nearBorder ||
        kind == BarrioResolveKind.nearby ||
        kind == BarrioResolveKind.unknown;
  }

  String get origenDelPinKey =>
      origen == PinOrigen.ajusteManual ? 'ajuste_manual' : 'gps';
}
