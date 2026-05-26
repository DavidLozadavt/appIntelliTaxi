import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

/// Permisos de ubicación para el flujo del pasajero.
class PasajeroLocationPermissionHelper {
  PasajeroLocationPermissionHelper._();

  static Future<bool> checkAndRequest() async {
    if (!await Geolocator.isLocationServiceEnabled()) return false;

    var status = await Permission.location.status;
    if (!status.isGranted) {
      status = await Permission.location.request();
    }
    return status.isGranted;
  }
}
