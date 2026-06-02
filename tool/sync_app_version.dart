import 'dart:io';

/// Escribe [lib/core/app_version.generated.dart] leyendo `version:` de pubspec.yaml.
void main() {
  final pubspecFile = File('pubspec.yaml');
  if (!pubspecFile.existsSync()) {
    stderr.writeln('No se encontró pubspec.yaml');
    exit(1);
  }

  final pubspec = pubspecFile.readAsStringSync();
  final match = RegExp(
    r'^version:\s*(.+)$',
    multiLine: true,
  ).firstMatch(pubspec);
  final version = match?.group(1)?.trim();
  if (version == null || version.isEmpty) {
    stderr.writeln('No se encontró version: en pubspec.yaml');
    exit(1);
  }

  final out = File('lib/core/app_version.generated.dart');
  out.parent.createSync(recursive: true);
  out.writeAsStringSync('''
// Generado por tool/sync_app_version.dart — no editar a mano.
// Ejecutar: dart run tool/sync_app_version.dart (o `make deps`).

const String kAppVersionLabel = '$version';
''');

  stdout.writeln('Versión sincronizada: $version');
}
