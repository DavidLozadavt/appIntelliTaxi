import 'package:permission_handler/permission_handler.dart';

class PermissionsService {
  Future<bool> requestNotificationPermission() async {
    final status = await Permission.notification.request();
    return status.isGranted;
  }

  Future<bool> requestStoragePermission() async {
    final status = await Permission.storage.request();
    return status.isGranted;
  }

  Future<bool> requestMicrophonePermission() async {
    final status = await Permission.microphone.request();
    return status.isGranted;
  }

  Future<bool> requestCameraPermission() async {
  final status = await Permission.camera.request();
  return status.isGranted;
}

Future<bool> requestGalleryPermission() async {
  final status = await Permission.photos.request();
  return status.isGranted;
}


  Future<Map<String, bool>> requestAll() async {
    final statuses = await [
      Permission.notification,
      Permission.storage,
      Permission.microphone,
    ].request();

    return {
      "notification": statuses[Permission.notification]?.isGranted ?? false,
      "storage": statuses[Permission.storage]?.isGranted ?? false,
      "microphone": statuses[Permission.microphone]?.isGranted ?? false,
    };
  }

  Future<bool> hasAllPermissions() async {
    final notification = await Permission.notification.isGranted;
    final storage = await Permission.storage.isGranted;
    final mic = await Permission.microphone.isGranted;

    return notification && storage && mic;
  }
}
