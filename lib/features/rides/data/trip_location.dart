class TripLocation {
  final String? placeId;
  final String name;
  final String address;
  final double lat;
  final double lng;
  final bool isCurrentLocation;
  final String? barrio;
  final int? barrioId;
  final bool barrioConfirmadoPorUsuario;
  final String? referencia;
  final double? precisionGpsM;
  final String? origenDelPin;

  TripLocation({
    this.placeId,
    required this.name,
    required this.address,
    required this.lat,
    required this.lng,
    this.isCurrentLocation = false,
    this.barrio,
    this.barrioId,
    this.barrioConfirmadoPorUsuario = false,
    this.referencia,
    this.precisionGpsM,
    this.origenDelPin,
  });

  factory TripLocation.currentLocation({
    required double lat,
    required double lng,
    String name = 'Mi ubicación',
    String address = 'Mi ubicación actual',
    String? barrio,
    int? barrioId,
    bool barrioConfirmadoPorUsuario = false,
    String? referencia,
    double? precisionGpsM,
    String? origenDelPin,
  }) {
    return TripLocation(
      name: name,
      address: address,
      lat: lat,
      lng: lng,
      isCurrentLocation: true,
      barrio: barrio,
      barrioId: barrioId,
      barrioConfirmadoPorUsuario: barrioConfirmadoPorUsuario,
      referencia: referencia,
      precisionGpsM: precisionGpsM,
      origenDelPin: origenDelPin,
    );
  }

  factory TripLocation.fromPlaceDetails({
    required String placeId,
    required String name,
    required String address,
    required double lat,
    required double lng,
    String? barrio,
    int? barrioId,
    bool barrioConfirmadoPorUsuario = false,
    String? referencia,
    double? precisionGpsM,
    String? origenDelPin,
  }) {
    return TripLocation(
      placeId: placeId,
      name: name,
      address: address,
      lat: lat,
      lng: lng,
      barrio: barrio,
      barrioId: barrioId,
      barrioConfirmadoPorUsuario: barrioConfirmadoPorUsuario,
      referencia: referencia,
      precisionGpsM: precisionGpsM,
      origenDelPin: origenDelPin,
    );
  }

  @override
  String toString() => name;
}
