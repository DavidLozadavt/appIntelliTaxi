class TripLocation {
  final String? placeId;
  final String name;
  final String address;
  final double lat;
  final double lng;
  final bool isCurrentLocation;

  TripLocation({
    this.placeId,
    required this.name,
    required this.address,
    required this.lat,
    required this.lng,
    this.isCurrentLocation = false,
  });

  factory TripLocation.currentLocation({
    required double lat,
    required double lng,
    String address = 'Mi ubicación actual',
  }) {
    return TripLocation(
      name: 'Mi ubicación',
      address: address,
      lat: lat,
      lng: lng,
      isCurrentLocation: true,
    );
  }

  factory TripLocation.fromPlaceDetails({
    required String placeId,
    required String name,
    required String address,
    required double lat,
    required double lng,
  }) {
    return TripLocation(
      placeId: placeId,
      name: name,
      address: address,
      lat: lat,
      lng: lng,
    );
  }

  @override
  String toString() => name;
}
