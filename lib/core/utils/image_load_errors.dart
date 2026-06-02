/// Errores de decodificación/carga de imagen que la UI puede ignorar.
///
/// En Samsung (y otros OEM) [NetworkImage] suele emitir [FlutterError] antes del
/// callback de error; sin filtrar, Crashlytics los cuenta como crash fatal.
bool isBenignImageLoadError(Object error) {
  final text = error.toString().toLowerCase();
  return text.contains('invalid image data') ||
      text.contains('datos de imagen no válidos') ||
      (text.contains('image codec') && text.contains('failed')) ||
      (text.contains('unable to load asset') && text.contains('image'));
}

bool isBenignImageLoadStack(StackTrace? stack) {
  if (stack == null) return false;
  final trace = stack.toString();
  return trace.contains('NetworkImage._loadAsync') ||
      trace.contains('instantiateImageCodec') ||
      trace.contains('PaintingBinding.instantiateImageCodec');
}

bool shouldSuppressImageCrashReport({
  required Object error,
  StackTrace? stack,
}) {
  return isBenignImageLoadError(error) || isBenignImageLoadStack(stack);
}

/// URL http(s) con extensión o ruta típica de imagen (evita HTML de login).
bool isPlausibleNetworkImageUrl(String? raw) {
  final url = raw?.trim();
  if (url == null || url.isEmpty) return false;
  if (!url.startsWith('http://') && !url.startsWith('https://')) return false;

  final path = Uri.tryParse(url)?.path.toLowerCase() ?? '';
  const exts = ['.jpg', '.jpeg', '.png', '.gif', '.webp', '.bmp', '.heic'];
  if (exts.any(path.endsWith)) return true;

  // Rutas API habituales de fotos de perfil / vehículo.
  return path.contains('foto') ||
      path.contains('photo') ||
      path.contains('avatar') ||
      path.contains('imagen') ||
      path.contains('image') ||
      path.contains('upload') ||
      path.contains('storage') ||
      path.contains('media');
}
