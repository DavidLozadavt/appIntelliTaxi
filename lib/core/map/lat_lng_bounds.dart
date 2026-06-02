import 'package:intellitaxi/core/map/lat_lng.dart';

class LatLngBounds {
  const LatLngBounds({
    required this.southwest,
    required this.northeast,
  });

  final LatLng southwest;
  final LatLng northeast;

  LatLng get center => LatLng(
        (southwest.latitude + northeast.latitude) / 2,
        (southwest.longitude + northeast.longitude) / 2,
      );
}
