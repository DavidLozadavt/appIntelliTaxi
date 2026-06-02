import 'dart:typed_data';
import 'dart:ui' as ui;

/// Comprueba bytes mínimos de PNG/JPEG/GIF/WebP antes de decodificar.
bool looksLikeImageBytes(Uint8List bytes) {
  if (bytes.length < 12) return false;

  // PNG: 89 50 4E 47
  if (bytes[0] == 0x89 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x4E &&
      bytes[3] == 0x47) {
    return true;
  }

  // JPEG: FF D8
  if (bytes[0] == 0xFF && bytes[1] == 0xD8) return true;

  // GIF: GIF8
  if (bytes[0] == 0x47 && bytes[1] == 0x49 && bytes[2] == 0x46) return true;

  // WebP: RIFF....WEBP
  if (bytes[0] == 0x52 &&
      bytes[1] == 0x49 &&
      bytes[2] == 0x46 &&
      bytes[3] == 0x46 &&
      bytes[8] == 0x57 &&
      bytes[9] == 0x45 &&
      bytes[10] == 0x42 &&
      bytes[11] == 0x50) {
    return true;
  }

  return false;
}

/// Decodifica sin propagar `Invalid image data` a Crashlytics.
Future<ui.Image?> decodeImageFromBytes(
  Uint8List bytes, {
  int? targetWidth,
  int? targetHeight,
}) async {
  if (!looksLikeImageBytes(bytes)) return null;
  try {
    final codec = await ui.instantiateImageCodec(
      bytes,
      targetWidth: targetWidth,
      targetHeight: targetHeight,
    );
    final frame = await codec.getNextFrame();
    return frame.image;
  } catch (_) {
    return null;
  }
}
