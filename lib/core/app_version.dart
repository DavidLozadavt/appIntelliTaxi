import 'package:intellitaxi/core/app_version.generated.dart';

/// Versión mostrada en la app (sincronizada con `version:` en [pubspec.yaml]).
class AppVersion {
  AppVersion._();

  static Future<String> get displayLabel async => kAppVersionLabel;
}
