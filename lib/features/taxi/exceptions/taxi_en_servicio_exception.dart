/// HTTP 409 cuando el usuario ya tiene un viaje activo (`en_servicio: true`).
class TaxiEnServicioException implements Exception {
  final String message;
  final int? servicioActivoId;

  const TaxiEnServicioException({
    required this.message,
    this.servicioActivoId,
  });

  @override
  String toString() => message;

  static TaxiEnServicioException? fromResponseBody(dynamic data) {
    if (data is! Map) return null;
    final map = Map<String, dynamic>.from(data);
    if (map['en_servicio'] != true) return null;

    final idRaw = map['servicio_activo_id'] ?? map['servicioActivoId'];
    int? servicioId;
    if (idRaw is int) {
      servicioId = idRaw;
    } else {
      servicioId = int.tryParse(idRaw?.toString() ?? '');
    }

    final message = map['message']?.toString() ??
        'Ya tienes un viaje activo. Finaliza o cancela el servicio actual.';

    return TaxiEnServicioException(
      message: message,
      servicioActivoId: servicioId,
    );
  }
}
