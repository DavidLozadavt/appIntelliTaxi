class TripLocation {
  final String? placeId;
  final String name;
  final String address;
  final double lat;
  final double lng;
  final bool isCurrentLocation;
  final String? barrio;

  TripLocation({
    this.placeId,
    required this.name,
    required this.address,
    required this.lat,
    required this.lng,
    this.isCurrentLocation = false,
    this.barrio,
  });

  factory TripLocation.currentLocation({
    required double lat,
    required double lng,
    String name = 'Mi ubicación',
    String address = 'Mi ubicación actual',
    String? barrio,
  }) {
    return TripLocation(
      name: name,
      address: address,
      lat: lat,
      lng: lng,
      isCurrentLocation: true,
      barrio: barrio,
    );
  }

  factory TripLocation.fromPlaceDetails({
    required String placeId,
    required String name,
    required String address,
    required double lat,
    required double lng,
    String? barrio,
  }) {
    return TripLocation(
      placeId: placeId,
      name: name,
      address: address,
      lat: lat,
      lng: lng,
      barrio: barrio,
    );
  }

  @override
  String toString() => name;
}
