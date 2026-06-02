import 'dart:typed_data';

/// Descriptor de icono de marcador (sustituto de Google Maps).
class BitmapDescriptor {
  const BitmapDescriptor._({
    this.bytes,
    this.assetPath,
    this.hue,
    this.width = 48,
  });

  final Uint8List? bytes;
  final String? assetPath;
  final double? hue;
  final double width;

  static const BitmapDescriptor defaultMarker = BitmapDescriptor._();

  /// Compatible con `BitmapDescriptor.asset(ImageConfiguration, path)`.
  static Future<BitmapDescriptor> asset(
    Object configOrAsset, [
    String? assetPath,
    double width = 48,
  ]) async {
    final path = assetPath ?? configOrAsset as String;
    return BitmapDescriptor._(assetPath: path, width: width);
  }

  static BitmapDescriptor fromBytes(Uint8List data, {double width = 48}) {
    return BitmapDescriptor._(bytes: data, width: width);
  }

  static BitmapDescriptor defaultMarkerWithHue(double hue) {
    return BitmapDescriptor._(hue: hue);
  }

  static const double hueRed = 0;
  static const double hueOrange = 30;
  static const double hueYellow = 60;
  static const double hueGreen = 120;
  static const double hueCyan = 180;
  static const double hueAzure = 210;
  static const double hueBlue = 240;
  static const double hueViolet = 270;
  static const double hueMagenta = 300;
  static const double hueRose = 330;
}
