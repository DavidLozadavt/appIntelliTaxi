class AppVersionDto {
  const AppVersionDto({
    required this.version,
    required this.apkUrl,
    required this.changelog,
    required this.forceUpdate,
    this.appVersionId,
  });

  final String version;
  final String? apkUrl;
  final String? changelog;
  final bool forceUpdate;
  final String? appVersionId;

  bool get hasValidApkUrl => (apkUrl ?? '').trim().isNotEmpty;

  String get effectiveChangelog {
    final value = changelog?.trim();
    if (value == null || value.isEmpty) {
      return 'Correcciones y mejoras generales.';
    }
    return value;
  }

  factory AppVersionDto.fromJson(Map<String, dynamic> json) {
    final forceValue = json['forceUpdate'];
    return AppVersionDto(
      version: json['version']?.toString().trim() ?? '',
      apkUrl: json['apkUrl']?.toString().trim(),
      changelog: json['changelog']?.toString(),
      forceUpdate:
          forceValue == true ||
          forceValue?.toString().toLowerCase().trim() == 'true' ||
          forceValue?.toString().trim() == '1',
      appVersionId: json['appVersionId']?.toString(),
    );
  }
}
